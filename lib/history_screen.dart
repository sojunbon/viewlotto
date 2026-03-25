import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // อย่าลืมเพิ่ม intl: ^0.18.1 ใน pubspec.yaml

// หน้าจอประวัติการแทงหวย
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF11998E),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF11998E),
              tabs: [
                Tab(text: "รายการที่รอผล"),
                Tab(text: "ประวัติการแทง"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildHistoryList(user?.uid, 'pending'), // รายการที่ยังไม่รู้ผล
            _buildHistoryList(user?.uid, 'completed'), // รายการที่ตรวจผลแล้ว
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(String? uid, String statusGroup) {
    if (uid == null) return const Center(child: Text("กรุณาเข้าสู่ระบบ"));

    // สร้าง Query ตามสถานะ
    Query query = FirebaseFirestore.instance
        .collection('lotto_tickets') // เปลี่ยนเป็นชื่อ Collection ที่คุณเก็บโพย
        .where('uid', isEqualTo: uid);

    if (statusGroup == 'pending') {
      query = query.where('status', isEqualTo: 'waiting'); // รอผล
    } else {
      query = query.where('status', whereIn: ['win', 'lose']); // ได้ผลแล้ว
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("ไม่มีรายการโพยในขณะนี้"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildTicketCard(data);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> data) {
    // จัดการสีตามสถานะ
    Color statusColor = Colors.orange;
    String statusText = "รอผลรางวัล";
    if (data['status'] == 'win') {
      statusColor = Colors.green;
      statusText = "ถูกรางวัล";
    } else if (data['status'] == 'lose') {
      statusColor = Colors.red;
      statusText = "ไม่ถูกรางวัล";
    }

    // ฟอร์แมตวันที่
    String dateStr = "";
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          // ส่วนหัวของโพย
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data['lottoTitle'] ?? "หวย",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          // รายละเอียดเลขที่แทง
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "เลขที่แทง",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      data['numbers'] ?? "-",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ยอดเดิมพัน: ฿${data['totalPrice']}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (data['status'] == 'win')
                      Text(
                        "ได้รับ: ฿${data['prize']}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
