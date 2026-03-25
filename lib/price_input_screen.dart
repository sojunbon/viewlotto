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

  int _countPerNum = 5000;
  int _payPercent = 10;
  int _activeFieldIndex = 0;
  bool _showKeypad = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadInitialData();
  }

  void _initControllers() {
    priceControllers.clear();
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController(text: "");
    }
  }

  Future<void> _loadInitialData() async {
    final payrateDoc = await _db.collection('configs').doc('payrate').get();
    if (payrateDoc.exists) {
      setState(() {
        _countPerNum = (payrateDoc.data()?['countpernum'] ?? 5000).toInt();
        _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
      });
    }

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

  Map<String, dynamic> _getRateInfo(int index) {
    if (index >= widget.draftBets.length)
      return {"rate": 0, "isDiscounted": false};
    var bet = widget.draftBets[index];
    double input = double.tryParse(priceControllers[index]?.text ?? "") ?? 0;
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
      "isDiscounted": finalRate < base,
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("ระบุราคา"),
        backgroundColor: kMainGreen,
        centerTitle: true,
      ),
      body: widget.draftBets.isEmpty
          ? const Center(child: Text("ไม่มีรายการแทง"))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(10),
                    children: groupedIndices.entries
                        .map((e) => _buildCategoryCard(e.key, e.value))
                        .toList(),
                  ),
                ),
                _showKeypad ? _buildSymmetricKeypad() : _buildSummaryFooter(),
              ],
            ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    double categoryTotal = 0;
    for (int idx in indices) {
      categoryTotal += double.tryParse(priceControllers[idx]!.text) ?? 0;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 🏆 Header: ชื่อประเภท
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kMainGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          // 📋 Column Headers
          Container(
            color: kMainGreen,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "รายการ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "ราคา",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "เรท",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "ยอดจ่าย",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 35),
              ],
            ),
          ),
          // 🔢 รายการตัวเลข
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: indices.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 1.2,
              color: Color(0xFFE0E0E0),
            ), // เส้นแบ่งหนาขึ้น
            itemBuilder: (context, i) => _buildPriceRow(indices[i]),
          ),
          // 💰 สรุปยอดกลุ่ม
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  "รวมยอดแทงกลุ่มนี้: ",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${categoryTotal.toStringAsFixed(0)} บาท",
                  style: const TextStyle(
                    fontSize: 15,
                    color: kMainGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 35),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          color: isActive ? kMainGreen.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  widget.draftBets[index]['num']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Container(
              width: 70,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDiscounted
                      ? Colors.red
                      : (isActive ? kMainGreen : Colors.grey.shade300),
                  width: isDiscounted ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  priceControllers[index]!.text.isEmpty
                      ? "0"
                      : priceControllers[index]!.text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDiscounted ? Colors.red : kMainGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  "x${rateInfo['rate']}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDiscounted ? Colors.red : Colors.grey,
                    fontWeight: isDiscounted
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "${((double.tryParse(priceControllers[index]!.text) ?? 0) * rateInfo['rate']).toStringAsFixed(0)} บ.",
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  Map<int, String> currentValues = {};
                  for (int i = 0; i < widget.draftBets.length; i++)
                    currentValues[i] = priceControllers[i]!.text;
                  widget.draftBets.removeAt(index);
                  _initControllers();
                  for (int i = 0; i < widget.draftBets.length; i++) {
                    if (i < index)
                      priceControllers[i]!.text = currentValues[i]!;
                    else
                      priceControllers[i]!.text = currentValues[i + 1]!;
                  }
                  if (_activeFieldIndex >= widget.draftBets.length)
                    _activeFieldIndex = widget.draftBets.isEmpty
                        ? 0
                        : widget.draftBets.length - 1;
                  if (widget.draftBets.isEmpty) _showKeypad = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryFooter() {
    double total = 0;
    priceControllers.values.forEach(
      (c) => total += double.tryParse(c.text) ?? 0,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("ยอดแทงรวมทั้งหมด:", style: TextStyle(fontSize: 16)),
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
        'price_bet': amount,
        'rate_pay': rateInfo['rate'],
        'total_pay': amount * rateInfo['rate'],
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }
    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

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
      child: Center(
        child: isIcon ? const Icon(Icons.backspace, size: 20) : Text(k),
      ),
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
    if (widget.draftBets.isEmpty) return;
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
