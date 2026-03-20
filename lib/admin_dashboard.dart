import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kDeepBlue = Color(0xFF1A3D5D);
const Color kMainGreen = Color(0xFF11998E);

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "แผงควบคุมผู้ดูแลระบบ",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kDeepBlue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // ไม่ต้อง Navigate เอง เพราะ AuthGate ใน main.dart จะพาไปหน้า Login อัตโนมัติ
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ส่วนหัวโชว์สถานะ Admin
          _buildHeader(),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(15),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _adminMenu(
                  context,
                  "จัดการผู้ใช้งาน",
                  Icons.people_alt,
                  Colors.blue,
                  '/user_management',
                ),
                _adminMenu(
                  context,
                  "ตั้งค่าหวย",
                  Icons.settings_suggest,
                  Colors.orange,
                  '/lotto_config', // ✅ ใส่ชื่อ Route ที่เราเพิ่มใน main.dart
                ),
                _adminMenu(
                  context,
                  "ดูโพยทั้งหมด",
                  Icons.receipt_long,
                  Colors.purple,
                  null,
                ),
                _adminMenu(
                  context,
                  "สลับไปหน้า User",
                  Icons.swap_horiz,
                  Colors.teal,
                  '/home',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: kDeepBlue,
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user?.email ?? "Admin",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "สถานะ: ผู้ดูแลระบบสูงสุด",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _adminMenu(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String? route,
  ) {
    return InkWell(
      onTap: () {
        if (route != null) {
          Navigator.pushNamed(context, route);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("กำลังพัฒนาส่วนนี้...")));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle, // ✅ แก้ไขจาก BoxType เป็น BoxShape
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
