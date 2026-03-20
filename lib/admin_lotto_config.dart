import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLottoConfig extends StatelessWidget {
  const AdminLottoConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ตั้งค่าราคาจ่ายหวย",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✅ ปรับ Path ให้จบที่ collection 'lottogrid' ที่มี AutoID อยู่ข้างใน
        stream: FirebaseFirestore.instance
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number') // เรียงตามเลขลำดับ 1, 2, 3...
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "ไม่พบรายการหวยในระบบ\n(ตรวจสอบ Path: configs/lottogen/lottogrid)",
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              // เช็คว่ามีฟิลด์ digit4 หรือยัง
              bool hasPrice = data.containsKey('digit4');

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(
                    data['lottoname'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: hasPrice
                      ? Text(
                          "4ตัว: x${data['digit4']} | 3ตัว: x${data['digit3']} | 2ตัว: x${data['digit2']}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Text(
                          "⚠️ ยังไม่ได้ตั้งค่าราคาจ่าย",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                  trailing: Icon(
                    hasPrice ? Icons.edit_note : Icons.add_circle,
                    color: hasPrice ? Colors.blue : Colors.orange,
                  ),
                  onTap: () => _showEditDialog(context, docId, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    TextEditingController d4 = TextEditingController(
      text: (data['digit4'] ?? "8000").toString(),
    );
    TextEditingController d3 = TextEditingController(
      text: (data['digit3'] ?? "920").toString(),
    );
    TextEditingController d2 = TextEditingController(
      text: (data['digit2'] ?? "92").toString(),
    );
    TextEditingController d1 = TextEditingController(
      text: (data['digit1'] ?? "3.2").toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("ตั้งค่า: ${data['lottoname']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField("4 ตัวบน", d4),
            _buildField("3 ตัวบน", d3),
            _buildField("2 ตัวบน", d2),
            _buildField("วิ่งบน", d1),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998E),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('configs')
                  .doc('lottogen')
                  .collection('lottogrid')
                  .doc(docId)
                  .update({
                    // ใช้ update เพื่อเพิ่ม/แก้ไข digit1-4 โดยไม่ทับ lottoname
                    'digit4': int.tryParse(d4.text) ?? 0,
                    'digit3': int.tryParse(d3.text) ?? 0,
                    'digit2': int.tryParse(d2.text) ?? 0,
                    'digit1': double.tryParse(d1.text) ?? 0.0,
                  });
              Navigator.pop(ctx);
            },
            child: const Text("บันทึก", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixText: "x "),
      keyboardType: TextInputType.number,
    );
  }
}
