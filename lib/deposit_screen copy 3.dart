import 'dart:io';
import 'dart:math'; // ✅ สำหรับการสุ่ม
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ สำหรับ Clipboard (ปุ่มก๊อปปี้)
import 'package:image_picker/image_picker.dart';
import 'easyslip_api.dart'; // ✅ ตรวจสอบชื่อไฟล์ API ของคุณ

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
  bool _isAutoMode = false;

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

  // ✅ 1. วิดเจ็ตสุ่มบัญชีธนาคารพร้อมปุ่ม Copy
  Widget _buildRandomBankCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('banktransfer').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("ไม่พบข้อมูลบัญชีธนาคาร");

        // 🎲 สุ่มเลือก 1 บัญชีจากรายการทั้งหมด
        final random = Random();
        final bankData =
            docs[random.nextInt(docs.length)].data() as Map<String, dynamic>;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blue.shade100, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 18,
                    color: Color(0xFF11998E),
                  ),

                  SizedBox(width: 8),
                  Text(
                    "โอนเงินมาที่บัญชีนี้",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  // โลโก้ธนาคาร
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        bankData['banklogo_link'] != null &&
                            bankData['banklogo_link'] != ""
                        ? Image.network(
                            bankData['banklogo_link'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: const Icon(Icons.account_balance),
                          ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bankData['bankname'] ?? "ธนาคาร",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          bankData['bankaccount'] ?? "000-0-00000-0",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ ปุ่มก๊อปปี้
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF11998E)),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: bankData['bankaccount'] ?? ""),
                      );
                      _showSnackBar("คัดลอกเลขบัญชีแล้ว");
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ 2. เลือกรูปและบีบอัด (ป้องกันแอปหลุด)
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 40,
      );

      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar("ไม่สามารถเลือกรูปภาพได้");
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

  Future<void> _handleAutoAPI() async {
    var slipData = await SlipService().verifySlip(_image!);
    if (slipData != null) {
      double amountInSlip = (slipData['amount']['amount'] ?? 0).toDouble();
      String transRef = slipData['transRef'] ?? "";
      var dup = await _db
          .collection('transactions')
          .where('transRef', isEqualTo: transRef)
          .get();

      if (dup.docs.isNotEmpty) {
        _showSnackBar("สลิปนี้ถูกใช้งานไปแล้ว");
      } else if (amountInSlip == double.parse(_amountController.text)) {
        await _saveTransaction(amountInSlip, transRef, true);
      } else {
        _showSnackBar("ยอดเงินไม่ตรงกับสลิป (สลิปโอนจริง: $amountInSlip)");
      }
    } else {
      _showSnackBar("ตรวจสอบสลิปไม่ผ่าน กรุณาลองใหม่หรือติดต่อ Admin");
    }
  }

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
      Navigator.of(context, rootNavigator: true).pop();
      _showSnackBar(
        isAuto ? "เติมเงินสำเร็จแล้ว!" : "ส่งข้อมูลแล้ว รอ Admin อนุมัติ",
      );
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แจ้งฝากเงิน", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF11998E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ✅ แสดงบัตรธนาคารแบบสุ่ม
                  _buildRandomBankCard(),

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
                        const Text(
                          "ระบบอัตโนมัติ (เงินเข้าทันที)",
                          style: TextStyle(
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
                      height: 200,
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
                                  size: 50,
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
