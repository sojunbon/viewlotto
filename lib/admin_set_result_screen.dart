import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      // ✅ 1. ดึง Document 'setnum4' มาเพื่อเช็ค Array 'lottotype'
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('configs').doc('setnum4').snapshots(),
        builder: (context, config4Snapshot) {
          List<dynamic> lottotypeArray = [];
          if (config4Snapshot.hasData && config4Snapshot.data!.exists) {
            final configData =
                config4Snapshot.data!.data() as Map<String, dynamic>;
            // ตรวจสอบฟิลด์ lottotype ที่เป็น Array ตามรูป
            lottotypeArray = configData['lottotype'] ?? [];
          }

          return StreamBuilder<QuerySnapshot>(
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

                  // ✅ 2. เช็คว่าหวยนี้ต้องโชว์ช่อง 4 ตัวไหม (เช็คจาก Array)
                  bool hasDigit4 = lottotypeArray.contains(lottoKey);

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
                                  "ล่าสุด: ${hasDigit4 ? '${currentRes['res_4top'] ?? '-'} | ' : ''}${currentRes['res_3top']} | ${currentRes['res_2bottom']}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                )
                              : const Text(
                                  "ยังไม่มีผล",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                          children: [
                            _buildSetResultForm(
                              lottoKey,
                              lottoData['lottoname'],
                              currentRes,
                              hasDigit4,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSetResultForm(
    String lottoKey,
    String lottoName,
    Map<String, dynamic>? currentRes,
    bool hasDigit4,
  ) {
    TextEditingController top4 = TextEditingController(
      text: currentRes?['res_4top']?.toString() ?? "",
    );
    TextEditingController top3 = TextEditingController(
      text: currentRes?['res_3top']?.toString() ?? "",
    );
    TextEditingController bottom2 = TextEditingController(
      text: currentRes?['res_2bottom']?.toString() ?? "",
    );

    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Row(
            children: [
              if (hasDigit4) ...[
                Expanded(child: _buildResultInput("4 ตัวบน", top4, 4)),
                const SizedBox(width: 10),
              ],
              Expanded(child: _buildResultInput("3 ตัวบน", top3, 3)),
              const SizedBox(width: 15),
              Expanded(child: _buildResultInput("2 ตัวล่าง", bottom2, 2)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3D5D),
                  ),
                  onPressed: () => _updateLottoResult(
                    lottoKey,
                    lottoName,
                    top4.text,
                    top3.text,
                    bottom2.text,
                    hasDigit4,
                  ),
                  child: const Text(
                    "บันทึกผล",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  onPressed: _isProcessing
                      ? null
                      : () => _updateResultAndCheckBets(
                          lottoKey,
                          lottoName,
                          top4.text,
                          top3.text,
                          bottom2.text,
                          hasDigit4,
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

  Future<void> _updateLottoResult(
    String key,
    String name,
    String t4,
    String t3,
    String b2,
    bool has4,
  ) async {
    if (t3.length != 3 || b2.length != 2) return;
    if (has4 && t4.length != 4) return;

    Map<String, dynamic> data = {
      'lotto_type': key,
      'lotto_name': name,
      'res_3top': t3,
      'res_2bottom': b2,
      'draw_date': FieldValue.serverTimestamp(),
    };
    if (has4) data['res_4top'] = t4;

    await _db.collection('lotto_results').doc(key).set(data);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("บันทึกผลรางวัลสำเร็จ")));
  }

  // ✅ ฟังก์ชันตรวจรางวัลและ Update โพยลูกค้า (แก้ไข Path bets/bills)
  Future<void> _updateResultAndCheckBets(
    String key,
    String name,
    String t4,
    String t3,
    String b2,
    bool has4,
  ) async {
    if (t3.length != 3 || b2.length != 2) return;
    setState(() => _isProcessing = true);

    try {
      await _updateLottoResult(key, name, t4, t3, b2, has4);

      // 🛠️ ดึงจาก Collection 'bets' ตามโครงสร้างจริงของคุณ
      QuerySnapshot pendingBets = await _db
          .collection('bets')
          .where('lotto_key', isEqualTo: key)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _db.batch();
      Map<String, double> userPayouts = {};
      Map<String, List<double>> billWins = {}; // เก็บยอดชนะแยกตาม billId

      for (var doc in pendingBets.docs) {
        final betData = doc.data() as Map<String, dynamic>;
        final String betNumbers = betData['number'].toString();
        final String betCategory = betData['category'] ?? '';
        final String billId = betData['billId'] ?? '';
        final String uid = betData['uid'] ?? '';
        double rate = (betData['rate_pay'] ?? 0.0).toDouble();
        double price = (betData['price_bet'] ?? 0.0).toDouble();

        bool isWin = false;

        // ตรวจเงื่อนไข
        if (betCategory == "4 ตัวบน" && has4 && betNumbers == t4)
          isWin = true;
        else if (betCategory == "3 ตัวบน" && betNumbers == t3)
          isWin = true;
        else if (betCategory == "2 ตัวล่าง" && betNumbers == b2)
          isWin = true;

        if (isWin) {
          double payout = price * rate;
          userPayouts[uid] = (userPayouts[uid] ?? 0.0) + payout;
          billWins[billId] = (billWins[billId] ?? [])..add(payout);
          batch.update(doc.reference, {'status': 'win', 'payout': payout});
        } else {
          batch.update(doc.reference, {'status': 'lose', 'payout': 0.0});
          if (!billWins.containsKey(billId)) billWins[billId] = [];
        }
      }

      // Update ยอดเครดิตลูกค้า
      userPayouts.forEach((uid, amount) {
        batch.update(_db.collection('users').doc(uid), {
          'credit': FieldValue.increment(amount),
        });
      });

      // ✅ Update Collection 'bills' เพื่อให้หน้าโพยลูกค้าเปลี่ยนสถานะ
      billWins.forEach((bId, payouts) {
        double totalBillWin = payouts.fold(0.0, (sum, item) => sum + item);
        batch.update(_db.collection('bills').doc(bId), {
          'status': totalBillWin > 0 ? 'win' : 'lose',
          'total_win': totalBillWin,
        });
      });

      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("จ่ายเงินรางวัลและอัปเดตโพยเรียบร้อย")),
        );
    } catch (e) {
      debugPrint("Payout Error: $e");
    }
    setState(() => _isProcessing = false);
  }
}
