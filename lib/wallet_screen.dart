import 'package:flutter/material.dart';
import 'deposit_screen.dart'; // ✅ อย่าลืม import หน้าแจ้งฝากที่ทำไว้

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
            // แสดงยอดเงินคงเหลือ (ตัวอย่าง)
            _buildBalanceCard(),
            const SizedBox(height: 30),

            // ปุ่มฝากเงิน
            _menuButton(
              context,
              "แจ้งฝากเงิน",
              Icons.add_circle_outline,
              Colors.green,
              const DepositScreen(), // ลิงก์ไปหน้า Deposit
            ),

            const SizedBox(height: 15),

            // ปุ่มถอนเงิน
            _menuButton(
              context,
              "แจ้งถอนเงิน",
              Icons.remove_circle_outline,
              Colors.redAccent,
              const Center(
                child: Text("หน้าถอนเงินกำลังพัฒนา"),
              ), // เปลี่ยนเป็น WithdrawScreen ภายหลัง
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Text(
            "ยอดเงินคงเหลือ",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          SizedBox(height: 10),
          Text(
            "฿ 0.00",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
