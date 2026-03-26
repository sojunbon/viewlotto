import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // อย่าลืมเพิ่ม intl ใน pubspec.yaml

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
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          "จัดการผลรางวัล",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('configs').doc('setnum4').snapshots(),
        builder: (context, config4Snapshot) {
          List<dynamic> lottotypeArray = [];
          if (config4Snapshot.hasData && config4Snapshot.data!.exists) {
            lottotypeArray =
                (config4Snapshot.data!.data()
                    as Map<String, dynamic>)['lottotype'] ??
                [];
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

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final lottoData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final String lottoKey = lottoData['lottotype'] ?? 'unknown';
                  bool hasDigit4 = lottotypeArray.contains(lottoKey);

                  return StreamBuilder<DocumentSnapshot>(
                    stream: _db
                        .collection('lotto_results')
                        .doc(lottoKey)
                        .snapshots(),
                    builder: (context, resSnapshot) {
                      Map<String, dynamic>? currentRes;
                      String updateTimeStr = "ยังไม่มีการออกผล";

                      if (resSnapshot.hasData && resSnapshot.data!.exists) {
                        currentRes =
                            resSnapshot.data!.data() as Map<String, dynamic>;
                        // ✅ ดึงวันที่และเวลาจาก draw_date มาแสดง
                        if (currentRes['draw_date'] != null) {
                          DateTime dt = (currentRes['draw_date'] as Timestamp)
                              .toDate();
                          updateTimeStr =
                              "อัปเดตเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(dt)} น.";
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ExpansionTile(
                          leading: lottoData['lottolink'] != null
                              ? Image.network(
                                  lottoData['lottolink'],
                                  height: 30,
                                )
                              : const Icon(Icons.casino),
                          title: Text(
                            lottoData['lottoname'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentRes != null
                                    ? "${hasDigit4 ? '${currentRes['res_4top'] ?? '-'} | ' : ''}${currentRes['res_3top']} | ${currentRes['res_2bottom']}"
                                    : "ยังไม่มีผล",
                                style: TextStyle(
                                  color: currentRes != null
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                updateTimeStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
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
              if (hasDigit4) Expanded(child: _buildInput("4 ตัวบน", top4, 4)),
              Expanded(child: _buildInput("3 ตัวบน", top3, 3)),
              Expanded(child: _buildInput("2 ตัวล่าง", bottom2, 2)),
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

  Widget _buildInput(String l, TextEditingController c, int m) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    maxLength: m,
    decoration: InputDecoration(
      labelText: l,
      isDense: true,
      border: const OutlineInputBorder(),
      counterText: "",
    ),
  );

  Future<void> _updateLottoResult(
    String key,
    String name,
    String t4,
    String t3,
    String b2,
    bool has4,
  ) async {
    if (t3.length != 3 || b2.length != 2) return;
    Map<String, dynamic> data = {
      'lotto_type': key,
      'lotto_name': name,
      'res_3top': t3.trim(),
      'res_2bottom': b2.trim(),
      'draw_date': FieldValue.serverTimestamp(),
    };
    if (has4) data['res_4top'] = t4.trim();
    await _db.collection('lotto_results').doc(key).set(data);
  }

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
      QuerySnapshot pendingBets = await _db
          .collection('bets')
          .where('lotto_key', isEqualTo: key)
          .where('status', isEqualTo: 'pending')
          .get();
      final batch = _db.batch();
      Map<String, double> userPayouts = {};
      Map<String, double> billWins = {};
      Set<String> affectedBills = {};

      for (var doc in pendingBets.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final String betNumbers = d['number'].toString().trim();
        final String cat = d['category'].toString().trim();
        final String bId = d['billId'] ?? '';
        final String uid = d['uid'] ?? '';
        double price = (d['price_bet'] ?? 0.0).toDouble();
        double rate = (d['rate_pay'] ?? 0.0).toDouble();
        affectedBills.add(bId);
        bool isWin = false;

        // ✅ แก้ไขอักขระให้ตรง DB: ใช้ "สี่ตัวบน", "สามตัวบน", "สองตัวล่าง"
        if (cat == "สี่ตัวบน" && has4 && betNumbers == t4.trim())
          isWin = true;
        else if (cat == "สามตัวบน" && betNumbers == t3.trim())
          isWin = true;
        else if (cat == "สองตัวล่าง" && betNumbers == b2.trim())
          isWin = true;

        if (isWin) {
          double payout = price * rate;
          userPayouts[uid] = (userPayouts[uid] ?? 0.0) + payout;
          billWins[bId] = (billWins[bId] ?? 0.0) + payout;
          batch.update(doc.reference, {'status': 'win', 'payout': payout});
        } else {
          batch.update(doc.reference, {'status': 'lose', 'payout': 0.0});
        }
      }
      userPayouts.forEach(
        (uid, amt) => batch.update(_db.collection('users').doc(uid), {
          'credit': FieldValue.increment(amt),
        }),
      );
      for (String bId in affectedBills) {
        double winAmt = billWins[bId] ?? 0.0;
        batch.update(_db.collection('bills').doc(bId), {
          'status': winAmt > 0 ? 'win' : 'lose',
          'total_win': winAmt,
        });
      }
      await batch.commit();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("จ่ายเงินสำเร็จ")));
    } catch (e) {
      debugPrint("Error: $e");
    }
    setState(() => _isProcessing = false);
  }
}
