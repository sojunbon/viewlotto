import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    const HomeScreen(),
    const WalletScreen(),
    const BetTypeScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
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
            label: "หน้าแรก",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: "ฝาก/ถอน",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.casino_outlined),
            label: "แทงหวย",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: "โพย",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
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
                // "฿ ${credit.toStringAsFixed(2)}",
                NumberFormat('#,###.00').format(credit),
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
// ✅ หน้า BetTypeScreen (Clean Version - No Debug)
// ------------------------------------------------------------------
class BetTypeScreen extends StatefulWidget {
  const BetTypeScreen({super.key});

  @override
  State<BetTypeScreen> createState() => _BetTypeScreenState();
}

class _BetTypeScreenState extends State<BetTypeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime? _getClosingDateTime(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      String closeStr = data['closeTime'] ?? "15:30";
      final DateFormat timeFormat = DateFormat('HH:mm');
      DateTime closeTimeParsed = timeFormat.parse(closeStr);

      DateTime targetClosing;
      String? specificDatesStr = data['specificDates'];

      if (specificDatesStr != null && specificDatesStr.isNotEmpty) {
        List<int> openDates = specificDatesStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .toList();
        List<DateTime> upcomingDates = [];
        for (int day in openDates) {
          if (day == 0) continue;
          DateTime d = DateTime(
            now.year,
            now.month,
            day,
            closeTimeParsed.hour,
            closeTimeParsed.minute,
          );
          if (d.isBefore(now))
            d = DateTime(
              now.year,
              now.month + 1,
              day,
              closeTimeParsed.hour,
              closeTimeParsed.minute,
            );
          upcomingDates.add(d);
        }
        upcomingDates.sort();
        targetClosing = upcomingDates.first;
      } else {
        targetClosing = DateTime(
          now.year,
          now.month,
          now.day,
          closeTimeParsed.hour,
          closeTimeParsed.minute,
        );
        if (targetClosing.isBefore(now))
          targetClosing = targetClosing.add(const Duration(days: 1));
      }
      return targetClosing;
    } catch (e) {
      return null;
    }
  }

  String _getCountdownText(DateTime closingTime) {
    final now = DateTime.now();
    final diff = closingTime.difference(now);
    if (diff.isNegative) return "ปิดรับแทง";
    if (diff.inDays > 0) return "${diff.inDays} วัน ${diff.inHours % 24} ชม.";
    return "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  bool _isLottoOpen(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      if (data['lottostatus'] == false) return false;

      String? specificDatesStr = data['specificDates'];

      if (specificDatesStr != null && specificDatesStr.trim().isNotEmpty) {
        List<int> openDates = specificDatesStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .where((e) => e > 0)
            .toList();
        int preOpenDays = data['preOpenDays'] ?? 0;
        for (int day in openDates) {
          DateTime targetDate = DateTime(now.year, now.month, day);
          if (todayMidnight.isAfter(targetDate))
            targetDate = DateTime(now.year, now.month + 1, day);
          int diffDays = targetDate.difference(todayMidnight).inDays;
          if (diffDays == 0) return _checkTime(data, now);
          if (diffDays > 0 && diffDays <= preOpenDays) return true;
        }
        return false;
      } else {
        var rawPlayDays = data['playDays'];
        List<int> playDays = [];
        if (rawPlayDays is List)
          playDays = rawPlayDays
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .toList();
        if (playDays.contains(now.weekday)) return _checkTime(data, now);
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  bool _checkTime(Map<String, dynamic> data, DateTime now) {
    try {
      final DateFormat tf = DateFormat('HH:mm');
      DateTime oT = tf.parse((data['openTime'] ?? "00:01").toString());
      DateTime cT = tf.parse((data['closeTime'] ?? "23:59").toString());
      DateTime openToday = DateTime(
        now.year,
        now.month,
        now.day,
        oT.hour,
        oT.minute,
      );
      DateTime closeToday = DateTime(
        now.year,
        now.month,
        now.day,
        cT.hour,
        cT.minute,
      );
      return now.isAfter(openToday) && now.isBefore(closeToday);
    } catch (e) {
      return true;
    }
  }

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
              childAspectRatio: 0.95,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isOpen = _isLottoOpen(data);
              DateTime? closingTime = _getClosingDateTime(data);

              return AbsorbPointer(
                absorbing: !isOpen,
                child: Opacity(
                  opacity: isOpen ? 1.0 : 0.6,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NumberInputScreen(lottoList: [data]),
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
                              height: 50,
                              width: 50,
                            )
                          else
                            const Icon(
                              Icons.casino,
                              size: 40,
                              color: Color(0xFF11998E),
                            ),
                          const SizedBox(height: 5),
                          Text(
                            data['lottoname'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (isOpen && closingTime != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getCountdownText(closingTime),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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
