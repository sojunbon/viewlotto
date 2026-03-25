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

  double _userCredit = 0;
  int _countPerNum = 5000; // จาก Firebase
  int _payPercent = 10; // จาก Firebase
  int? _activeFieldIndex; // เก็บ index ของแถวที่กำลังถูกเลือกกรอก

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController(text: "");
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final userDoc = await _db.collection('users').doc(_user?.uid).get();
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
    if (mounted)
      setState(() => _userCredit = (userDoc.data()?['credit'] ?? 0).toDouble());
  }

  int _calculateStepRate(
    int index,
    double inputAmount,
    double totalAlreadyBet,
  ) {
    var bet = widget.draftBets[index];
    String cat = (bet['cat'] ?? "").replaceAll(RegExp(r'\s+'), "");
    String fieldKey = "";
    if (cat.contains("สี่ตัว"))
      fieldKey = "digit4";
    else if ((cat.contains("สามตัว") || cat.contains("3ตัว")) &&
        !cat.contains("โต๊ด"))
      fieldKey = "digit3";
    else if (cat.contains("โต๊ด"))
      fieldKey = "swift";
    else if (cat.contains("สองตัว") || cat.contains("2ตัว"))
      fieldKey = "digit2";
    else if (cat.contains("วิ่ง"))
      fieldKey = "digit1";

    double baseRate = _allBasePayRates[bet['lottoKey']]?[fieldKey] ?? 0;
    if (baseRate <= 0) return 0;

    double totalAmount = totalAlreadyBet + inputAmount;
    int steps = totalAmount > 0
        ? ((totalAmount - 0.01) / _countPerNum).floor()
        : 0;
    return (baseRate * (1 - (steps * _payPercent / 100))).round();
  }

  void _onKeypadPress(String key) {
    if (_activeFieldIndex == null) return;
    String current = priceControllers[_activeFieldIndex!]!.text;
    setState(() {
      if (key == "del") {
        if (current.isNotEmpty)
          priceControllers[_activeFieldIndex!]!.text = current.substring(
            0,
            current.length - 1,
          );
      } else if (key.startsWith("+")) {
        int val = int.parse(key.substring(1));
        priceControllers[_activeFieldIndex!]!.text =
            ((int.tryParse(current) ?? 0) + val).toString();
      } else {
        priceControllers[_activeFieldIndex!]!.text = current + key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      if (!groupedIndices.containsKey(cat)) groupedIndices[cat] = [];
      groupedIndices[cat]!.add(i);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          "ระบุราคา",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: kMainGreen,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: groupedIndices.entries
                  .map((e) => _buildCategoryCard(e.key, e.value))
                  .toList(),
            ),
          ),
          if (_activeFieldIndex != null)
            _buildCustomKeypad(), // โชว์แป้นเฉพาะตอนเลือกแถว
          if (_activeFieldIndex == null)
            _buildSummaryFooter(), // โชว์สรุปยอดถ้าไม่ได้เลือกแถว
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kMainGreen, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              category,
              style: const TextStyle(
                color: kMainGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            color: kMainGreen,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "รายการ",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "ราคา",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "เรท",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "ยอดจ่าย",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                SizedBox(width: 35),
              ],
            ),
          ),
          ...indices.map((idx) => _buildPriceRow(idx)).toList(),
        ],
      ),
    );
  }

  Widget _buildPriceRow(int index) {
    bool isActive = _activeFieldIndex == index;
    int rate = _calculateStepRate(
      index,
      double.tryParse(priceControllers[index]!.text) ?? 0,
      0,
    );
    double price = double.tryParse(priceControllers[index]!.text) ?? 0;

    return InkWell(
      onTap: () => setState(() => _activeFieldIndex = index),
      child: Container(
        color: isActive ? kMainGreen.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 6),
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
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  width: 70,
                  height: 35,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive ? kMainGreen : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      priceControllers[index]!.text.isEmpty
                          ? "0"
                          : priceControllers[index]!.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  "x$rate",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: Text(
                  "${(price * rate).toStringAsFixed(0)} บ.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: kMainGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => priceControllers[index]!.clear()),
              icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomKeypad() {
    List<String> keys = [
      "1",
      "2",
      "3",
      "+1",
      "4",
      "5",
      "6",
      "+5",
      "7",
      "8",
      "9",
      "+10",
      "0",
      "del",
      "ตกลง",
      "+100",
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.8,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              String k = keys[index];
              bool isAction = k == "del" || k == "ตกลง" || k.startsWith("+");
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAction ? kMainGreen : Colors.white,
                  foregroundColor: isAction ? Colors.white : Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onPressed: () => k == "ตกลง"
                    ? setState(() => _activeFieldIndex = null)
                    : _onKeypadPress(k),
                child: k == "del"
                    ? const Icon(Icons.backspace_outlined, size: 18)
                    : Text(
                        k,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter() {
    double total = 0;
    priceControllers.values.forEach(
      (c) => total += double.tryParse(c.text) ?? 0,
    );
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kMainGreen,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () {},
        child: Text(
          "ตกลง (ยอดรวม ${total.toStringAsFixed(0)})",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
