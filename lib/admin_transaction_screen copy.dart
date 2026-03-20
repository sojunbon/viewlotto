import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTransactionScreen extends StatelessWidget {
  const AdminTransactionScreen({super.key});

  // ✅ ฟังก์ชันอนุมัติรายการ (สำหรับ Manual)
  Future<void> _approveManual(
    BuildContext context,
    String docId,
    String uid,
    double amount,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. อัปเดตสถานะเป็น approved
      batch.update(
        FirebaseFirestore.instance.collection('transactions').doc(docId),
        {'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()},
      );

      // 2. เติมเครดิตให้ User
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'credit': FieldValue.increment(amount),
      });

      await batch.commit();
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("อนุมัติและเติมเงินสำเร็จ")),
        );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ❌ ฟังก์ชันปฏิเสธรายการ
  Future<void> _rejectTransaction(String docId) async {
    await FirebaseFirestore.instance
        .collection('transactions')
        .doc(docId)
        .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "จัดการรายการฝากเงิน",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF1A3D5D),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(text: "รอตรวจสอบ (Manual)"),
              Tab(text: "สำเร็จแล้ว (Auto/Approve)"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTransactionList('pending'), // รายการที่ต้องกดมือ
            _buildTransactionList(
              'approved',
            ), // รายการที่เข้าออโต้หรืออนุมัติแล้ว
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('status', isEqualTo: status)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "ไม่มีรายการในหมวดนี้",
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            bool isAuto = data.containsKey(
              'transRef',
            ); // เช็คว่าเป็นรายการจาก API หรือไม่

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isAuto
                      ? Colors.green[100]
                      : Colors.orange[100],
                  child: Icon(
                    isAuto ? Icons.bolt : Icons.hourglass_empty,
                    color: isAuto ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  "ยอดฝาก: ${data['amount']} บาท",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("โดย: ${data['displayName'] ?? 'ไม่ระบุชื่อ'}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        if (data['slipUrl'] != null) // ถ้ามีรูปสลิป (Manual)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['slipUrl'],
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text("โหลดรูปไม่ได้"),
                            ),
                          ),
                        const SizedBox(height: 15),
                        if (isAuto)
                          _infoRow(
                            "เลขที่อ้างอิงธนาคาร (Ref):",
                            data['transRef'],
                          ),

                        _infoRow(
                          "วันเวลาที่ทำรายการ:",
                          data['timestamp']?.toDate().toString().split(
                                '.',
                              )[0] ??
                              '-',
                        ),

                        if (status == 'pending') ...[
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _rejectTransaction(docId),
                                icon: const Icon(Icons.cancel),
                                label: const Text("ปฏิเสธ"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _approveManual(
                                  context,
                                  docId,
                                  data['uid'],
                                  (data['amount'] as num).toDouble(),
                                ),
                                icon: const Icon(Icons.check_circle),
                                label: const Text("อนุมัติเงิน"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
