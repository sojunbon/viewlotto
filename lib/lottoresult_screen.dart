import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: () async => {}, // ใส่ฟังก์ชันดึงข้อมูลใหม่ถ้าต้องการ
        child: CustomScrollView(
          slivers: [
            // --- ส่วนแบนเนอร์หรือประกาศ ---
            _buildHeaderBanner(),

            // --- ส่วนรายการผลรางวัล ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lotto_results')
                  .orderBy('draw_date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const SliverToBoxAdapter(
                    child: Center(child: Text("เกิดข้อผิดพลาด")),
                  );
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                final results = snapshot.data!.docs;

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final data = results[index].data() as Map<String, dynamic>;
                    return _buildResultCard(data);
                  }, childCount: results.length),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ), // เผื่อพื้นที่ด้านล่าง
          ],
        ),
      ),
    );
  }

  // แบนเนอร์ด้านบนสุด
  Widget _buildHeaderBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A3D5D), Color(0xFF2E5A88)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "เช็คผลรางวัลล่าสุด",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "อัปเดตผลรวดเร็ว แม่นยำ ส่งตรงจากระบบ",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // การ์ดแสดงผลรางวัลแต่ละประเภท
  Widget _buildResultCard(Map<String, dynamic> data) {
    String dateStr = "";
    if (data['draw_date'] != null) {
      dateStr = DateFormat(
        'dd MMM yyyy',
      ).format((data['draw_date'] as Timestamp).toDate());
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // หัวการ์ด (ชื่อหวย + วันที่)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF11998E).withOpacity(0.1),
              child: const Icon(Icons.stars, color: Color(0xFF11998E)),
            ),
            title: Text(
              data['lotto_name'] ?? 'หวย',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "งวดวันที่ $dateStr",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
          ),
          const Divider(height: 1),
          // ส่วนแสดงตัวเลขรางวัล
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
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
