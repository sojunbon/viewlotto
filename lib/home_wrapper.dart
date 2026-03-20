import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ ส่วนของ Import (ตรวจสอบว่าไฟล์เหล่านี้มีอยู่ในโปรเจกต์ของคุณ)
import 'number_input_screen.dart';
import 'wallet_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'lottoresult_screen.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0; // ตัวควบคุมหน้าปัจจุบัน
  final User? _user = FirebaseAuth.instance.currentUser;

  // ✅ 1. รายการหน้าหลัก 5 เมนู (เชื่อมโยง Class หน้าต่างๆ ไว้ที่นี่)
  // ลำดับต้องตรงกับ BottomNavigationBarItem ด้านล่าง
  late final List<Widget> _pages = [
    const HomeScreen(), // Index 0: หน้าผลรางวัล
    const WalletScreen(), // Index 1: ฝาก/ถอน
    const BetTypeScreen(), // Index 2: แทงหวย (เลือกประเภท)
    const HistoryScreen(), // Index 3: โพย (รายการที่แทง)
    const ProfileScreen(), // Index 4: โปรไฟล์
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- AppBar แสดงยอดเงิน Real-time ---
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3D5D),
        elevation: 0,
        title: const Text(
          "LOTTO VIP",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _buildBalanceAction(), // แสดงเครดิตมุมขวาบน
        ],
      ),

      // ✅ 2. ใช้ IndexedStack เพื่อรักษาข้อมูลในหน้าจอ (สลับหน้าแล้วข้อมูลไม่หาย)
      body: IndexedStack(index: _selectedIndex, children: _pages),

      // --- 3. เมนูนำทางด้านล่าง 5 เมนู ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF11998E),
        unselectedItemColor: Colors.grey,
        type:
            BottomNavigationBarType.fixed, // แสดงชื่อเมนูทั้งหมดแม้จะมีหลายเมนู
        selectedFontSize: 10,
        unselectedFontSize: 10,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "หน้าแรก",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: "ฝาก/ถอน",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.casino_outlined),
            activeIcon: Icon(Icons.casino),
            label: "แทงหวย",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: "โพย",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "โปรไฟล์",
          ),
        ],
      ),
    );
  }

  // ✅ วิดเจ็ตดึงยอดเงินจาก Firestore แบบ Real-time
  Widget _buildBalanceAction() {
    if (_user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        double credit = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            // ดึงค่า credit และแปลงเป็น double ป้องกัน Error
            var data = snapshot.data!.data() as Map<String, dynamic>;
            credit = (data['credit'] ?? 0).toDouble();
          } catch (e) {
            credit = 0.0;
          }
        }

        return Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.yellow,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                "฿ ${credit.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              // ปุ่มกดเพื่อไปหน้าฝากเงินทันที (เปลี่ยนไป index 1)
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 1),
                child: const Icon(
                  Icons.add_circle,
                  color: Colors.greenAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// ✅ 4. หน้า BetTypeScreen (หน้าเลือกประเภทหวย)
// ------------------------------------------------------------------
class BetTypeScreen extends StatelessWidget {
  const BetTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("โหลดข้อมูลไม่สำเร็จ"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return InkWell(
                onTap: () {
                  // ลิงก์ไปหน้ากรอกตัวเลข พร้อมส่ง lottoKey ไปดึงราคา
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NumberInputScreen(
                        lottoTitle: data['lottoname'] ?? 'หวย',
                        lottoKey: data['lottotype'] ?? 'unknown',
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (data['lottolink'] != null && data['lottolink'] != "")
                        Image.network(
                          data['lottolink'],
                          height: 60,
                          width: 60,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.casino, size: 40),
                        )
                      else
                        const Icon(
                          Icons.casino,
                          size: 40,
                          color: Color(0xFF11998E),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        data['lottoname'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "เปิดรับแทง",
                        style: TextStyle(color: Colors.green, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
