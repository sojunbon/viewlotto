import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ส่วนของ Import หน้าต่างๆ
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
  int _selectedIndex = 0;
  final User? _user = FirebaseAuth.instance.currentUser;

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
        actions: [_buildBalanceAction()],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF11998E),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
          var data = snapshot.data!.data() as Map<String, dynamic>;
          credit = (data['credit'] ?? 0).toDouble();
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
// ✅ หน้า BetTypeScreen (Logic ปรับปรุงใหม่ แม่นยำเรื่องวันที่ล่วงหน้า)
// ------------------------------------------------------------------
class BetTypeScreen extends StatelessWidget {
  const BetTypeScreen({super.key});

  bool _isLottoOpen(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final todayWeekday = now.weekday;

      if (data['lottostatus'] == false) return false;

      int preOpenDays = data['preOpenDays'] ?? 0;
      String? specificDatesStr = data['specificDates'];

      if (specificDatesStr != null && specificDatesStr.isNotEmpty) {
        List<int> openDates = specificDatesStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .toList();
        bool isDateMatch = false;

        for (int openDate in openDates) {
          if (openDate == 0) continue;

          // 1. สร้างวันที่หวยออกของ "เดือนนี้"
          DateTime targetDate = DateTime(now.year, now.month, openDate);

          // 2. ✅ จุดสำคัญ: ถ้าวันนี้ (24 มี.ค.) มันเลยวันหวยออกของเดือนนี้ไปแล้ว (16 มี.ค.)
          // ให้ขยับ targetDate ไปเป็นเดือนหน้า (1 เม.ย.) อัตโนมัติ
          if (todayMidnight.isAfter(targetDate)) {
            targetDate = DateTime(now.year, now.month + 1, openDate);
          }

          // 3. คำนวณหาความต่างของจำนวนวัน
          int dayDiff = targetDate.difference(todayMidnight).inDays;

          // ถ้าอยู่ในช่วงวันที่ตั้งค่าไว้ (เช่น 0-10 วันก่อนหวยออก)
          if (dayDiff >= 0 && dayDiff <= preOpenDays) {
            isDateMatch = true;
            break;
          }
        }
        if (!isDateMatch) return false;
      } else {
        List<dynamic> playDays = data['playDays'] ?? [1, 2, 3, 4, 5, 6, 7];
        if (!playDays.contains(todayWeekday)) return false;
      }

      // 5. เช็คเวลาเปิด-ปิด
      String openStr = data['openTime'] ?? "06:00";
      String closeStr = data['closeTime'] ?? "15:30";
      final DateFormat timeFormat = DateFormat('HH:mm');

      DateTime openTime = timeFormat.parse(openStr);
      DateTime closeTime = timeFormat.parse(closeStr);

      openTime = DateTime(
        now.year,
        now.month,
        now.day,
        openTime.hour,
        openTime.minute,
      );
      closeTime = DateTime(
        now.year,
        now.month,
        now.day,
        closeTime.hour,
        closeTime.minute,
      );

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return false;
    }
  }

  /*
  bool _isLottoOpen(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      // สร้าง DateTime ของวันนี้เวลา 00:00 น. เพื่อใช้คำนวณระยะห่างของวัน
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final todayWeekday = now.weekday; // 1=จันทร์, 7=อาทิตย์

      // 1. เช็คสถานะเปิด/ปิด จาก Admin (Manual Switch)
      if (data['lottostatus'] == false) return false;

      // 2. ดึงค่าเปิดล่วงหน้ากี่วัน
      int preOpenDays = data['preOpenDays'] ?? 0;

      // 3. เช็คเงื่อนไข "ระบุวันที่" (เช่น 1, 16)
      String? specificDatesStr = data['specificDates'];
      if (specificDatesStr != null && specificDatesStr.isNotEmpty) {
        List<int> openDates = specificDatesStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .toList();
        bool isDateMatch = false;

        for (int openDate in openDates) {
          if (openDate == 0) continue;

          // สร้างวันที่หวยออกของเดือนนี้
          DateTime targetDate = DateTime(now.year, now.month, openDate);

          // ✅ คำนวณหาความต่างของจำนวนวัน (ใช้ .difference)
          // วันหวยออก ลบ วันปัจจุบัน
          int dayDiff = targetDate.difference(todayMidnight).inDays;

          // เงื่อนไข:
          // - ต้องไม่เลยวันหวยออก (dayDiff >= 0)
          // - ต้องอยู่ในช่วงวันที่เปิดรับล่วงหน้า (dayDiff <= preOpenDays)
          if (dayDiff >= 0 && dayDiff <= preOpenDays) {
            isDateMatch = true;
            break;
          }
        }
        if (!isDateMatch) return false;
      } else {
        // 4. ถ้าไม่มีระบุวันที่ ให้เช็คตามวันในสัปดาห์ (จันทร์-อาทิตย์)
        List<dynamic> playDays = data['playDays'] ?? [1, 2, 3, 4, 5, 6, 7];
        if (!playDays.contains(todayWeekday)) return false;
      }

      // 5. เช็คเวลาเปิด-ปิด (HH:mm)
      String openStr = data['openTime'] ?? "06:00";
      String closeStr = data['closeTime'] ?? "15:30";
      final DateFormat timeFormat = DateFormat('HH:mm');

      DateTime openTime = timeFormat.parse(openStr);
      DateTime closeTime = timeFormat.parse(closeStr);

      openTime = DateTime(
        now.year,
        now.month,
        now.day,
        openTime.hour,
        openTime.minute,
      );
      closeTime = DateTime(
        now.year,
        now.month,
        now.day,
        closeTime.hour,
        closeTime.minute,
      );

      return now.isAfter(openTime) && now.isBefore(closeTime);
    } catch (e) {
      return false;
    }
  }
  */

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
              bool isOpen = _isLottoOpen(data);

              return AbsorbPointer(
                absorbing: !isOpen,
                child: Opacity(
                  opacity: isOpen ? 1.0 : 0.6,
                  child: InkWell(
                    onTap: () {
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
                          if (data['lottolink'] != null &&
                              data['lottolink'] != "")
                            Image.network(
                              data['lottolink'],
                              height: 55,
                              width: 55,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.casino, size: 40),
                            )
                          else
                            const Icon(
                              Icons.casino,
                              size: 40,
                              color: Color(0xFF11998E),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            data['lottoname'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOpen ? "🟢 เปิดรับแทง" : "🔴 ปิดรับแทง",
                            style: TextStyle(
                              color: isOpen ? Colors.green : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
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
