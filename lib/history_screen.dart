import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 🟢 ประวัติการแทง (History Screen)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedBillId;
  Map<String, dynamic>? _selectedBillData;

  // ✅ เก็บข้อมูลหวยทั้งหมดไว้ใน Map (lottotype -> {name, link})
  Map<String, Map<String, String>> _lottoMasterMap = {};

  @override
  void initState() {
    super.initState();
    _fetchLottoMasterData();
  }

  // ✅ ดึงข้อมูล Master จาก configs/lottogen/lottogrid
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
            'name': d['lottoname'] ?? "ไม่ระบุชื่อ", // ดึงชื่อจาก config
            'link': d['lottolink'] ?? "", // ดึงลิงก์รูปจาก config
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
              : _buildFullBillDetail(_selectedBillId!, _selectedBillData!),
        ),
      ),
    );
  }

  Widget _buildMainHistory(String? uid) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _buildTopSummary(),
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
    bool isPending = data['status'] == 'pending';
    bool isWin = data['status'] == 'win';

    return FutureBuilder<QuerySnapshot>(
      // ✅ ดึงลัดจาก bets เพื่อเอา lotto_key มาตัวเดียวพอ
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

          // ✅ Mapping: เอา lotto_key จาก bet ไปหา ชื่อและรูป ใน Master Map
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
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "🛡️ ฿ ${(data['net_pay'] ?? 0.0).toDouble().toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Color(0xFF00A859),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isPending ? Icons.access_time : Icons.check_circle,
                    color: const Color(0xFF00A859),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPending
                        ? "สถานะ: รอออกผลรางวัล"
                        : (isWin
                              ? "สถานะ: ถูกรางวัล ✨"
                              : "สถานะ: ไม่ถูกรางวัล"),
                    style: const TextStyle(
                      color: Color(0xFF00A859),
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
                        ? "฿ ${(data['total_win'] ?? 0.0).toDouble().toStringAsFixed(2)}"
                        : "฿ 0",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isWin ? Colors.green : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _selectedBillId = billId;
                      _selectedBillData = data;
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A859),
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

  // --- รายละเอียดบิล (Full Page) ---
  Widget _buildFullBillDetail(String billId, Map<String, dynamic> billData) {
    bool isWin = billData['status'] == 'win';
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => setState(() => _selectedBillId = null),
              ),
              const Text(
                "รายละเอียดบิล",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
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
                  "฿${(billData['total_win'] ?? 0.0).toDouble().toStringAsFixed(2)}",
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
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  double priceBet = (bet['price_bet'] ?? 0.0).toDouble();
                  double ratePay = (bet['rate_pay'] ?? 0.0).toDouble();
                  double payout = priceBet * ratePay;

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
                          backgroundColor: bet['status'] == 'win'
                              ? Colors.green
                              : Colors.grey.shade100,
                          radius: 25,
                          child: Text(
                            "${bet['number']}",
                            style: TextStyle(
                              color: bet['status'] == 'win'
                                  ? Colors.white
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                                "฿${priceBet.toStringAsFixed(0)} x ${ratePay.toStringAsFixed(0)}",
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
                              "฿${payout.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: bet['status'] == 'win'
                                    ? Colors.green
                                    : Colors.black,
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
  }

  Widget _buildTopSummary() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _sumItem("ยอดแทงวันนี้", "70.00"),
        _sumItem("ออกผลแล้ว", "0.00"),
        _sumItem("ยังไม่ออกผล", "70.00"),
      ],
    ),
  );
  Widget _sumItem(String l, String v) => Column(
    children: [
      Text(
        l,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      const SizedBox(height: 5),
      Text(
        v,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ],
  );
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
