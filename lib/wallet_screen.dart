import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ เพิ่ม import firestore
import 'package:firebase_auth/firebase_auth.dart'; // ✅ เพิ่ม import auth
import 'package:flutter/material.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "กระเป๋าเงิน",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // ✅ แสดงยอดเงินคงเหลือ (ดึงจาก Firebase จริง)
            _buildBalanceCard(),
            const SizedBox(height: 30),

            // ปุ่มฝากเงิน
            _menuButton(
              context,
              "แจ้งฝากเงิน",
              Icons.add_circle_outline,
              Colors.green,
              const DepositScreen(),
            ),

            const SizedBox(height: 15),

            // ปุ่มถอนเงิน
            _menuButton(
              context,
              "แจ้งถอนเงิน",
              Icons.remove_circle_outline,
              Colors.redAccent,
              const WithdrawScreen(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ แก้ไขฟังก์ชันนี้ให้ดึงข้อมูล Real-time
  Widget _buildBalanceCard() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        double credit = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            credit = (data['credit'] ?? 0).toDouble();
          } catch (e) {
            credit = 0.0;
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                "ยอดเงินคงเหลือ",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                // "฿ ${credit.toStringAsFixed(2)}", // ✅ แสดงยอดเงินจริงจาก Firebase
                NumberFormat(
                  '#,###.00',
                ).format(credit), // ✅ ใช้ intl ในการจัดรูปแบบตัวเลข
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget targetPage,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetPage),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
