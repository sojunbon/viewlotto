import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();

  bool _isLoading = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  // ฟังก์ชันส่งคำขอถอนเงิน
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

    if (_bankAccountController.text.isEmpty ||
        _bankNameController.text.isEmpty) {
      _showMsg("กรุณากรอกข้อมูลบัญชีธนาคารให้ครบถ้วน");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final String docId = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. หักเครดิต User ทันที
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(_user!.uid),
        {'credit': FieldValue.increment(-amount)},
      );

      // 2. สร้างรายการถอนใน transactions
      batch.set(
        FirebaseFirestore.instance.collection('transactions').doc(docId),
        {
          'uid': _user!.uid,
          'displayName': _user!.displayName ?? 'User',
          'amount': amount,
          'type': 'withdraw', // ระบุว่าเป็นรายการถอน
          'status': 'pending',
          'bankName': _bankNameController.text.trim(),
          'bankAccount': _bankAccountController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

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
      appBar: AppBar(
        title: const Text(
          "ถอนเงิน",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
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
                // แสดงยอดเงินปัจจุบัน
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "ยอดเงินที่ถอนได้",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "฿ ${credit.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                const Text(
                  "ระบุข้อมูลการรับเงิน",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                _buildInput(
                  "ชื่อธนาคาร (เช่น กสิกร, ไทยพาณิชย์)",
                  _bankNameController,
                  Icons.account_balance,
                ),
                const SizedBox(height: 15),
                _buildInput(
                  "เลขบัญชีธนาคาร",
                  _bankAccountController,
                  Icons.numbers,
                ),
                const SizedBox(height: 15),
                _buildInput(
                  "จำนวนเงินที่ต้องการถอน",
                  _amountController,
                  Icons.attach_money,
                  isNumber: true,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submitWithdraw(credit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3D5D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "ยืนยันการถอนเงิน",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                const Center(
                  child: Text(
                    "* เงินจะถูกหักจากบัญชีทันที และรอแอดมินตรวจสอบโอนเงิน",
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
