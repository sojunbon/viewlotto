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

  Map<int, TextEditingController> priceControllers = {};
  Map<String, Map<String, double>> _allBasePayRates = {};
  Map<String, double> _accumulatedPayoutMap = {};

  int _countPerNum = 5000;
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

  Future<void> _loadInitialData() async {
    try {
      final payrateDoc = await _db.collection('configs').doc('payrate').get();
      if (payrateDoc.exists) {
        setState(() {
          _countPerNum = (payrateDoc.data()?['countpernum'] ?? 5000).toInt();
          _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
        });
      }
    } catch (e) {
      debugPrint("🚨 [Debug] ดึง Config ผิดพลาด: $e");
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          var userData = userDoc.data()!;
          Timestamp? expire = userData['expire_discount'];
          double discount = (userData['custdiscount'] ?? 0.0).toDouble();
          if (expire != null && expire.toDate().isAfter(DateTime.now())) {
            setState(() => _userDiscountPercent = discount);
          }
        }
        await _fetchTotalPayoutRisk();
      } catch (e) {
        debugPrint("🚨 [Debug] ดึงข้อมูล User/Payout ผิดพลาด: $e");
      }
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
      _accumulatedPayoutMap[mapKey] = totalRisk;
    }
    setState(() {});
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
        });
      }
    }
  }

  Map<String, dynamic> _getRateInfo(int index) {
    if (index >= widget.draftBets.length)
      return {"rate": 0, "isDiscounted": false, "isClosed": false};
    var bet = widget.draftBets[index];

    // ✅ ดึงราคาที่กำลังพิมพ์อยู่ในช่องนี้มาคำนวณ Real-time
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
    String mapKey = "${bet['num']}_${bet['cat']}_${bet['lottoKey']}";
    double accumulatedRisk = _accumulatedPayoutMap[mapKey] ?? 0;

    // ✅ คำนวณความเสี่ยงรวม (ยอดจ่ายสะสมเดิม + ยอดจ่ายที่กำลังพิมพ์)
    double totalPotentialRisk = accumulatedRisk + (input * base);

    // ✅ คิดขั้นบันไดตามยอดรวมความเสี่ยง
    int steps = totalPotentialRisk > 0
        ? (totalPotentialRisk / _countPerNum).floor()
        : 0;
    int finalRate = (base * (1 - (steps * _payPercent / 100))).round();

    if (finalRate <= 0 && totalPotentialRisk > 0) {
      return {"rate": 0, "isDiscounted": true, "isClosed": true};
    }

    return {
      "rate": finalRate,
      "isDiscounted": finalRate < base,
      "isClosed": false,
    };
  }

  Future<void> _submitBetsToFirebase() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double grandTotal = 0;
    priceControllers.values.forEach(
      (c) => grandTotal += double.tryParse(c.text) ?? 0,
    );
    if (grandTotal <= 0) return;

    for (int i = 0; i < widget.draftBets.length; i++) {
      if (_getRateInfo(i)['isClosed']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("มีเลขที่ปิดรับแทงแล้วในรายการ")),
        );
        return;
      }
    }

    double totalDiscount = (grandTotal * _userDiscountPercent) / 100;
    double netPay = grandTotal - totalDiscount;

    WriteBatch batch = _db.batch();
    String billId = "BILL-${DateTime.now().millisecondsSinceEpoch}";

    try {
      final userRef = _db.collection('users').doc(user.uid);
      final userSnap = await userRef.get();
      double currentCredit = (userSnap.data()?['credit'] ?? 0.0).toDouble();

      if (currentCredit < netPay) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("เครดิตไม่เพียงพอ"),
            ),
          );
        return;
      }

      batch.update(userRef, {'credit': FieldValue.increment(-netPay)});

      DocumentReference billRef = _db.collection('bills').doc(billId);
      batch.set(billRef, {
        'billId': billId,
        'uid': user.uid,
        'total_price': grandTotal,
        'total_discount': totalDiscount,
        'net_pay': netPay,
        'discount_percent': _userDiscountPercent,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      for (int i = 0; i < widget.draftBets.length; i++) {
        double amount = double.tryParse(priceControllers[i]!.text) ?? 0;
        if (amount <= 0) continue;
        var rateInfo = _getRateInfo(i);
        var bet = widget.draftBets[i];
        DocumentReference betRef = _db.collection('bets').doc();
        batch.set(betRef, {
          'uid': user.uid,
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
    } catch (e) {
      debugPrint("🚨 Error: $e");
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
    double total = 0;
    indices.forEach(
      (idx) => total += double.tryParse(priceControllers[idx]!.text) ?? 0,
    );
    double discount = (total * _userDiscountPercent) / 100;
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: indices.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (c, i) => _buildPriceRow(indices[i]),
          ),
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
                  child: Text(
                    "รวม ${total.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: kMainGreen),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(30),
                    ),
                  ),
                  child: Text(
                    "ส่วนลด ${discount.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.grey),
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
    bool isClosed = rateInfo['isClosed'];
    bool isDiscounted =
        rateInfo['isDiscounted']; // ✅ สำหรับแจ้งเตือนเลขอั้น (Tier 1 ขึ้นไป)
    bool isActive = _activeFieldIndex == index && _showKeypad;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
      color: isActive ? kMainGreen.withOpacity(0.08) : Colors.transparent,
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
              color: isClosed ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              // ✅ ใส่กรอบแดงทันทีหากเป็นเลขอั้นหรือเต็ม
              border: Border.all(
                color: isClosed || isDiscounted
                    ? Colors.red
                    : (isActive ? kMainGreen : Colors.grey.shade300),
                width: isClosed || isDiscounted ? 2.5 : 1.5,
              ),
            ),
            child: Center(
              child: Text(
                isClosed ? "เต็ม" : priceControllers[index]!.text,
                style: TextStyle(
                  color: isClosed || isDiscounted ? Colors.red : Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "x${rateInfo['rate']}",
                style: TextStyle(
                  color: isClosed || isDiscounted ? Colors.red : Colors.black,
                  fontWeight: isClosed || isDiscounted
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isClosed || isDiscounted ? Colors.red : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
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
    setState(() {}); // ✅ สั่งคำนวณ rateInfo ใหม่ทันทีที่พิมพ์
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
