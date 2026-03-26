import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// หน้าจอสำหรับระบุราคาที่ต้องการแทง (หลังจากเลือกเลขและประเภทในหน้า Draft) โดยมีการคำนวณอัตราจ่ายแบบขั้นบันได และแสดงยอดเงินคงเหลือแบบ Real-time
const Color kMainGreen = Color(0xFF11998E);

class PriceInputScreen extends StatefulWidget {
  final List<Map<String, String>> draftBets;
  const PriceInputScreen({super.key, required this.draftBets});

  @override
  State<PriceInputScreen> createState() => _PriceInputScreenState();
}

class _PriceInputScreenState extends State<PriceInputScreen> {
  final _db = FirebaseFirestore.instance;
  Map<int, TextEditingController> priceControllers = {};
  Map<String, Map<String, double>> _allBasePayRates = {};
  Map<String, Map<String, double>> _lottoMaxLimits = {};
  Map<String, double> _accumulatedPayoutMap = {};

  int _countPerNum = 95000;
  int _maxOver = 5000;
  int _payPercent = 10;
  double _userDiscountPercent = 0.0;
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

  // ✅ ฟังก์ชันแสดงยอดเงินแบบ Real-time บน AppBar
  Widget _buildCreditBadge() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        double credit = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          credit = (snapshot.data!.get('credit') ?? 0).toDouble();
        }

        return Container(
          margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.yellow,
                size: 14,
              ),
              const SizedBox(width: 5),
              Text(
                NumberFormat('#,###.00').format(credit),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadInitialData() async {
    try {
      final payrateDoc = await _db.collection('configs').doc('payrate').get();
      if (payrateDoc.exists) {
        setState(() {
          _countPerNum = (payrateDoc.data()?['countpernum'] ?? 95000).toInt();
          _maxOver = (payrateDoc.data()?['maxover'] ?? 5000).toInt();
          _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
        });
      }
    } catch (e) {
      debugPrint("🚨 Config Error: $e");
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        double discount = (userDoc.data()?['custdiscount'] ?? 0.0).toDouble();
        Timestamp? expire = userDoc.data()?['expire_discount'];
        if (expire != null && expire.toDate().isAfter(DateTime.now())) {
          setState(() => _userDiscountPercent = discount);
        }
      }
      await _fetchTotalPayoutRisk();
    }
    _loadBaseRates();
  }

  Future<void> _fetchTotalPayoutRisk() async {
    for (var bet in widget.draftBets) {
      String mapKey = "${bet['num']}_${bet['cat']}_${bet['lottoKey']}";
      final snap = await _db
          .collection('bets')
          .where('number', isEqualTo: bet['num'])
          .where('category', isEqualTo: bet['cat'])
          .where('lotto_key', isEqualTo: bet['lottoKey'])
          .where('status', isEqualTo: 'pending')
          .get();

      double totalRisk = 0;
      for (var doc in snap.docs) {
        totalRisk += (doc.data()['total_pay'] ?? 0).toDouble();
      }
      setState(() => _accumulatedPayoutMap[mapKey] = totalRisk);
    }
  }

  Future<void> _loadBaseRates() async {
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
          _lottoMaxLimits[key] = {
            'digit4': (lData['maxdigit4'] ?? 0).toDouble(),
            'digit3': (lData['maxdigit3'] ?? 0).toDouble(),
            'digit2': (lData['maxdigit2'] ?? 0).toDouble(),
            'digit1': (lData['maxdigit1'] ?? 0).toDouble(),
            'swift': (lData['maxswift'] ?? 0).toDouble(),
          };
        });
      }
    }
  }

  Map<String, dynamic> _getRateInfo(int index) {
    if (index >= widget.draftBets.length)
      return {
        "rate": 0,
        "isDiscounted": false,
        "isClosed": false,
        "isOverLimit": false,
      };

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
    double maxLimit = _lottoMaxLimits[bet['lottoKey']]?[fieldKey] ?? 0;
    bool isOverLimit = maxLimit > 0 && input > maxLimit;

    String mapKey = "${bet['num']}_${bet['cat']}_${bet['lottoKey']}";
    double accumulatedRisk = _accumulatedPayoutMap[mapKey] ?? 0;

    // 🛠️ NEW LOGIC: ขั้นบันได (Range Step)
    int steps = 0;
    if (accumulatedRisk >= _countPerNum) {
      steps = 1;
      double excess = accumulatedRisk - _countPerNum;
      if (excess > 0 && _maxOver > 0) {
        steps += (excess / _maxOver).floor();
      }
    }

    int finalRate = (base * (1 - (steps * _payPercent / 100))).round();

    if (finalRate <= 0)
      return {
        "rate": 0,
        "isDiscounted": true,
        "isClosed": true,
        "isOverLimit": isOverLimit,
        "maxAmt": maxLimit,
      };

    return {
      "rate": finalRate,
      "isDiscounted": finalRate < base,
      "isClosed": false,
      "isOverLimit": isOverLimit,
      "maxAmt": maxLimit,
    };
  }

  Future<void> _submitBetsToFirebase() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    for (int i = 0; i < widget.draftBets.length; i++) {
      var r = _getRateInfo(i);
      if (r['isOverLimit']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "เลข ${widget.draftBets[i]['num']} แทงเกินยอดสูงสุด (${r['maxAmt']} บ.)",
            ),
          ),
        );
        return;
      }
    }

    double total = 0;
    priceControllers.values.forEach(
      (c) => total += double.tryParse(c.text) ?? 0,
    );
    if (total <= 0) return;

    double disc = (total * _userDiscountPercent) / 100;
    double netPay = total - disc;

    WriteBatch batch = _db.batch();
    try {
      final userRef = _db.collection('users').doc(user.uid);
      final userSnap = await userRef.get();
      double currentCredit = (userSnap.data()?['credit'] ?? 0.0).toDouble();

      if (currentCredit < netPay) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("เครดิตไม่เพียงพอ")));
        return;
      }

      batch.update(userRef, {'credit': FieldValue.increment(-netPay)});
      String billId = "BILL-${DateTime.now().millisecondsSinceEpoch}";
      batch.set(_db.collection('bills').doc(billId), {
        'billId': billId,
        'uid': user.uid,
        'net_pay': netPay,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      for (int i = 0; i < widget.draftBets.length; i++) {
        double amt = double.tryParse(priceControllers[i]!.text) ?? 0;
        if (amt <= 0) continue;
        var r = _getRateInfo(i);
        batch.set(_db.collection('bets').doc(), {
          'uid': user.uid,
          'billId': billId,
          'number': widget.draftBets[i]['num'],
          'category': widget.draftBets[i]['cat'],
          'lotto_key': widget.draftBets[i]['lottoKey'],
          'price_bet': amt,
          'rate_pay': r['rate'],
          'total_pay': amt * r['rate'],
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      Navigator.pop(context);
    } catch (e) {
      debugPrint("🚨 Submit Error: $e");
    }
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
        title: const Text(
          "ระบุราคา",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kMainGreen,
        centerTitle: false, // ✅ เว้นที่ให้ Badge ยอดเงิน
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [_buildCreditBadge()], // ✅ แสดงยอดเงิน Real-time
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
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
    indices.forEach(
      (idx) =>
          categoryTotal += double.tryParse(priceControllers[idx]!.text) ?? 0,
    );
    double discountAmount = (categoryTotal * _userDiscountPercent) / 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: kMainGreen, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              category,
              style: const TextStyle(
                color: kMainGreen,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          ...indices.map((i) => _buildPriceRow(i)).toList(),
          const SizedBox(height: 15),
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
                  decoration: const BoxDecoration(
                    color: kMainGreen,
                    borderRadius: BorderRadius.horizontal(
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
                        categoryTotal.toStringAsFixed(0),
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
                  child: Text(
                    "ส่วนลด ${discountAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
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
    var r = _getRateInfo(index);
    bool active = _activeFieldIndex == index && _showKeypad;
    bool over = r['isOverLimit'];
    bool red = r['isDiscounted'] || r['isClosed'] || over;

    return InkWell(
      onTap: () => setState(() {
        _activeFieldIndex = index;
        _showKeypad = true;
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        color: active ? kMainGreen.withOpacity(0.08) : Colors.transparent,
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
                color: r['isClosed'] ? Colors.grey.shade200 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: over
                      ? Colors.red.shade900
                      : (red
                            ? Colors.red
                            : (active ? kMainGreen : Colors.grey.shade300)),
                  width: over ? 3.0 : (red ? 2.5 : 1.5),
                ),
              ),
              child: Center(
                child: Text(
                  r['isClosed'] ? "เต็ม" : priceControllers[index]!.text,
                  style: TextStyle(
                    color: red ? Colors.red : Colors.black,
                    fontWeight: over ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  "x${r['rate']}",
                  style: TextStyle(color: red ? Colors.red : Colors.black),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                "${((double.tryParse(priceControllers[index]!.text) ?? 0) * r['rate']).toStringAsFixed(0)} บ.",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: red ? Colors.red : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              onPressed: () => setState(() => priceControllers[index]!.clear()),
              icon: Icon(Icons.cancel, color: Colors.grey.shade400, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 5),
          ],
        ),
      ),
    );
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
        int current = int.tryParse(c.text) ?? 0;
        c.text = (current + v).toString();
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
    double disc = (total * _userDiscountPercent) / 100;
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
              const Text("ยอดสุทธิที่ต้องจ่าย:"),
              Text(
                "${(total - disc).toStringAsFixed(2)} บาท",
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
}
