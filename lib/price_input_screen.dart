import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kMainGreen = Color(0xFF11998E);
const Color kLightGreen = Color(0xFF38EF7D);

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

  int _getRate(int index) {
    var bet = widget.draftBets[index];
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

    return (_allBasePayRates[bet['lottoKey']]?[fieldKey] ?? 0).round();
  }

  void _updatePrice(int index, int addValue) {
    int current = int.tryParse(priceControllers[index]!.text) ?? 0;
    setState(
      () => priceControllers[index]!.text = (current + addValue).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // จัดกลุ่มข้อมูลตามหมวดหมู่เพื่อแสดงแบบ Card
    Map<String, List<int>> groupedIndices = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      if (!groupedIndices.containsKey(cat)) groupedIndices[cat] = [];
      groupedIndices[cat]!.add(i);
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.draftBets.first['lottoTitle'] ?? "ระบุราคา",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: kMainGreen,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Center(
              child: Text(
                "เครดิต: ${_userCredit.toStringAsFixed(2)}",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(10),
              children: groupedIndices.entries
                  .map((entry) => _buildCategoryCard(entry.key, entry.value))
                  .toList(),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<int> indices) {
    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kMainGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text(
                category,
                style: TextStyle(
                  color: kMainGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Container(
            height: 30,
            color: kMainGreen,
            child: Row(
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
                SizedBox(width: 40),
              ],
            ),
          ),
          ...indices.map((idx) => _buildPriceRow(idx)).toList(),
          _buildGroupSummary(indices),
        ],
      ),
    );
  }

  Widget _buildPriceRow(int index) {
    int rate = _getRate(index);
    double price = double.tryParse(priceControllers[index]!.text) ?? 0;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                widget.draftBets[index]['num']!,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              height: 35,
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: TextField(
                controller: priceControllers[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
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
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                "${(price * rate).toStringAsFixed(0)}",
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => priceControllers[index]!.clear()),
            icon: Icon(Icons.cancel, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSummary(List<int> indices) {
    double groupTotal = 0;
    for (var i in indices) {
      groupTotal += double.tryParse(priceControllers[i]!.text) ?? 0;
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: kMainGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "รวม ${groupTotal.toStringAsFixed(0)}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              "ส่วนลด 0",
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    double total = 0;
    priceControllers.values.forEach((c) {
      total += double.tryParse(c.text) ?? 0;
    });
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _quickPriceBtn("+1", 1),
              _quickPriceBtn("+5", 5),
              _quickPriceBtn("+10", 10),
              _quickPriceBtn("+100", 100),
            ],
          ),
          SizedBox(height: 15),
          InkWell(
            onTap: _submitFinalBets,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: kMainGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  "ตกลง (ยอดรวม $total)",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPriceBtn(String label, int value) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kMainGreen,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          onPressed: () {
            for (int i = 0; i < widget.draftBets.length; i++) {
              _updatePrice(i, value);
            }
          },
          child: Text(label),
        ),
      ),
    );
  }

  Future<void> _submitFinalBets() async {
    // ... โค้ดบันทึกเดิมที่คุณมี ...
  }
}
