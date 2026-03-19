import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import หน้ากรอกเลขที่คุณแยกไฟล์ไว้
import 'number_input_screen.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;

  // รายการหน้าจอหลัก
  final List<Widget> _screens = [
    const HomeScreen(), // Index 0: หน้าหลักผลรางวัล
    const WalletScreen(), // Index 1: ฝาก/ถอน
    const BetTypeScreen(), // Index 2: หน้าเลือกประเภทหวย (Dynamic)
    const HistoryScreen(), // Index 3: โพย
    const ProfileScreen(), // Index 4: โปรไฟล์
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF11998E),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'ฝาก/ถอน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.casino_outlined),
              activeIcon: Icon(Icons.casino),
              label: 'แทงหวย',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'โพย',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// --- หน้าเลือกประเภทหวย (ดึงข้อมูลจาก Firebase configs > lottogen > lottogrid) ---
class BetTypeScreen extends StatelessWidget {
  const BetTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "เลือกประเภทหวย",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ ดึงข้อมูลจาก Sub-collection และเรียงตามฟิลด์ 'number'
        stream: FirebaseFirestore.instance
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number') // เรียงลำดับจากน้อยไปมาก
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("เกิดข้อผิดพลาดในการโหลดข้อมูล"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF11998E)),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีข้อมูลหวยในระบบ"));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // ดึงข้อมูลจากฟิลด์ที่คุณกำหนด
              final String name = data['lottoname'] ?? 'หวย';
              final String type = data['lottotype'] ?? 'unknown';
              final String imageLink = data['lottolink'] ?? '';

              return InkWell(
                onTap: () {
                  // ✅ ส่ง lottoname ไปโชว์ และ lottotype ไปเช็ค Config เลข 4 ตัว
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NumberInputScreen(lottoTitle: name, lottoKey: type),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ✅ แสดงรูปภาพจาก lottolink (ถ้าไม่มีให้ใช้ไอคอนสำรอง)
                      imageLink.isNotEmpty
                          ? Image.network(
                              imageLink,
                              height: 60,
                              width: 60,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.casino, size: 40),
                            )
                          : const Icon(
                              Icons.casino,
                              size: 40,
                              color: Color(0xFF11998E),
                            ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "เปิดรับแทง",
                        style: TextStyle(color: Colors.green, fontSize: 11),
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

// --- หน้าจออื่นๆ (Mockup) ---

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("หน้าหลักผลรางวัล")),
      body: const Center(child: Text("แสดงผลหวยล่าสุดที่นี่")),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ฝาก/ถอน")),
      body: const Center(child: Text("ระบบการเงิน")),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("โพยของฉัน")),
      body: const Center(child: Text("ประวัติการแทงทั้งหมด")),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("โปรไฟล์")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => FirebaseAuth.instance.signOut(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text(
            "ออกจากระบบ",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
