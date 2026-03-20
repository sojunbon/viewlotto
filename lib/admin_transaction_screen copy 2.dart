import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTransactionScreen extends StatelessWidget {
  const AdminTransactionScreen({super.key});

  // ✅ ฟังก์ชันอนุมัติรายการ (รองรับทั้งฝากและถอน)
  Future<void> _approveManual(
    BuildContext context,
    String docId,
    String uid,
    double amount,
    String type, // เพิ่มการเช็คประเภท
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. อัปเดตสถานะเป็น approved
      batch.update(
        FirebaseFirestore.instance.collection('transactions').doc(docId),
        {'status': 'approved', 'approvedAt': FieldValue.serverTimestamp()},
      );

      // 2. ถ้าเป็นรายการ 'deposit' (ฝาก) ให้เติมเครดิต
      // ถ้าเป็น 'withdraw' (ถอน) ไม่ต้องทำอะไรเพิ่มเพราะหักเงินไปแล้วตอน user กดถอน
      if (type == 'deposit') {
        batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
          'credit': FieldValue.increment(amount),
        });
      }

      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'deposit'
                  ? "อนุมัติเติมเงินสำเร็จ"
                  : "ยืนยันการโอนเงินถอนสำเร็จ",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ❌ ฟังก์ชันปฏิเสธรายการ
  // กรณีปฏิเสธการถอนเงิน ควรคืนเครดิตให้ User ด้วย
  Future<void> _rejectTransaction(
    String docId,
    String uid,
    double amount,
    String type,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.update(
      FirebaseFirestore.instance.collection('transactions').doc(docId),
      {'status': 'rejected', 'rejectedAt': FieldValue.serverTimestamp()},
    );

    // ถ้าปฏิเสธการถอน ต้องคืนเงินให้ user
    if (type == 'withdraw') {
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'credit': FieldValue.increment(amount),
      });
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "จัดการรายการ ฝาก/ถอน",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          backgroundColor: const Color(0xFF1A3D5D),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(text: "รอตรวจสอบ"),
              Tab(text: "สำเร็จแล้ว"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTransactionList('pending'),
            _buildTransactionList('approved'),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
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
            String type = data['type'] ?? 'deposit'; // ตรวจสอบว่าเป็นฝากหรือถอน
            bool isAuto = data.containsKey('transRef');

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: type == 'deposit'
                      ? (isAuto ? Colors.green[100] : Colors.orange[100])
                      : Colors.red[100],
                  child: Icon(
                    type == 'deposit'
                        ? (isAuto ? Icons.bolt : Icons.add_circle_outline)
                        : Icons.remove_circle_outline,
                    color: type == 'deposit' ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                title: Text(
                  "${type == 'deposit' ? 'ฝากเงิน' : 'ถอนเงิน'}: ${data['amount']} บาท",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("โดย: ${data['displayName'] ?? 'ไม่ระบุชื่อ'}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      children: [
                        // --- ส่วนของสลิปฝากเงิน ---
                        if (data['slipUrl'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              data['slipUrl'],
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                          ),

                        // --- ส่วนข้อมูลธนาคาร (เฉพาะถอนเงิน) ---
                        if (type == 'withdraw') ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _infoRow("ธนาคาร:", data['bankName'] ?? '-'),
                                _infoRow(
                                  "เลขบัญชี:",
                                  data['bankAccount'] ?? '-',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        if (isAuto)
                          _infoRow("เลขที่อ้างอิง (Ref):", data['transRef']),

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
                                onPressed: () => _rejectTransaction(
                                  docId,
                                  data['uid'],
                                  (data['amount'] as num).toDouble(),
                                  type,
                                ),
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
                                  type,
                                ),
                                icon: const Icon(Icons.check_circle),
                                label: Text(
                                  type == 'deposit'
                                      ? "อนุมัติเงิน"
                                      : "ยืนยันโอนเงิน",
                                ),
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
