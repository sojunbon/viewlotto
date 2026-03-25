import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kMainGreen = Color(0xFF11998E);

class PriceInputScreen extends StatefulWidget {
  final List<Map<String, String>> draftBets;
  const PriceInputScreen({super.key, required this.draftBets});

  @override
  State<PriceInputScreen> createState() => _PriceInputScreenState();
}

class _PriceInputScreenState extends State<PriceInputScreen> {
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Map<int, TextEditingController> priceControllers = {};
  Map<String, Map<String, double>> _allBasePayRates = {};

  // ✅ Config ลดหลั่นจาก Firebase
  int _countPerNum = 5000;
  int _payPercent = 10;

  int _activeFieldIndex = 0;
  bool _showKeypad = true; // ✅ ควบคุมการซ่อน/แสดงแป้นพิมพ์

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController(text: "");
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final payrateDoc = await _db.collection('configs').doc('payrate').get();
    if (payrateDoc.exists) {
      setState(() {
        _countPerNum = (payrateDoc.data()?['countpernum'] ?? 5000).toInt();
        _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
      });
    }
    // ดึงเรทราคา (digit1-4, swift) จาก Firebase...
    Set<String?> selectedKeys = widget.draftBets
        .map((e) => e['lottoKey'])
        .toSet();
    for (String? key in selectedKeys) {
      if (key == null) continue;
      final lottoSnap = await _db
          .collection('configs')
          .doc('lottogen')
          .collection('lottogrid')
          .where('lottotype', isEqualTo: key)
          .get();
      if (lottoSnap.docs.isNotEmpty) {
        var lData = lottoSnap.docs.first.data();
        setState(() {
          _allBasePayRates[key] = {
            'digit4': (lData['digit4'] ?? 0).toDouble(),
            'digit3': (lData['digit3'] ?? 0).toDouble(),
            'digit2': (lData['digit2'] ?? 0).toDouble(),
            'digit1': (lData['digit1'] ?? 0).toDouble(),
            'swift': (lData['swift'] ?? 0).toDouble(),
          };
        });
      }
    }
  }

  // ✅ ฟังก์ชันคำนวณเรท และเช็คว่า "โดนลดหลั่น" หรือไม่
  Map<String, dynamic> _getRateInfo(int index) {
    var bet = widget.draftBets[index];
    double input = double.tryParse(priceControllers[index]!.text) ?? 0;

    String cat = (bet['cat'] ?? "").replaceAll(RegExp(r'\s+'), "");
    String fieldKey = "";
    if (cat.contains("สี่ตัว"))
      fieldKey = "digit4";
    else if (cat.contains("สามตัว") && !cat.contains("โต๊ด"))
      fieldKey = "digit3";
    else if (cat.contains("โต๊ด"))
      fieldKey = "swift";
    else if (cat.contains("สองตัว"))
      fieldKey = "digit2";
    else if (cat.contains("วิ่ง"))
      fieldKey = "digit1";

    double base = _allBasePayRates[bet['lottoKey']]?[fieldKey] ?? 0;
    int steps = input > 0 ? ((input - 0.01) / _countPerNum).floor() : 0;
    int finalRate = (base * (1 - (steps * _payPercent / 100))).round();

    return {
      "rate": finalRate,
      "isDiscounted": finalRate < base, // ✅ เช็คว่าราคาลดลงไหม
      "baseRate": base,
    };
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      groupedIndices.putIfAbsent(cat, () => []).add(i);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("ระบุราคา"),
        backgroundColor: kMainGreen,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: groupedIndices.entries
                  .map((e) => _buildCategoryCard(e.key, e.value))
                  .toList(),
            ),
          ),
          // ✅ แสดงผลสลับกันตามสถานะ _showKeypad
          _showKeypad ? _buildSymmetricKeypad() : _buildSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              category,
              style: const TextStyle(
                color: kMainGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...indices.map((idx) => _buildPriceRow(idx)).toList(),
        ],
      ),
    );
  }

  Widget _buildPriceRow(int index) {
    var rateInfo = _getRateInfo(index);
    bool isDiscounted = rateInfo['isDiscounted'];
    bool isActive = _activeFieldIndex == index && _showKeypad;

    return InkWell(
      onTap: () => setState(() {
        _activeFieldIndex = index;
        _showKeypad = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isActive ? kMainGreen.withOpacity(0.05) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                widget.draftBets[index]['num']!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // ✅ ช่องใส่ยอดแทง (กรอบแดงถ้าโดนลดหลั่น)
            Container(
              width: 70,
              height: 35,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isDiscounted
                      ? Colors.red
                      : (isActive ? kMainGreen : Colors.grey.shade300),
                  width: isDiscounted ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  priceControllers[index]!.text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDiscounted ? Colors.red : kMainGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                "x${rateInfo['rate']}",
                style: TextStyle(
                  color: isDiscounted ? Colors.red : Colors.grey,
                  fontWeight: isDiscounted
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                "${((double.tryParse(priceControllers[index]!.text) ?? 0) * rateInfo['rate']).toStringAsFixed(0)} บ.",
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ปุ่มยืนยันส่งโพย และสรุปยอด
  Widget _buildSummaryFooter() {
    double total = 0;
    priceControllers.values.forEach(
      (c) => total += double.tryParse(c.text) ?? 0,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("ยอดแทงรวม:", style: TextStyle(fontSize: 16)),
              Text(
                "${total.toStringAsFixed(0)} บาท",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kMainGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _submitBetsToFirebase,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              "ยืนยันส่งโพย",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ฟังก์ชันส่งข้อมูลเข้า Firebase
  Future<void> _submitBetsToFirebase() async {
    WriteBatch batch = _db.batch();
    String billId = "BILL-${DateTime.now().millisecondsSinceEpoch}";

    for (int i = 0; i < widget.draftBets.length; i++) {
      double amount = double.tryParse(priceControllers[i]!.text) ?? 0;
      if (amount <= 0) continue;

      var rateInfo = _getRateInfo(i);
      var bet = widget.draftBets[i];

      DocumentReference ref = _db.collection('bets').doc();
      batch.set(ref, {
        'uid': _user?.uid,
        'billId': billId,
        'number': bet['num'],
        'category': bet['cat'],
        'lotto_key': bet['lottoKey'],
        'price_bet': amount, // ราคาที่แทง
        'rate_pay': rateInfo['rate'], // เรทจ่ายที่คำนวณแล้ว (ลดหลั่นแล้ว)
        'total_pay': amount * rateInfo['rate'], // ยอดที่จะได้รับถ้าถูก
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    await batch.commit();
    if (mounted) Navigator.pop(context); // ส่งเสร็จกลับหน้าแรก
  }

  // ✅ แป้นพิมพ์ (เหมือนเดิมแต่ปุ่มตกลงสั่งซ่อน)
  Widget _buildSymmetricKeypad() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  children: [
                    for (var i = 1; i <= 9; i++) _btn(i.toString()),
                    const SizedBox(),
                    _btn("0"),
                    _btn("del", isIcon: true),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _qBtn("+1", 1),
                    _qBtn("+5", 5),
                    _qBtn("+10", 10),
                    _qBtn("+100", 100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => setState(() => _showKeypad = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainGreen,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("ตกลง", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _btn(String k, {bool isIcon = false}) => InkWell(
    onTap: () => _onKeypadPress(isIcon ? "del" : k),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: isIcon ? const Icon(Icons.backspace) : Text(k)),
    ),
  );
  Widget _qBtn(String l, int v) => InkWell(
    onTap: () => setState(() {
      for (var c in priceControllers.values) {
        c.text = ((int.tryParse(c.text) ?? 0) + v).toString();
      }
    }),
    child: Container(
      margin: const EdgeInsets.only(bottom: 5),
      height: 40,
      decoration: BoxDecoration(
        color: kMainGreen,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(l, style: const TextStyle(color: Colors.white)),
      ),
    ),
  );

  void _onKeypadPress(String k) {
    String cur = priceControllers[_activeFieldIndex]!.text;
    if (k == "del") {
      if (cur.isNotEmpty)
        priceControllers[_activeFieldIndex]!.text = cur.substring(
          0,
          cur.length - 1,
        );
    } else {
      if (cur.length < 6) priceControllers[_activeFieldIndex]!.text = cur + k;
    }
    setState(() {});
  }
}
