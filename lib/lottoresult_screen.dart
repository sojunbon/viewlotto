import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? _user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        // ✅ ดึงผลรางวัลล่าสุด เรียงลำดับจากน้อยไปมากตาม number (เหมือนหน้า Admin)
        stream: FirebaseFirestore.instance
            .collection('lotto_results') // ดึงจาก collection ผลหวย
            .orderBy('draw_date', descending: true) // เอาล่าสุดขึ้นก่อน
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final results = snapshot.data!.docs;

          return ListView.builder(
            itemCount: results.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = results[index].data() as Map<String, dynamic>;

              String dateStr = "";
              if (data['draw_date'] != null) {
                dateStr = DateFormat(
                  'dd MMM yyyy',
                ).format((data['draw_date'] as Timestamp).toDate());
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(
                          0xFF11998E,
                        ).withOpacity(0.1),
                        child: const Icon(
                          Icons.casino,
                          color: Color(0xFF11998E),
                        ),
                      ),
                      title: Text(
                        data['lotto_name'] ?? 'หวย',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "งวดวันที่ $dateStr",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 15,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNumberItem(
                            "3 ตัวบน",
                            data['res_3top'] ?? "---",
                            Colors.redAccent,
                          ),
                          _buildNumberItem(
                            "2 ตัวล่าง",
                            data['res_2bottom'] ?? "--",
                            Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNumberItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
