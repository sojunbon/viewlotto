import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color kMainGreen = Color(0xFF11998E);
const Color kLightGreen = Color(0xFF38EF7D);
const Color kDeepBlue = Color(0xFF1A3D5D);

class PriceInputScreen extends StatefulWidget {
  final List<Map<String, String>> draftBets; // รับรายการเลขมาจากหน้าก่อนหน้า
  final String lottoTitle;
  final String lottoKey;

  const PriceInputScreen({
    super.key,
    required this.draftBets,
    required this.lottoTitle,
    required this.lottoKey,
  });

  @override
  State<PriceInputScreen> createState() => _PriceInputScreenState();
}

class _PriceInputScreenState extends State<PriceInputScreen> {
  // เก็บราคาของเลขแต่ละตัว โดยใช้ Index เป็น Key
  Map<int, TextEditingController> priceControllers = {};
  final TextEditingController _allPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // สร้าง Controller สำหรับเลขทุกตัว
    for (int i = 0; i < widget.draftBets.length; i++) {
      priceControllers[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in priceControllers.values) {
      c.dispose();
    }
    _allPriceController.dispose();
    super.dispose();
  }

  // ✅ ฟังก์ชันใส่ราคาเท่ากันทั้งหมด
  void _setAllPrices(String value) {
    if (value.isEmpty) return;
    setState(() {
      for (var c in priceControllers.values) {
        c.text = value;
      }
    });
  }

  // ✅ คำนวณยอดรวมทั้งหมด
  double _calculateTotal() {
    double total = 0;
    for (var c in priceControllers.values) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  // ✅ จัดกลุ่มเลขตามประเภทเพื่อโชว์ Header
  Map<String, List<int>> _getGroupedBets() {
    Map<String, List<int>> groups = {};
    for (int i = 0; i < widget.draftBets.length; i++) {
      String cat = widget.draftBets[i]['cat']!;
      if (!groups.containsKey(cat)) groups[cat] = [];
      groups[cat]!.add(i);
    }
    return groups;
  }

  // ✅ ส่งโพยเข้า Firebase (Batch Write)
  Future<void> _submitFinalBets() async {
    double totalAmount = _calculateTotal();
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาใส่ราคาอย่างน้อย 1 รายการ")),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            const Center(child: CircularProgressIndicator(color: kMainGreen)),
      );

      final user = FirebaseAuth.instance.currentUser;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < widget.draftBets.length; i++) {
        double price = double.tryParse(priceControllers[i]!.text) ?? 0;
        if (price <= 0) continue; // ข้ามตัวที่ไม่ได้ใส่ราคา

        DocumentReference ref = FirebaseFirestore.instance
            .collection('bets')
            .doc();
        batch.set(ref, {
          'uid': user?.uid,
          'email': user?.email,
          'lotto_type': widget.lottoTitle,
          'lotto_key': widget.lottoKey,
          'category': widget.draftBets[i]['cat'],
          'number': widget.draftBets[i]['num'],
          'price': price,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      Navigator.pop(context); // ปิด Loading

      if (mounted) {
        _showSuccessAndExit();
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint("Submit Error: $e");
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
              Navigator.pop(ctx);
              Navigator.pop(context); // กลับหน้าเลือกหวย
              Navigator.pop(context); // กลับหน้า Home
            },
            child: const Text("ตกลง", style: TextStyle(color: kMainGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var grouped = _getGroupedBets();

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
          // 1. ส่วนใส่ราคาเท่ากันทั้งหมด (Quick Fill)
          _buildQuickFillHeader(),

          // 2. รายการเลขแยกตามกลุ่ม
          Expanded(
            child: ListView(
              children: grouped.entries.map((entry) {
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: kDeepBlue.withOpacity(0.1),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: kDeepBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...entry.value.map((index) => _buildPriceItem(index)),
                  ],
                );
              }).toList(),
            ),
          ),

          // 3. สรุปยอดและปุ่มส่งโพย
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
              style: TextStyle(fontWeight: FontWeight.bold),
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
              onChanged: _setAllPrices,
            ),
          ),
          const SizedBox(width: 10),
          const Text("บาท"),
        ],
      ),
    );
  }

  Widget _buildPriceItem(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: [
          Text(
            widget.draftBets[index]['num']!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            height: 35,
            child: TextField(
              controller: priceControllers[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: "0"),
              onChanged: (val) => setState(() {}), // อัปเดตยอดรวม Real-time
            ),
          ),
          const SizedBox(width: 10),
          const Text("บาท"),
        ],
      ),
    );
  }

  Widget _buildSummaryFooter() {
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
                "${_calculateTotal()} บาท",
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
}
