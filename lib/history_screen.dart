import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "ประวัติการแทง",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF11998E),
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "รายการที่รอผล"),
              Tab(text: "ประวัติทั้งหมด"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBillList(user?.uid, 'pending'), // ดึงจากสถานะ pending
            _buildBillList(user?.uid, 'completed'), // ดึงสถานะอื่นๆ
          ],
        ),
      ),
    );
  }

  Widget _buildBillList(String? uid, String statusGroup) {
    if (uid == null) return const Center(child: Text("กรุณาเข้าสู่ระบบ"));

    // ดึงข้อมูลจาก collection 'bills' ตามโครงสร้างที่เราบันทึกไว้
    Query query = FirebaseFirestore.instance
        .collection('bills')
        .where('uid', isEqualTo: uid);

    if (statusGroup == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else {
      // สำหรับประวัติทั้งหมด ให้ดึงรายการที่ตัดสินผลแล้ว
      query = query.where('status', whereIn: ['win', 'lose', 'completed']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text("ไม่มีรายการโพยในขณะนี้"));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final billId = docs[index].id;
            return _buildBillCard(context, data, billId);
          },
        );
      },
    );
  }

  Widget _buildBillCard(
    BuildContext context,
    Map<String, dynamic> data,
    String billId,
  ) {
    Color statusColor = Colors.orange;
    String statusText = "รอผลรางวัล";

    if (data['status'] == 'win') {
      statusColor = Colors.green;
      statusText = "ถูกรางวัล";
    } else if (data['status'] == 'lose') {
      statusColor = Colors.red;
      statusText = "ไม่ถูกรางวัล";
    }

    String dateStr = "";
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showBillDetails(context, billId, data),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "เลขที่บิล: ${billId.substring(billId.length - 8)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ยอดรวมบิล:",
                    style: TextStyle(color: Colors.black87),
                  ),
                  Text(
                    "฿${(data['net_pay'] ?? 0).toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF11998E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "ดูรายละเอียด >",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันแสดงรายละเอียดเลขภายในบิล
  void _showBillDetails(
    BuildContext context,
    String billId,
    Map<String, dynamic> billData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "รายละเอียดการแทง",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
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
                      itemCount: bets.length,
                      itemBuilder: (context, index) {
                        final bet = bets[index].data() as Map<String, dynamic>;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "${bet['number']} (${bet['category']})",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("ราคาจ่าย x${bet['rate_pay']}"),
                          trailing: Text(
                            "฿${bet['price_bet']}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("ยอดจ่ายสุทธิ:", style: TextStyle(fontSize: 16)),
                  Text(
                    "฿${(billData['net_pay'] ?? 0).toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF11998E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
