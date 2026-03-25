import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // ✅ กำหนดให้แถวแรกถูกเลือกเป็นค่าเริ่มต้น เพื่อให้แป้นเลขพร้อมใช้งานทันที
  int _activeFieldIndex = 0;

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

  // ✅ ฟังก์ชันปุ่มลัด: ใส่ค่าให้ทุกช่องพร้อมกัน
  void _addAllPrices(int value) {
    setState(() {
      for (var controller in priceControllers.values) {
        int current = int.tryParse(controller.text) ?? 0;
        controller.text = (current + value).toString();
      }
    });
  }

  void _onKeypadPress(String key) {
    String current = priceControllers[_activeFieldIndex]!.text;
    setState(() {
      if (key == "del") {
        if (current.isNotEmpty) {
          priceControllers[_activeFieldIndex]!.text = current.substring(
            0,
            current.length - 1,
          );
        }
      } else {
        // จำกัดไม่ให้กรอกเลขเกินความจำเป็น (เช่น ไม่เกิน 6 หลัก)
        if (current.length < 6) {
          priceControllers[_activeFieldIndex]!.text = current + key;
        }
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
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text(
          "ระบุราคา",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: kMainGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
          _buildCustomKeypad(), // ✅ แป้นพิมพ์แสดงค้างไว้ด้านล่างเสมอ
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kMainGreen.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
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
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                  flex: 2,
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
                SizedBox(width: 40),
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
    var bet = widget.draftBets[index];

    // ดึงเรทราคา (ดึงจาก Firebase configs)
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

    double baseRate = _allBasePayRates[bet['lottoKey']]?[fieldKey] ?? 0;
    double inputAmount = double.tryParse(priceControllers[index]!.text) ?? 0;

    // คำนวณลดหลั่น (Step Payrate)
    int steps = inputAmount > 0
        ? ((inputAmount - 0.01) / _countPerNum).floor()
        : 0;
    int currentRate = (baseRate * (1 - (steps * _payPercent / 100))).round();

    return InkWell(
      onTap: () => setState(() => _activeFieldIndex = index),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? kMainGreen.withOpacity(0.1) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: 60,
                  height: 35,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive ? kMainGreen : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      priceControllers[index]!.text,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  "x$currentRate",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: Text(
                  "${(inputAmount * currentRate).toStringAsFixed(0)} บ.",
                  style: const TextStyle(
                    color: kMainGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => priceControllers[index]!.clear()),
              icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔢 ตัวเลข 1-9 และ 0
              Expanded(
                flex: 3,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    ...[
                      "1",
                      "2",
                      "3",
                      "4",
                      "5",
                      "6",
                      "7",
                      "8",
                      "9",
                    ].map((k) => _btn(k, () => _onKeypadPress(k))),
                    const SizedBox(), // ช่องว่าง
                    _btn("0", () => _onKeypadPress("0")),
                    _btn(
                      "⌫",
                      () => _onKeypadPress("del"),
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ⚡ ปุ่มลัดด้านขวา (+1, +5...)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _quickBtn("+1", 1),
                    _quickBtn("+5", 5),
                    _quickBtn("+10", 10),
                    _quickBtn("+100", 100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // ✅ ปุ่มตกลงด้านล่างสุด
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainGreen,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // TODO: บันทึกข้อมูล
            },
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

  Widget _btn(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _quickBtn(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _addAllPrices(value),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: kMainGreen,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
