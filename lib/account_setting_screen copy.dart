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
  String? _selectedBank; // เก็บค่าธนาคารที่เลือก
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  // ดึงข้อมูลเดิมมาแสดง (ถ้ามี)
  Future<void> _loadCurrentUserData() async {
    final userDoc = await _db
        .collection('users')
        .doc(_auth.currentUser?.uid)
        .get();
    if (userDoc.exists) {
      setState(() {
        _nameController.text = userDoc.data()?['fullName'] ?? "";
        _accNumController.text = userDoc.data()?['bankAccount'] ?? "";
        _selectedBank = userDoc.data()?['bankName'];
      });
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลสำเร็จ")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      setState(() => _isLoading = false);
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              "ชื่อ - นามสกุล",
              _nameController,
              Icons.person_outline,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              "เลขบัญชีธนาคาร",
              _accNumController,
              Icons.numbers,
              isNum: true,
            ),
            const SizedBox(height: 15),

            const Text(
              "เลือกธนาคาร",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // --- ส่วน Dropdown ดึงจาก Firebase Array ---
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('configs').doc('banks').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();

                // ดึง Array จากฟิลด์ bank_list
                List<dynamic> bankList = snapshot.data?['bank_list'] ?? [];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedBank,
                      hint: const Text("กรุณาเลือกธนาคาร"),
                      items: bankList.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank.toString(),
                          child: Text(bank.toString()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBank = val),
                    ),
                  ),
                );
              },
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11998E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _saveAccount,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "บันทึกข้อมูล",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNum = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
