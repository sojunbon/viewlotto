import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminTransactionScreen extends StatelessWidget {
  const AdminTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "จัดการฝาก-ถอน",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A3D5D),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "รายการรออนุมัติ"),
              Tab(text: "ประวัติทั้งหมด"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTransactionList(isPending: true),
            _buildTransactionList(isPending: false),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList({required bool isPending}) {
    Query query = FirebaseFirestore.instance.collection('transactions');

    if (isPending) {
      query = query.where('status', isEqualTo: 'pending');
    }

    // ⚠️ อย่าลืมสร้าง Index ใน Firebase ตามลิงก์ใน Debug Console นะครับ
    query = query.orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text("ไม่มีรายการในขณะนี้"));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return _buildTransactionCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    bool isDeposit = data['type'] == 'deposit';
    Color typeColor = isDeposit ? Colors.green : Colors.red;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: Icon(
          isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
          color: typeColor,
        ),
        title: Text(
          "${isDeposit ? 'ฝากเงิน' : 'ถอนเงิน'} - ฿${data['amount']}",
          style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
        ),
        subtitle: Text("โดย: ${data['displayName'] ?? 'ไม่ระบุชื่อ'}"),
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),

                // --- ส่วนข้อมูลบัญชี ---
                if (isDeposit) ...[
                  _infoRow(
                    "โอนจาก (ลูกค้า):",
                    "${data['userBankName']} (${data['userBankAccount']})",
                  ),
                  _infoRow(
                    "โอนเข้า (ร้าน):",
                    "${data['receiverBankName']} (${data['receiverBankAccount']})",
                  ),
                ] else ...[
                  _infoRow(
                    "ถอนเข้าบัญชีลูกค้า:",
                    "${data['bankName']} (${data['bankAccount']})",
                  ),
                ],

                const SizedBox(height: 10),

                // --- ส่วนแสดงสลิป (เฉพาะรายการฝาก) ---
                if (isDeposit && data['slipUrl'] != null)
                  GestureDetector(
                    onTap: () => _showFullImage(context, data['slipUrl']),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(data['slipUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 15),

                // --- ปุ่มจัดการ (เฉพาะรายการ Pending) ---
                if (data['status'] == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () =>
                              _updateStatus(context, docId, data, 'approved'),
                          child: const Text(
                            "อนุมัติ",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () =>
                              _updateStatus(context, docId, data, 'rejected'),
                          child: const Text("ปฏิเสธ"),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ปิด"),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ระบบอัปเดตสถานะและจัดการเครดิต
  Future<void> _updateStatus(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
    String newStatus,
  ) async {
    final _db = FirebaseFirestore.instance;
    final batch = _db.batch();

    try {
      // 1. อัปเดตสถานะ Transaction
      batch.update(_db.collection('transactions').doc(docId), {
        'status': newStatus,
      });

      // 2. ถ้าเป็นการอนุมัติ "ฝากเงิน" ต้องไปเพิ่มเครดิตให้ User
      // (ส่วนการถอนเงิน เครดิตถูกหักไปแล้วตั้งแต่ตอน User กดถอนในแอป)
      if (newStatus == 'approved' && data['type'] == 'deposit') {
        batch.update(_db.collection('users').doc(data['uid']), {
          'credit': FieldValue.increment(data['amount']),
        });
      }

      // 3. ถ้า "ปฏิเสธ" การถอนเงิน ต้องคืนเครดิตให้ User
      if (newStatus == 'rejected' && data['type'] == 'withdraw') {
        batch.update(_db.collection('users').doc(data['uid']), {
          'credit': FieldValue.increment(data['amount']),
        });
      }

      await batch.commit();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("ทำรายการสำเร็จ: $newStatus")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }
}
