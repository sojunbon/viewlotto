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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            _selectedBillId == null ? "ประวัติการแทง" : "รายละเอียดบิล",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF11998E),
          leading: _selectedBillId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () => setState(() => _selectedBillId = null),
                )
              : null,
          elevation: 0,
          centerTitle: true,
        ),
        body: _selectedBillId == null
            ? _buildMainHistory(user?.uid)
            : _buildFullBillDetail(_selectedBillId!, _selectedBillData!),
      ),
    );
  }

  // --- หน้าหลัก: รายการบิล ---
  Widget _buildMainHistory(String? uid) {
    if (uid == null) return const Center(child: Text("กรุณาเข้าสู่ระบบ"));
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF11998E),
            child: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: [
                Tab(text: "รายการที่รอผล"),
                Tab(text: "ประวัติทั้งหมด"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBillList(uid, 'pending'),
                _buildBillList(uid, 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillList(String? uid, String statusGroup) {
    Query query = FirebaseFirestore.instance
        .collection('bills')
        .where('uid', isEqualTo: uid);
    if (statusGroup == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else {
      query = query.where('status', whereIn: ['win', 'lose', 'completed']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Text("ไม่พบรายการบิล", style: TextStyle(color: Colors.grey)),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final billId = docs[index].id;
            return _buildBillCard(data, billId);
          },
        );
      },
    );
  }

  Widget _buildBillCard(Map<String, dynamic> data, String billId) {
    bool isWin = data['status'] == 'win';
    Color statusColor = isWin
        ? Colors.green
        : (data['status'] == 'lose' ? Colors.red : Colors.orange);
    String dateStr = data['timestamp'] != null
        ? DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format((data['timestamp'] as Timestamp).toDate())
        : "";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () => setState(() {
          _selectedBillId = billId;
          _selectedBillData = data;
        }),
        title: Text(
          "เลขที่บิล: ${billId.substring(billId.length - 8).toUpperCase()}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            dateStr,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "฿${(data['net_pay'] ?? 0).toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              data['status'] == 'pending'
                  ? "รอผล"
                  : (isWin ? "ถูกรางวัล" : "ไม่ถูกรางวัล"),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- หน้าใหม่: รายละเอียดบิล (ตัดยอดสุทธิที่จ่ายออก) ---
  Widget _buildFullBillDetail(String billId, Map<String, dynamic> billData) {
    bool isWin = billData['status'] == 'win';

    return Column(
      children: [
        // ✅ ส่วน Header: โชว์เฉพาะยอดรางวัลที่ได้รับ (กรณีถูกหวย)
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "฿${(billData['total_win'] ?? 0).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    letterSpacing: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars, color: Colors.amber, size: 20),
                      SizedBox(width: 5),
                      Text(
                        "ยินดีด้วย! คุณถูกรางวัลในบิลนี้",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // รายการตัวเลข (ยอดแทง x ราคาจ่าย = ยอดที่ได้รับ)
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                              const SizedBox(height: 2),
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
