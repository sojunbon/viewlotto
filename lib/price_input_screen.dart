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

    return {"rate": finalRate, "isDiscounted": finalRate < base};
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      groupedIndices.putIfAbsent(cat, () => []).add(i);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("ระบุราคา", style: TextStyle(color: Colors.white)),
        backgroundColor: kMainGreen,
        centerTitle: true,
        elevation: 0,
      ),
      body: widget.draftBets.isEmpty
          ? const Center(child: Text("ไม่มีรายการแทง"))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: kMainGreen, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 🏆 Header: ชื่อประเภทหวย
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              category,
              style: const TextStyle(
                color: kMainGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // 📋 Column Header
          Container(
            color: kMainGreen,
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                SizedBox(width: 40),
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
              thickness: 1.5,
              color: Color(0xFFEEEEEE),
              indent: 10,
              endIndent: 10,
            ),
            itemBuilder: (context, i) => _buildPriceRow(indices[i]),
          ),
          const SizedBox(height: 15),
          // 💰 สรุปยอดรวมกลุ่มแบบ Capsule
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kMainGreen,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "รวม ",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        "${categoryTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: kMainGreen, width: 1.5),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "ส่วนลด 0",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
        decoration: BoxDecoration(
          color: isActive ? kMainGreen.withOpacity(0.08) : Colors.transparent,
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
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDiscounted
                      ? Colors.red
                      : (isActive ? kMainGreen : Colors.grey.shade300),
                  width: isDiscounted ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  priceControllers[index]!.text.isEmpty
                      ? "0"
                      : priceControllers[index]!.text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                    fontSize: 14,
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
                "${((double.tryParse(priceControllers[index]!.text) ?? 0) * rateInfo['rate']).toStringAsFixed(0)} บาท",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDiscounted ? Colors.red : Colors.black87,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 24),
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
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // แป้นพิมพ์และส่วนสรุปยอดรวม (คงเดิมตาม Logic ที่แก้ไปแล้ว)
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
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
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
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => setState(() => _showKeypad = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainGreen,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text(
              "ตกลง",
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

  Widget _btn(String k, {bool isIcon = false}) => InkWell(
    onTap: () => _onKeypadPress(isIcon ? "del" : k),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: isIcon
            ? const Icon(Icons.backspace, size: 22)
            : Text(
                k,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      margin: const EdgeInsets.only(bottom: 8),
      height: 45,
      decoration: BoxDecoration(
        color: kMainGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          l,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            onPressed: () async {
              // ... Logic ส่ง Firebase ...
              Navigator.pop(context);
            },
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
}
