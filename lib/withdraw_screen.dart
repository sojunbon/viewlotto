import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// หน้าจอสำหรับถอนเงิน โดยจะดึงข้อมูลบัญชีธนาคารของผู้ใช้มาแสดง (Disabled) และให้กรอกจำนวนเงินที่ต้องการถอน
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  String? _selectedBank;
  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserBankData();
  }

  // ✅ โหลดข้อมูลธนาคารและชื่อจากโปรไฟล์ผู้ใช้มาใส่ใน Controller และตัวแปร
  Future<void> _loadUserBankData() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    if (doc.exists) {
      setState(() {
        _fullNameController.text = doc.data()?['fullName'] ?? "";
        _bankAccountController.text = doc.data()?['bankAccount'] ?? "";
        // ✅ ดึงชื่อธนาคารมาเก็บเพื่อแสดงในหน้าจอ
        _selectedBank = doc.data()?['bankName'];
      });
    }
  }

  Future<void> _submitWithdraw(double currentCredit) async {
    final double? amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      _showMsg("กรุณาระบุจำนวนเงินที่ถูกต้อง");
      return;
    }

    if (amount > currentCredit) {
      _showMsg("ยอดเงินของคุณไม่เพียงพอ");
      return;
    }

    // เช็คว่า User ตั้งค่าบัญชีหรือยัง
    if (_bankAccountController.text.isEmpty || _selectedBank == null) {
      _showMsg("กรุณาตั้งค่าบัญชีธนาคารที่หน้าโปรไฟล์ก่อนทำรายการ");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // ✅ 🛠️ แก้ไข: ใช้ Auto-Generated ID จาก Firestore แทน millisecondsSinceEpoch เพื่อความปลอดภัย
      final withdrawRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid);

      batch.update(userRef, {'credit': FieldValue.increment(-amount)});

      batch.set(withdrawRef, {
        'transactionId': withdrawRef.id, // เก็บ ID ที่ระบบเจนให้ไว้ใน doc ด้วย
        'uid': _user!.uid,
        'displayName': _fullNameController.text,
        'amount': amount,
        'type': 'withdraw',
        'status': 'pending',
        'bankName': _selectedBank,
        'bankAccount': _bankAccountController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        _showMsg("ส่งคำขอถอนเงินเรียบร้อยแล้ว");
        Navigator.pop(context);
      }
    } catch (e) {
      _showMsg("เกิดข้อผิดพลาด: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          "ถอนเงิน",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          double credit = 0.0;
          if (snapshot.hasData && snapshot.data!.exists) {
            credit = (snapshot.data!.get('credit') ?? 0).toDouble();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(credit),
                const SizedBox(height: 25),
                const Text(
                  "ข้อมูลการรับเงิน (แก้ไขไม่ได้)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 15),

                // ✅ ชื่อ-นามสกุล (Disabled)
                _buildInput(
                  "ชื่อ - นามสกุล",
                  _fullNameController,
                  Icons.person_outline,
                  enabled: false,
                ),
                const SizedBox(height: 15),

                // ✅ Dropdown ธนาคาร (Disabled แต่ดึงค่ามาแสดงจากโปรไฟล์)
                _buildBankDropdown(enabled: false),
                const SizedBox(height: 15),

                // ✅ เลขบัญชี (Disabled)
                _buildInput(
                  "เลขบัญชีธนาคาร",
                  _bankAccountController,
                  Icons.account_balance_wallet_outlined,
                  enabled: false,
                ),

                const Divider(height: 40),

                const Text(
                  "ระบุจำนวนเงินที่ต้องการถอน",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                // ✅ ช่องระบุจำนวนเงิน (ตัวเดียวที่แก้ไขได้)
                _buildInput(
                  "จำนวนเงิน",
                  _amountController,
                  Icons.attach_money,
                  isNumber: true,
                  enabled: true,
                ),

                const SizedBox(height: 30),
                _buildSubmitButton(credit),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "* หากต้องการเปลี่ยนบัญชี กรุณาไปที่หน้า 'ตั้งค่าบัญชี'",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double credit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "ยอดเงินที่ถอนได้",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "฿ ${credit.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Dropdown แสดงชื่อธนาคารจากโปรไฟล์ (Lock ไม่ให้เลือกใหม่)
  Widget _buildBankDropdown({bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("เลือกธนาคาร"),
          value: _selectedBank,
          items: _selectedBank == null
              ? []
              : [
                  DropdownMenuItem(
                    value: _selectedBank,
                    child: Text(
                      _selectedBank!,
                      style: TextStyle(
                        color: enabled ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
          onChanged: null, // ✅ ล็อค Dropdown ให้อ่านอย่างเดียว
        ),
      ),
    );
  }

  Widget _buildSubmitButton(double credit) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _submitWithdraw(credit),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3D5D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "ยืนยันการถอนเงิน",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: enabled ? const Color(0xFF1A3D5D) : Colors.grey,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      style: TextStyle(
        color: enabled ? Colors.black : Colors.grey.shade700,
        fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
