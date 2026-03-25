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
  // ✅ โหลดจาก Firebase configs/payrate
  int _countPerNum = 5000;
  int _payPercent = 10;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController(text: "");
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. ดึงเครดิตผู้ใช้
      final userDoc = await _db.collection('users').doc(_user?.uid).get();

      // 2. ✅ ดึง Config การลดหลั่นจาก Firebase (ไม่ Fix ค่า)
      final payrateDoc = await _db.collection('configs').doc('payrate').get();
      if (payrateDoc.exists) {
        setState(() {
          _countPerNum = (payrateDoc.data()?['countpernum'] ?? 5000).toInt();
          _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
        });
      }

      // 3. ✅ ดึงเรทราคาจ่ายจาก Firebase (ไม่ Fix ค่า)
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
        setState(
          () => _userCredit = (userDoc.data()?['credit'] ?? 0).toDouble(),
        );
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  // ✅ ฟังก์ชันคำนวณเรทแบบลดหลั่น (ดึงค่าจากตัวแปรที่โหลดมาจาก Firebase)
  int _calculateStepRate(
    int index,
    double inputAmount,
    double totalAlreadyBet,
  ) {
    var bet = widget.draftBets[index];
    String cat = (bet['cat'] ?? "").replaceAll(RegExp(r'\s+'), "");
    String? lKey = bet['lottoKey'];

    String fieldKey = "";
    if (cat.contains("สี่ตัว"))
      fieldKey = "digit4";
    else if ((cat.contains("สามตัว") || cat.contains("3ตัว")) &&
        !cat.contains("โต๊ด"))
      fieldKey = "digit3";
    else if (cat.contains("โต๊ด"))
      fieldKey = "swift";
    else if (cat.contains("สองตัว"))
      fieldKey = "digit2";
    else if (cat.contains("วิ่ง"))
      fieldKey = "digit1";

    double baseRate = _allBasePayRates[lKey]?[fieldKey] ?? 0;
    if (baseRate <= 0) return 0;

    // คำนวณลดหลั่นตาม Config จาก Firebase
    double totalAmount = totalAlreadyBet + inputAmount;
    int steps = totalAmount > 0
        ? ((totalAmount - 0.01) / _countPerNum).floor()
        : 0;
    double finalRate = baseRate * (1 - (steps * _payPercent / 100));

    return finalRate.round();
  }

  @override
  Widget build(BuildContext context) {
    // จัดกลุ่มตาม Category เหมือนตัวอย่าง
    Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      if (!groupedIndices.containsKey(cat)) groupedIndices[cat] = [];
      groupedIndices[cat]!.add(i);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
              padding: const EdgeInsets.all(10),
              children: groupedIndices.entries
                  .map((e) => _buildCategoryCard(e.key, e.value))
                  .toList(),
            ),
          ),
          _buildFooterSummary(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          Container(
            color: kMainGreen,
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "รายการ",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "ราคา",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      "เรท",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "ยอดจ่าย",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(width: 30),
              ],
            ),
          ),
          ...indices.map((idx) => _buildPriceRow(idx)).toList(),
        ],
      ),
    );
  }

  Widget _buildPriceRow(int index) {
    // ใช้ StreamBuilder เพื่อดึงยอดแทงสะสมรวมในระบบมาคำนวณลดหลั่นแบบ Real-time
    var bet = widget.draftBets[index];
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('bets')
          .where('lotto_key', isEqualTo: bet['lottoKey'])
          .where('number', isEqualTo: bet['num'])
          .where('category', isEqualTo: bet['cat'])
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        double alreadyBet = 0;
        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) {
            alreadyBet += (d.get('price') ?? 0).toDouble();
          }
        }

        double currentInput =
            double.tryParse(priceControllers[index]!.text) ?? 0;
        int rate = _calculateStepRate(index, currentInput, alreadyBet);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    bet['num']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 35,
                  child: TextField(
                    controller: priceControllers[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    "x$rate",
                    style: const TextStyle(
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
                    (currentInput * rate).toStringAsFixed(0),
                    style: const TextStyle(
                      color: kMainGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => priceControllers[index]!.clear()),
                icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterSummary() {
    double total = 0;
    priceControllers.values.forEach(
      (c) => total += double.tryParse(c.text) ?? 0,
    );
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _quickBtn("+1", 1),
              _quickBtn("+5", 5),
              _quickBtn("+10", 10),
              _quickBtn("+100", 100),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainGreen,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => {}, // ใส่ฟังก์ชันบันทึก
            child: Text(
              "ตกลง (ยอดรวม ${total.toStringAsFixed(0)})",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, int val) {
    return ElevatedButton(
      onPressed: () {
        for (var c in priceControllers.values) {
          int cur = int.tryParse(c.text) ?? 0;
          c.text = (cur + val).toString();
        }
        setState(() {});
      },
      child: Text(label),
    );
  }
}
