import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class NumberInputScreen extends StatefulWidget {
  final String lottoTitle;
  const NumberInputScreen({super.key, required this.lottoTitle});

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  String selectedCategory = "สามตัวบน";
  String currentNumber = "";

  final List<Map<String, String>> categories = [
    {"name": "สามตัวบน", "price": "x920"},
    {"name": "สามตัวโต๊ด", "price": "x120"},
    {"name": "สองตัวบน", "price": "x92"},
    {"name": "สองตัวล่าง", "price": "x92"},
    {"name": "วิ่งบน", "price": "x3.2"},
    {"name": "วิ่งล่าง", "price": "x4.2"},
  ];

  void _onKeyPress(String value) {
    setState(() {
      if (value == "⌫") {
        if (currentNumber.isNotEmpty) {
          currentNumber = currentNumber.substring(0, currentNumber.length - 1);
        }
      } else if (value == "สุ่ม") {
        _generateRandomNumber();
      } else {
        int maxLength = selectedCategory.contains("สาม")
            ? 3
            : (selectedCategory.contains("วิ่ง") ? 1 : 2);
        if (currentNumber.length < maxLength) {
          currentNumber += value;
        }
      }
    });
  }

  void _generateRandomNumber() {
    int maxLength = selectedCategory.contains("สาม")
        ? 3
        : (selectedCategory.contains("วิ่ง") ? 1 : 2);
    Random random = Random();
    String result = "";
    for (int i = 0; i < maxLength; i++) {
      result += random.nextInt(10).toString();
    }
    setState(() => currentNumber = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.lottoTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF11998E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // ✅ แก้ Overflow โดยใช้ SafeArea + SingleChildScrollView หรือ Column ที่จัด Layout ใหม่
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // 1. ส่วนเลือกประเภทรางวัล
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: categories.map((cat) {
                          bool isSelected = selectedCategory == cat['name'];
                          return InkWell(
                            onTap: () => setState(() {
                              selectedCategory = cat['name']!;
                              currentNumber = "";
                            }),
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF11998E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF11998E),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cat['name']!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    cat['price']!,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // 2. ช่องแสดงตัวเลข
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          selectedCategory.contains("สาม")
                              ? 3
                              : (selectedCategory.contains("วิ่ง") ? 1 : 2),
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 65,
                            height: 75,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                currentNumber.length > index
                                    ? currentNumber[index]
                                    : "-",
                                style: const TextStyle(
                                  fontSize: 35,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. แป้นพิมพ์ตัวเลข (固定ด้านล่าง)
            Container(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ ป้องกันการขยายตัวเกินจำเป็น
                children: [
                  GridView.count(
                    shrinkWrap: true, // ✅ สำคัญมากเมื่อใช้ใน Column
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio:
                        1.9, // ✅ ปรับความกว้าง-สูงของปุ่มให้เล็กลงเพื่อลดความสูงรวม
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children:
                        [
                          "1",
                          "2",
                          "3",
                          "4",
                          "5",
                          "6",
                          "7",
                          "8",
                          "9",
                          "สุ่ม",
                          "0",
                          "⌫",
                        ].map((key) {
                          return InkWell(
                            onTap: () => _onKeyPress(key),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFF38EF7D),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: key == "⌫"
                                    ? const Icon(
                                        Icons.backspace_outlined,
                                        color: Color(0xFF11998E),
                                      )
                                    : Text(
                                        key,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 15),
                  // ปุ่มส่งโพย
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitBet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11998E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "ใส่ราคา / ส่งโพย",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันบันทึกโพย (เหมือนเดิม)
  Future<void> _submitBet() async {
    if (currentNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรุณากรอกเลข")));
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('bets').add({
        'uid': user?.uid,
        'email': user?.email,
        'lotto_type': widget.lottoTitle,
        'category': selectedCategory,
        'number': currentNumber,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("สำเร็จ!")));
        Navigator.pop(context);
      }
    } catch (e) {
      print(e);
    }
  }
}
