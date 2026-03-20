import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'easyslip_api.dart'; // ✅ คลาสที่เรียกใช้ API Verify

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  File? _image;
  bool _isLoading = false;
  bool _isAutoMode = false; // ✅ ตรวจสอบจาก Firebase ว่ามี API Key ไหม

  @override
  void initState() {
    super.initState();
    _checkApiConfig();
  }

  Future<void> _checkApiConfig() async {
    try {
      DocumentSnapshot snap = await _db
          .collection('configs')
          .doc('easyslips')
          .get();
      if (snap.exists) {
        final String apiKey = snap.get('apikey') ?? "";
        if (mounted) setState(() => _isAutoMode = apiKey.isNotEmpty);
      }
    } catch (e) {
      debugPrint("Config Error: $e");
    }
  }

  // ✅ เลือกรูป (ลด Image Quality เพื่อป้องกัน EGL_BAD_ALLOC บนเครื่องแรมต่ำ)
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, // ลดเหลือ 40% เพื่อความเสถียร
    );
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _submitDeposit() async {
    if (_amountController.text.isEmpty || _image == null || _user == null) {
      _showSnackBar("กรุณากรอกจำนวนเงินและแนบสลิป");
      return;
    }

    setState(() => _isLoading = true);

    if (_isAutoMode) {
      await _handleAutoAPI();
    } else {
      await _handleManualUpload();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ----------------------------------------------------
  // 🚀 โหมด 1: Auto API (Verify ทันที)
  // ----------------------------------------------------
  Future<void> _handleAutoAPI() async {
    var slipData = await SlipService().verifySlip(_image!);

    if (slipData != null) {
      double amountInSlip = (slipData['amount']['amount'] ?? 0).toDouble();
      String transRef = slipData['transRef'] ?? "";

      // เช็คสลิปซ้ำในระบบ
      var dup = await _db
          .collection('transactions')
          .where('transRef', isEqualTo: transRef)
          .get();

      if (dup.docs.isNotEmpty) {
        _showSnackBar("สลิปนี้ถูกใช้งานไปแล้ว");
      } else if (amountInSlip == double.parse(_amountController.text)) {
        // ✅ ผ่าน! อัปเดตยอดเงินทันที
        await _saveTransaction(amountInSlip, transRef, true);
      } else {
        _showSnackBar("ยอดเงินไม่ตรงกับสลิป (สลิปโอนจริง: $amountInSlip)");
      }
    } else {
      _showSnackBar("ตรวจสอบสลิปไม่ผ่าน กรุณาลองใหม่หรือติดต่อ Admin");
    }
  }

  // ----------------------------------------------------
  // 📝 โหมด 2: Manual (ส่งให้ Admin ตรวจ)
  // ----------------------------------------------------
  Future<void> _handleManualUpload() async {
    try {
      String fileName =
          'slips/${DateTime.now().millisecondsSinceEpoch}_${_user!.uid}.jpg';
      UploadTask task = FirebaseStorage.instance
          .ref()
          .child(fileName)
          .putFile(_image!);
      TaskSnapshot snap = await task;
      String url = await snap.ref.getDownloadURL();

      await _saveTransaction(
        double.parse(_amountController.text),
        fileName,
        false,
        slipUrl: url,
      );
    } catch (e) {
      _showSnackBar("อัปโหลดรูปไม่สำเร็จ: $e");
    }
  }

  // ฟังก์ชันกลางในการบันทึกข้อมูล
  Future<void> _saveTransaction(
    double amount,
    String ref,
    bool isAuto, {
    String? slipUrl,
  }) async {
    final batch = _db.batch();
    final docRef = _db.collection('transactions').doc();

    batch.set(docRef, {
      'uid': _user!.uid,
      'displayName': _user!.displayName ?? 'User',
      'amount': amount,
      'type': 'deposit',
      'status': isAuto ? 'approved' : 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      if (isAuto) 'transRef': ref,
      if (!isAuto) 'slipUrl': slipUrl,
    });

    if (isAuto) {
      batch.update(_db.collection('users').doc(_user!.uid), {
        'credit': FieldValue.increment(amount),
      });
    }

    await batch.commit();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // ปิดหน้าจอ
      _showSnackBar(
        isAuto ? "เติมเงินสำเร็จแล้ว!" : "ส่งข้อมูลแล้ว รอ Admin อนุมัติ",
      );
    }
  }

  void _showSnackBar(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แจ้งฝากเงิน"),
        backgroundColor: const Color(0xFF11998E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Banner บอกสถานะโหมด
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isAutoMode ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isAutoMode ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAutoMode ? Icons.bolt : Icons.history_edu,
                          color: _isAutoMode ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isAutoMode
                              ? "ระบบอัตโนมัติ (เงินเข้าทันที)"
                              : "ระบบปกติ (รอ Admin ตรวจสอบ)",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "จำนวนเงินโอน",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _image == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                Text("กดเพื่อแนบรูปสลิป"),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_image!, fit: BoxFit.contain),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _submitDeposit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF11998E),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _isAutoMode
                          ? "ยืนยันและเติมเงิน Auto"
                          : "ส่งข้อมูลแจ้งฝาก",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
