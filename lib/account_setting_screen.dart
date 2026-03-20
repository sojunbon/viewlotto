import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountSettingScreen extends StatefulWidget {
  const AccountSettingScreen({super.key});

  @override
  State<AccountSettingScreen> createState() => _AccountSettingScreenState();
}

class _AccountSettingScreenState extends State<AccountSettingScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accNumController = TextEditingController();
  String? _selectedBank;
  bool _isLoading = false;
  bool _isAlreadySet = false; // ✅ ตัวแปรเช็คว่าเคยบันทึกหรือยัง

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final userDoc = await _db
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data();
      if (mounted) {
        setState(() {
          _nameController.text = data?['fullName'] ?? "";
          _accNumController.text = data?['bankAccount'] ?? "";
          _selectedBank = data?['bankName'];

          // ✅ ถ้ามีเลขบัญชีอยู่แล้ว ให้ถือว่าตั้งค่าแล้ว
          if (_accNumController.text.isNotEmpty) {
            _isAlreadySet = true;
          }
        });
      }
    }
  }

  Future<void> _saveAccount() async {
    if (_nameController.text.isEmpty ||
        _accNumController.text.isEmpty ||
        _selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _db.collection('users').doc(_auth.currentUser?.uid).update({
        'fullName': _nameController.text,
        'bankAccount': _accNumController.text,
        'bankName': _selectedBank,
      });
      if (mounted) {
        setState(() => _isAlreadySet = true); // ✅ ล็อกหน้าจอทันทีหลังบันทึก
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("บันทึกข้อมูลบัญชีสำเร็จ")),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ตั้งค่าบัญชีธนาคาร",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isAlreadySet)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "บันทึกข้อมูลแล้ว หากต้องการแก้ไขกรุณาติดต่อแอดมิน",
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              _buildTextField(
                "ชื่อ - นามสกุล",
                _nameController,
                Icons.person_outline,
                enabled: !_isAlreadySet,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                "เลขบัญชีธนาคาร",
                _accNumController,
                Icons.numbers,
                isNum: true,
                enabled: !_isAlreadySet,
              ),
              const SizedBox(height: 25),

              const Text(
                "เลือกธนาคาร",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),

              // --- Dropdown Bank ---
              StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('configs').doc('bank').snapshots(),
                builder: (context, snapshot) {
                  List<dynamic> bankList = [];
                  if (snapshot.hasData && snapshot.data!.exists) {
                    bankList = snapshot.data!.get('bankname') ?? [];
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                      color: _isAlreadySet ? Colors.grey[100] : Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedBank,
                        hint: const Text("กรุณาเลือกธนาคาร"),
                        items: bankList
                            .map(
                              (bank) => DropdownMenuItem<String>(
                                value: bank.toString(),
                                child: Text(
                                  bank.toString(),
                                  style: TextStyle(
                                    color: _isAlreadySet
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isAlreadySet
                            ? null
                            : (val) => setState(() => _selectedBank = val),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // ✅ แสดงปุ่มบันทึกเฉพาะตอนที่ยังไม่ได้ตั้งค่าเท่านั้น
              if (!_isAlreadySet)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF11998E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _isLoading ? null : _saveAccount,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "บันทึกข้อมูล",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNum = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled, // ✅ ล็อกการพิมพ์
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
      style: TextStyle(color: enabled ? Colors.black : Colors.grey),
    );
  }
}
