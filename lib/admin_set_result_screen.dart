import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// หน้าจอสำหรับแอดมินในการคีย์ผลรางวัลและจ่ายเงินให้ผู้เล่น
class AdminSetResultScreen extends StatefulWidget {
  const AdminSetResultScreen({super.key});

  @override
  State<AdminSetResultScreen> createState() => _AdminSetResultScreenState();
}

class _AdminSetResultScreenState extends State<AdminSetResultScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "จัดการผลรางวัล",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final lottoGridDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: lottoGridDocs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final lottoData =
                  lottoGridDocs[index].data() as Map<String, dynamic>;
              final String lottoKey = lottoData['lottotype'] ?? 'unknown';

              // ดึงผลรางวัลล่าสุดของหวยประเภทนี้มาโชว์คู่กัน
              return StreamBuilder<DocumentSnapshot>(
                stream: _db
                    .collection('lotto_results')
                    .doc(lottoKey)
                    .snapshots(),
                builder: (context, resSnapshot) {
                  Map<String, dynamic>? currentRes;
                  if (resSnapshot.hasData && resSnapshot.data!.exists) {
                    currentRes =
                        resSnapshot.data!.data() as Map<String, dynamic>;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ExpansionTile(
                      leading: Image.network(
                        lottoData['lottolink'] ?? '',
                        height: 30,
                        errorBuilder: (c, e, s) => const Icon(Icons.casino),
                      ),
                      title: Text(
                        lottoData['lottoname'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: currentRes != null
                          ? Text(
                              "ล่าสุด: ${currentRes['res_3top']} | ${currentRes['res_2bottom']}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            )
                          : const Text(
                              "ยังไม่มีผล",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                      children: [
                        _buildSetResultForm(
                          lottoKey,
                          lottoData['lottoname'],
                          currentRes,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- ฟอร์มคีย์ผลรางวัล ---
  Widget _buildSetResultForm(
    String lottoKey,
    String lottoName,
    Map<String, dynamic>? currentRes,
  ) {
    TextEditingController top3 = TextEditingController(
      text: currentRes?['res_3top'],
    );
    TextEditingController bottom2 = TextEditingController(
      text: currentRes?['res_2bottom'],
    );

    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildResultInput("3 ตัวบน", top3, 3)),
              const SizedBox(width: 15),
              Expanded(child: _buildResultInput("2 ตัวล่าง", bottom2, 2)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              // ปุ่มบันทึกผลอย่างเดียว
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3D5D),
                  ),
                  onPressed: () => _updateLottoResult(
                    lottoKey,
                    lottoName,
                    top3.text,
                    bottom2.text,
                  ),
                  child: const Text(
                    "บันทึกผล",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ปุ่มบันทึกผล + ตรวจโพยและจ่ายเครดิต
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    "บันทึก & จ่ายเงิน",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onPressed: () => _updateResultAndCheckBets(
                    lottoKey,
                    lottoName,
                    top3.text,
                    bottom2.text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultInput(
    String label,
    TextEditingController controller,
    int maxLength,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        counterText: "",
      ),
    );
  }

  // ✅ 1. ฟังก์ชันบันทึกผลรางวัลลง Firestore
  Future<void> _updateLottoResult(
    String key,
    String name,
    String top,
    String bottom,
  ) async {
    if (top.length != 3 || bottom.length != 2) return;

    await _db.collection('lotto_results').doc(key).set({
      'lotto_type': key,
      'lotto_name': name,
      'res_3top': top,
      'res_2bottom': bottom,
      'draw_date': FieldValue.serverTimestamp(),
    });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("บันทึกผลรางวัลสำเร็จ")));
  }

  // ✅ 2. ฟังก์ชันบันทึกผล + ตรวจโพยและจ่ายเงิน (ใช้ WriteBatch เพื่อความปลอดภัย)
  Future<void> _updateResultAndCheckBets(
    String key,
    String name,
    String top,
    String bottom,
  ) async {
    if (top.length != 3 || bottom.length != 2) return;

    setState(() => _isProcessing = true);

    try {
      // 2.1 บันทึกผลรางวัลก่อน
      await _updateLottoResult(key, name, top, bottom);

      // 2.2 ดึงโพยที่ 'รอผล' (waiting) ของหวยประเภทนี้ทั้งหมดมา
      QuerySnapshot pendingBets = await _db
          .collection('lotto_tickets')
          .where('lottoKey', isEqualTo: key)
          .where('status', isEqualTo: 'waiting')
          .get();

      final batch = _db.batch();
      Map<String, double> userPayouts =
          {}; // เก็บรวบรวมยอดเงินที่จะจ่ายให้ User แต่ละคน

      for (var doc in pendingBets.docs) {
        final betData = doc.data() as Map<String, dynamic>;
        final String betNumbers = betData['numbers'] ?? '';
        final String betCategory =
            betData['cat'] ?? ''; // เช่น สามตัวบน, สองตัวล่าง
        double prizePerBaht = 0.0;
        double totalPrice = (betData['totalPrice'] ?? 0).toDouble();
        String finalStatus = 'lose'; // เริ่มต้นที่ 'ไม่ถูก'
        double payout = 0.0;

        // 2.3 ตรวจเงื่อนไข (เทียบผลที่เราเพิ่งคีย์)
        if (betCategory == "สามตัวบน") {
          if (betNumbers == top) {
            finalStatus = 'win';
            prizePerBaht = (betData['pay_digit3'] ?? 920)
                .toDouble(); // ดึงราคาจ่ายจากโพย
          }
        } else if (betCategory == "สองตัวล่าง") {
          if (betNumbers == bottom) {
            finalStatus = 'win';
            prizePerBaht = (betData['pay_digit2'] ?? 92).toDouble();
          }
        } // ... เพิ่มเงื่อนไขอื่นๆ ได้ที่นี่

        // 2.4 ถ้าถูกรางวัล -> อัปเดตโพย & รวมยอดเงิน
        if (finalStatus == 'win') {
          payout = totalPrice * prizePerBaht; // คำนวณเงินรางวัล
          final String uid = betData['uid'];
          userPayouts[uid] =
              (userPayouts[uid] ?? 0.0) + payout; // รวมยอดเงิน User คนนั้น

          batch.update(doc.reference, {'status': 'win', 'prize': payout});
        } else {
          batch.update(doc.reference, {
            'status': 'lose',
          }); // ไม่ถูกก็เปลี่ยนสถานะเป็น lose
        }
      }

      // 2.5 จ่ายเครดิตให้ User แต่ละคนแบบ Batch
      userPayouts.forEach((uid, amount) {
        batch.update(_db.collection('users').doc(uid), {
          'credit': FieldValue.increment(amount), // เติมเงินให้
        });
      });

      // 2.6 ส่งข้อมูลไป Firestore ทั้งหมดในครั้งเดียว
      await batch.commit();

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("จ่ายเงินรางวัลเรียบร้อย ($name)")),
        );
    } catch (e) {
      debugPrint("Payout Error: $e");
    }

    setState(() => _isProcessing = false);
  }
}
