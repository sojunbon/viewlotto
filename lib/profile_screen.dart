import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- ส่วนหัวโปรไฟล์ ---
            _buildHeader(user),

            const SizedBox(height: 20),

            // --- ส่วนแสดงยอดเงิน (Real-time) ---
            _buildBalanceCard(user?.uid),

            const SizedBox(height: 20),

            // --- รายการเมนูต่างๆ ---
            _buildMenuSection(context),

            const SizedBox(height: 30),

            // --- ปุ่มออกจากระบบ ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  // เมื่อ Logout ให้เด้งไปหน้า Login (ถ้าคุณตั้งชื่อ Route ไว้)
                  // Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "ออกจากระบบ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // วิดเจ็ตส่วนหัว (Avatar และชื่อ)
  Widget _buildHeader(User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1A3D5D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 15),
          Text(
            user?.displayName ?? "ผู้ใช้งานทั่วไป",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            user?.email ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // วิดเจ็ตแสดงยอดเงินคงเหลือ ดึงจาก Firestore
  Widget _buildBalanceCard(String? uid) {
    if (uid == null) return const SizedBox();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        double credit = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          credit = (snapshot.data!.get('credit') ?? 0).toDouble();
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ยอดเงินคงเหลือ", style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 5),
                  Text(
                    "เครดิตในบัญชี",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                "฿ ${credit.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF11998E),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ส่วนรวมเมนู
  Widget _buildMenuSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _menuTile(Icons.history, "ประวัติการแทงหวย", () {}),
          const Divider(height: 1),
          _menuTile(
            Icons.account_balance_wallet_outlined,
            "ประวัติการฝาก/ถอน",
            () {},
          ),
          const Divider(height: 1),
          _menuTile(Icons.settings_outlined, "ตั้งค่าบัญชี", () {}),
          const Divider(height: 1),
          _menuTile(Icons.help_outline, "ศูนย์ช่วยเหลือ / ติดต่อแอดมิน", () {}),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1A3D5D)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}
