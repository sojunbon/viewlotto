import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// หน้าจอสำหรับแสดงประวัติการแทงหวยของผู้ใช้ โดยดึงข้อมูลจาก Firestore แบบ Real-time และสามารถดูรายละเอียดโพยได้
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedBillId;
  Map<String, dynamic>? _selectedBillData;
  Map<String, Map<String, String>> _lottoMasterMap = {};

  @override
  void initState() {
    super.initState();
    _fetchLottoMasterData();
  }

  Future<void> _fetchLottoMasterData() async {
    try {
      final snap = await _db
          .collection('configs')
          .doc('lottogen')
          .collection('lottogrid')
          .get();
      Map<String, Map<String, String>> tempMap = {};
      for (var doc in snap.docs) {
        final d = doc.data();
        String type = d['lottotype'] ?? "";
        if (type.isNotEmpty) {
          tempMap[type] = {
            'name': d['lottoname'] ?? "ไม่ระบุชื่อ",
            'link': d['lottolink'] ?? "",
          };
        }
      }
      if (mounted) setState(() => _lottoMasterMap = tempMap);
    } catch (e) {
      debugPrint("🚨 Master Data Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return WillPopScope(
      onWillPop: () async {
        if (_selectedBillId != null) {
          setState(() => _selectedBillId = null);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: _selectedBillId == null
              ? _buildMainHistory(user?.uid)
              : _buildFullBillDetail(
                  _selectedBillId!,
                ), // ส่งแค่ ID เพื่อไปดึง Stream ใหม่
        ),
      ),
    );
  }

  Widget _buildMainHistory(String? uid) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _buildRealTimeSummary(uid),
          _buildTabBar(),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _buildBillList(uid, 'all'),
                _buildBillList(uid, 'all'),
                _buildBillList(uid, 'completed'),
                _buildBillList(uid, 'pending'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeSummary(String? uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('bills').where('uid', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        double todayTotal = 0.0;
        double winTotal = 0.0;
        double pendingTotal = 0.0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            double netPay = (data['net_pay'] ?? 0.0).toDouble();
            double totalWin = (data['total_win'] ?? 0.0).toDouble();
            String status = data['status'] ?? "";
            DateTime billDate = (data['timestamp'] as Timestamp).toDate();
            bool isToday =
                billDate.day == now.day &&
                billDate.month == now.month &&
                billDate.year == now.year;

            if (isToday) todayTotal += netPay;
            if (status == 'win') winTotal += totalWin;
            if (status == 'pending') pendingTotal += netPay;
          }
        }
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _sumItem("ยอดแทงวันนี้", todayTotal.toStringAsFixed(2)),
              _sumItem("ออกผลแล้ว", winTotal.toStringAsFixed(2)),
              _sumItem("ยังไม่ออกผล", pendingTotal.toStringAsFixed(2)),
            ],
          ),
        );
      },
    );
  }

  Widget _sumItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBillList(String? uid, String filter) {
    Query query = _db.collection('bills').where('uid', isEqualTo: uid);
    if (filter == 'pending')
      query = query.where('status', isEqualTo: 'pending');
    if (filter == 'completed')
      query = query.where('status', whereIn: ['win', 'lose']);

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildTicketCard(data, snapshot.data!.docs[index].id);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data, String billId) {
    String dateStr = data['timestamp'] != null
        ? DateFormat(
            'dd MMMM 2026',
          ).format((data['timestamp'] as Timestamp).toDate())
        : "";
    String timeStr = data['timestamp'] != null
        ? DateFormat(
            'HH:mm:ss',
          ).format((data['timestamp'] as Timestamp).toDate())
        : "";

    // ✅ ตรวจสอบสถานะเพื่อกำหนดสี
    String status = data['status'] ?? 'pending';
    bool isPending = status == 'pending';
    bool isWin = status == 'win';
    bool isLose = status == 'lose';

    Color statusColor = isPending
        ? const Color(0xFF00A859)
        : (isWin ? Colors.green : Colors.red);
    String statusText = isPending
        ? "สถานะ: รอออกผลรางวัล"
        : (isWin ? "สถานะ: ถูกรางวัล ✨" : "สถานะ: ไม่ถูกรางวัล");

    return FutureBuilder<QuerySnapshot>(
      future: _db
          .collection('bets')
          .where('billId', isEqualTo: billId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        String lottoName = "กำลังโหลด...";
        String? flagUrl;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final betData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          String lottoKey = (betData['lotto_key'] ?? "").toString();
          if (_lottoMasterMap.containsKey(lottoKey)) {
            lottoName = _lottoMasterMap[lottoKey]!['name']!;
            flagUrl = _lottoMasterMap[lottoKey]!['link']!;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0F2F5),
                      image: (flagUrl != null && flagUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(flagUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (flagUrl == null || flagUrl.isEmpty)
                        ? const Icon(Icons.flag, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lottoName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "เงินเดิมพัน : ",
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            //  "฿ ${(data['net_pay'] ?? 0.0).toDouble().toStringAsFixed(2)}",
                            "฿ ${NumberFormat('#,###.00').format((data['net_pay'] ?? 0.0).toDouble())}",
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isPending
                        ? Icons.access_time
                        : (isWin ? Icons.check_circle : Icons.cancel),
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Divider(height: 25),
              Row(
                children: [
                  const Text("ผลแพ้ชนะ: ", style: TextStyle(fontSize: 14)),
                  Text(
                    isWin
                        ? "฿ ${NumberFormat('#,###.00').format((data['total_win'] ?? 0.0).toDouble())}" //"฿ ${(data['total_win'] ?? 0.0).toDouble().toStringAsFixed(2)}"
                        : "฿ 0",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isWin
                          ? Colors.green
                          : (isLose ? Colors.red : Colors.black),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _selectedBillId = billId;
                      _selectedBillData = data;
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      elevation: 0,
                    ),
                    child: const Text(
                      "ดูโพย",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ หน้าที่สอง: bets (รายละเอียดรายการ)
  Widget _buildFullBillDetail(String billId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('bills').doc(billId).snapshots(),
      builder: (context, billSnap) {
        if (!billSnap.hasData)
          return const Center(child: CircularProgressIndicator());
        final billData = billSnap.data!.data() as Map<String, dynamic>;
        bool isWin = billData['status'] == 'win';

        return Column(
          children: [
            AppBar(
              title: const Text(
                "รายละเอียดบิล",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFF11998E),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => setState(() => _selectedBillId = null),
              ),
            ),
            if (isWin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                color: Colors.white,
                child: Column(
                  children: [
                    const Text(
                      "ยอดเงินรางวัลที่ได้รับ",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "฿ ${NumberFormat('#,###.00').format((billData['total_win'] ?? 0.0).toDouble())}",
                      //"฿${(billData['total_win'] ?? 0.0).toDouble().toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('bets')
                    .where('billId', isEqualTo: billId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final bet =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                      String betStatus = bet['status'] ?? 'pending';
                      double payout =
                          (bet['price_bet'] ?? 0.0).toDouble() *
                          (bet['rate_pay'] ?? 0.0).toDouble();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: betStatus == 'win'
                                  ? Colors.green
                                  : (betStatus == 'lose'
                                        ? Colors.red
                                        : Colors.grey.shade100),
                              child: Text(
                                "${bet['number']}",
                                style: TextStyle(
                                  color:
                                      (betStatus == 'win' ||
                                          betStatus == 'lose')
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${bet['category']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "฿${(bet['price_bet'] ?? 0.0).toDouble().toStringAsFixed(0)} x ${NumberFormat('#,###.00').format((bet['rate_pay'] ?? 0.0).toDouble())}",
                                    // "฿${(bet['price_bet'] ?? 0.0).toDouble().toStringAsFixed(0)} x ${(bet['rate_pay'] ?? 0.0).toDouble().toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  "ยอดที่จะได้รับ",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  "฿ ${NumberFormat('#,###.00').format((payout ?? 0.0).toDouble())}", //"฿${payout.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: betStatus == 'win'
                                        ? Colors.green
                                        : (betStatus == 'lose'
                                              ? Colors.red
                                              : Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: const TabBar(
      isScrollable: true,
      labelColor: Color(0xFF00A859),
      unselectedLabelColor: Colors.grey,
      indicatorColor: Color(0xFF00A859),
      tabs: [
        Tab(text: "ทั้งหมด"),
        Tab(text: "โพยที่ซื้อ"),
        Tab(text: "ออกผลแล้ว"),
        Tab(text: "ยังไม่ออก"),
      ],
    ),
  );
}
