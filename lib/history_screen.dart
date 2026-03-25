import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedBillId;
  Map<String, dynamic>? _selectedBillData;

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
        appBar: _selectedBillId != null
            ? AppBar(
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
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _selectedBillId = null),
                ),
              )
            : AppBar(
                backgroundColor: const Color(0xFF00A859),
                toolbarHeight: 70,
                elevation: 0,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "ประวัติการแทง",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "70.00 ↻",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Text(
                          "zodazozam",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        body: _selectedBillId == null
            ? _buildMainHistory(user?.uid)
            : _buildFullBillDetail(_selectedBillId!, _selectedBillData!),
      ),
    );
  }

  // --- หน้าหลัก: UI ตามภาพ image.png ---
  Widget _buildMainHistory(String? uid) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem("ยอดแทงวันนี้", "70.00"),
                _buildSummaryItem("ออกผลแล้ว", "0.00"),
                _buildSummaryItem("ยังไม่ออกผล", "70.00"),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: const TabBar(
              isScrollable: true,
              labelColor: Color(0xFF00A859),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF00A859),
              indicatorWeight: 3,
              tabs: [
                Tab(text: "ทั้งหมด"),
                Tab(text: "โพยที่ซื้อ"),
                Tab(text: "ออกผลแล้ว"),
                Tab(text: "ยังไม่ออก"),
              ],
            ),
          ),
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

  Widget _buildSummaryItem(String label, String value) {
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBillList(String? uid, String filter) {
    Query query = FirebaseFirestore.instance
        .collection('bills')
        .where('uid', isEqualTo: uid);
    if (filter == 'pending')
      query = query.where('status', isEqualTo: 'pending');
    if (filter == 'completed')
      query = query.where('status', whereIn: ['win', 'lose']);

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Text("ไม่มีรายการโพย", style: TextStyle(color: Colors.grey)),
          );

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildTicketCard(data, docs[index].id);
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
    bool isPending = data['status'] == 'pending';
    bool isWin = data['status'] == 'win';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "HD+",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "zodazozam",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFF0F2F5),
                child: Icon(Icons.flag, color: Colors.blue),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "หวยลาว",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "🛡️ เงินเดิมพัน : ฿ ${(data['net_pay'] ?? 0).toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Color(0xFF00A859),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    : (isWin ? "สถานะ: ถูกรางวัล ✨" : "สถานะ: ไม่ถูกรางวัล"),
                style: const TextStyle(
                  color: Color(0xFF00A859),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
                    ? "฿ ${(data['total_win'] ?? 0).toStringAsFixed(2)}"
                    : "฿ 0",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWin ? Colors.green : Colors.black,
                ),
              ),
              const Spacer(),
              if (isPending) ...[
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    elevation: 0,
                  ),
                  child: const Text(
                    "คืนโพย",
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton(
                onPressed: () => setState(() {
                  _selectedBillId = billId;
                  _selectedBillData = data;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A859),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
  }

  // --- หน้าใหม่: รายละเอียดบิล (เน้นยอดรับรางวัลรายบรรทัด) ---
  Widget _buildFullBillDetail(String billId, Map<String, dynamic> billData) {
    bool isWin = billData['status'] == 'win';

    return Column(
      children: [
        if (isWin)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
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
                const SizedBox(height: 8),
                Text(
                  "฿${(billData['total_win'] ?? 0).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "รายการตัวเลขที่แทง",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bets')
                .where('billId', isEqualTo: billId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final bets = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: bets.length,
                itemBuilder: (context, index) {
                  final bet = bets[index].data() as Map<String, dynamic>;
                  bool betWin = bet['status'] == 'win';
                  double priceBet = (bet['price_bet'] ?? 0).toDouble();
                  double ratePay = (bet['rate_pay'] ?? 0).toDouble();
                  double potentialPayout = priceBet * ratePay;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: betWin
                            ? Colors.green.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: betWin
                              ? Colors.green
                              : Colors.grey.shade100,
                          radius: 25,
                          child: Text(
                            "${bet['number']}",
                            style: TextStyle(
                              color: betWin ? Colors.white : Colors.black87,
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
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "฿${priceBet.toStringAsFixed(0)} x $ratePay",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
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
                              "฿${potentialPayout.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: betWin ? Colors.green : Colors.black87,
                              ),
                            ),
                            if (betWin)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "ถูกรางวัล",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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
            },
          ),
        ),
      ],
    );
  }
}
