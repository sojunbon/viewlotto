import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kMainGreen = Color(0xFF11998E);
const Color kLightGreen = Color(0xFF38EF7D);
const Color kDeepBlue = Color(0xFF1A3D5D);

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
  final TextEditingController _allPriceController = TextEditingController();

  double _userCredit = 0;
  int _countPerNum = 5000;
  int _payPercent = 10;

  // ✅ เก็บราคาจ่ายแยกตาม lottoKey (เช่น 'thai')
  Map<String, Map<String, double>> _allBasePayRates = {};
  bool _isLoadingRates = true;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController();
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    for (var c in priceControllers.values) {
      c.dispose();
    }
    _allPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final userDoc = await _db.collection('users').doc(_user?.uid).get();
      final payrateDoc = await _db.collection('configs').doc('payrate').get();

      // ดึง lottoKey ทั้งหมดจากรายการแทง (เช่น 'thai')
      Set<String?> selectedKeys = widget.draftBets
          .map((e) => e['lottoKey'])
          .toSet();

      for (String? key in selectedKeys) {
        if (key == null) continue;

        // Query หาเอกสารที่มี lottotype ตรงกัน
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

      if (mounted) {
        setState(() {
          _userCredit = (userDoc.data()?['credit'] ?? 0).toDouble();
          if (payrateDoc.exists) {
            _countPerNum = (payrateDoc.data()?['countpernum'] ?? 5000).toInt();
            _payPercent = (payrateDoc.data()?['pay_percent'] ?? 10).toInt();
          }
          _isLoadingRates = false; // ✅ โหลดเสร็จแล้ว
        });
      }
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  /*
  int _calculateCurrentRate(
    int index,
    double inputAmount,
    double totalAlreadyBet,
  ) {
    var bet = widget.draftBets[index];
    String cat = bet['cat'] ?? "";
    String? lKey = bet['lottoKey'];

    String fieldKey = "";
    if (cat.contains("4 ตัว"))
      fieldKey = "digit4";
    else if (cat.contains("3 ตัวบน") || cat.contains("3 ตัวตรง"))
      fieldKey = "digit3";
    else if (cat.contains("3 ตัวโต๊ด"))
      fieldKey = "swift";
    else if (cat.contains("2 ตัว"))
      fieldKey = "digit2";
    else if (cat.contains("วิ่ง"))
      fieldKey = "digit1";

    // ✅ ตรวจสอบว่ามีข้อมูลใน Map หรือไม่
    if (!_allBasePayRates.containsKey(lKey))
      return -1; // ส่ง -1 เพื่อบอกว่ายังไม่มีข้อมูล

    double baseRate = _allBasePayRates[lKey]?[fieldKey] ?? 0;
    if (baseRate <= 0) return 0; // ปิดรับจริงๆ

    double totalAmount = totalAlreadyBet + inputAmount;
    int steps = totalAmount > 0
        ? ((totalAmount - 0.01) / _countPerNum).floor()
        : 0;
    double finalRate = baseRate * (1 - (steps * _payPercent / 100));

    return finalRate.round();
  }
  

  int _calculateCurrentRate(
    int index,
    double inputAmount,
    double totalAlreadyBet,
  ) {
    var bet = widget.draftBets[index];
    String cat = bet['cat'] ?? "";
    String? lKey = bet['lottoKey'];

    String fieldKey = "";
    if (cat.contains("4 ตัว"))
      fieldKey = "digit4";
    else if (cat.contains("3 ตัวบน") || cat.contains("3 ตัวตรง"))
      fieldKey = "digit3";
    else if (cat.contains("3 ตัวโต๊ด"))
      fieldKey = "swift";
    else if (cat.contains("2 ตัว"))
      fieldKey = "digit2";
    else if (cat.contains("วิ่ง"))
      fieldKey = "digit1";

    // ✅ เพิ่ม LOG ตรงนี้เพื่อเช็คค่า
    // debugPrint("DEBUG: Checking index $index | Key: $lKey | Field: $fieldKey");

    // 1. เช็คว่า Map มีข้อมูลของหวยตัวนี้หรือยัง
    if (!_allBasePayRates.containsKey(lKey)) {
      return -1; // ถ้ายังไม่มี ต้องขึ้น "กำลังคำนวณ..."
    }
    
    // 2. ดึงราคาจ่ายพื้นฐาน
    double baseRate = _allBasePayRates[lKey]?[fieldKey] ?? 0;

    // ✅ ถ้า baseRate เป็น 0 ให้ลองเช็คว่าใน Map มันมีค่าอะไรอยู่บ้าง
    if (baseRate <= 0) {
      debugPrint("⚠️ ข้อมูลใน Map สำหรับ $lKey: ${_allBasePayRates[lKey]}");
      return 0; // ถ้าตรงนี้คืน 0 มันจะขึ้น "ปิดรับ"
    }

    double totalAmount = totalAlreadyBet + inputAmount;
    int steps = totalAmount > 0
        ? ((totalAmount - 0.01) / _countPerNum).floor()
        : 0;
    double finalRate = baseRate * (1 - (steps * _payPercent / 100));

    return finalRate.round();
  }
  */

  int _calculateCurrentRate(
    int index,
    double inputAmount,
    double totalAlreadyBet,
  ) {
    var bet = widget.draftBets[index];

    // ✅ 1. ล้างช่องว่างให้เกลี้ยง
    String rawCat = (bet['cat'] ?? "").toString();
    String cleanCat = rawCat.replaceAll(RegExp(r'\s+'), "");
    String? lKey = bet['lottoKey'];

    String fieldKey = "";

    // ✅ 2. Mapping ใหม่ (เน้นคำสำคัญที่ส่งมาจาก NumberInputScreen)
    if (cleanCat.contains("สี่ตัว") || cleanCat.contains("4ตัว")) {
      fieldKey = "digit4";
    } else if (cleanCat.contains("สามตัว") || cleanCat.contains("3ตัว")) {
      // แยก "ตรง/บน" กับ "โต๊ด"
      if (cleanCat.contains("โต๊ด")) {
        fieldKey = "swift";
      } else {
        fieldKey = "digit3";
      }
    } else if (cleanCat.contains("สองตัว") || cleanCat.contains("2ตัว")) {
      fieldKey = "digit2";
    } else if (cleanCat.contains("วิ่ง")) {
      fieldKey = "digit1";
    }

    // 🛠 DEBUG LOGS (ต้องเห็น fieldKey ไม่ว่างแล้ว!)
    debugPrint("------------------------------------------");
    debugPrint("🎯 INDEX: $index");
    debugPrint("📥 ค่าที่รับมา: '$rawCat'");
    debugPrint("🔑 คีย์ที่แมพได้: '$fieldKey'");

    // ✅ 3. เช็ค Map ข้อมูลจาก Firebase
    if (!_allBasePayRates.containsKey(lKey)) {
      return -1; // รอโหลด
    }

    // ✅ 4. ดึงราคาจ่ายจริง
    var rawRate = _allBasePayRates[lKey]?[fieldKey];
    double baseRate = double.tryParse(rawRate.toString()) ?? 0;

    debugPrint("💰 ราคาจ่ายจาก Map: $baseRate");
    debugPrint("------------------------------------------");

    if (baseRate <= 0) return 0;

    double totalAmount = totalAlreadyBet + inputAmount;
    int steps = totalAmount > 0
        ? ((totalAmount - 0.01) / _countPerNum).floor()
        : 0;
    double finalRate = baseRate * (1 - (steps * _payPercent / 100));

    return finalRate.round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "ระบุราคา",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kMainGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildQuickFillHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.draftBets.length,
              itemBuilder: (context, index) => _buildPriceItem(index),
            ),
          ),
          _buildSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildQuickFillHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "ใส่ราคาเท่ากันทั้งหมด:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 100,
            height: 40,
            child: TextField(
              controller: _allPriceController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "0",
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  for (var c in priceControllers.values) {
                    c.text = v;
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          const Text("บาท"),
        ],
      ),
    );
  }

  Widget _buildPriceItem(int index) {
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
        int rate = _calculateCurrentRate(index, currentInput, alreadyBet);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bet['num']!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  // ✅ ตรวจสอบสถานะการโหลดราคา
                  Text(
                    rate == -1
                        ? "กำลังโหลดราคา..."
                        : (rate > 0 ? "ราคาจ่าย: x$rate" : "🔴 ปิดรับ"),
                    style: TextStyle(
                      fontSize: 12,
                      color: rate == -1
                          ? Colors.blue
                          : (rate > 0 ? Colors.black87 : Colors.red),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${bet['lottoTitle']} | ${bet['cat']}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 80,
                height: 35,
                child: TextField(
                  controller: priceControllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: "0"),
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              const Text("บาท"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryFooter() {
    double total = 0;
    priceControllers.values.forEach((c) {
      total += double.tryParse(c.text) ?? 0;
    });
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("รวมทั้งหมด:", style: TextStyle(fontSize: 16)),
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
          InkWell(
            onTap: _submitFinalBets,
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kMainGreen, kLightGreen],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  "ยืนยันส่งโพย",
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

  Future<void> _submitFinalBets() async {
    double totalAmount = 0;
    priceControllers.values.forEach((c) {
      totalAmount += double.tryParse(c.text) ?? 0;
    });

    if (totalAmount > _userCredit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("ยอดเงินไม่พอ"),
        ),
      );
      return;
    }
    if (totalAmount <= 0) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: kMainGreen)),
      );
      WriteBatch batch = _db.batch();

      for (int i = 0; i < widget.draftBets.length; i++) {
        double price = double.tryParse(priceControllers[i]!.text) ?? 0;
        if (price <= 0) continue;
        var bet = widget.draftBets[i];
        DocumentReference ref = _db.collection('bets').doc();
        batch.set(ref, {
          'uid': _user?.uid,
          'email': _user?.email,
          'lotto_type': bet['lottoTitle'],
          'lotto_key': bet['lottoKey'],
          'category': bet['cat'],
          'number': bet['num'],
          'price': price,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      batch.update(_db.collection('users').doc(_user!.uid), {
        'credit': FieldValue.increment(-totalAmount),
      });
      await batch.commit();

      Navigator.pop(context); // ปิด loading
      _showSuccessAndExit();
    } catch (e) {
      Navigator.pop(context);
    }
  }

  void _showSuccessAndExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("สำเร็จ"),
        content: const Text("ส่งโพยเรียบร้อยแล้ว"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("ตกลง", style: TextStyle(color: kMainGreen)),
          ),
        ],
      ),
    );
  }
}
