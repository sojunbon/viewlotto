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
  List<String> draftBets = []; // รายการเลขที่เตรียมแทง
  bool isListExpanded = false; // สถานะเปิด/ปิด แถบซ้ายมือ

  final List<Map<String, String>> categories = [
    {"name": "สามตัวบน", "price": "x920"},
    {"name": "สามตัวโต๊ด", "price": "x120"},
    {"name": "สองตัวบน", "price": "x92"},
    {"name": "สองตัวล่าง", "price": "x92"},
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
        int maxLength = selectedCategory.contains("สาม") ? 3 : 2;
        if (currentNumber.length < maxLength) currentNumber += value;
      }
    });
  }

  void _generateRandomNumber() {
    int maxLength = selectedCategory.contains("สาม") ? 3 : 2;
    Random random = Random();
    String result = "";
    for (int i = 0; i < maxLength; i++) result += random.nextInt(10).toString();
    setState(() => currentNumber = result);
  }

  // ✅ ฟังก์ชันกลับเลข (Permutation)
  void _reverseNumber() {
    if (currentNumber.length < 2) return;

    List<String> results = [];
    void permute(List<String> chars, int index) {
      if (index == chars.length - 1) {
        results.add(chars.join());
        return;
      }
      for (int i = index; i < chars.length; i++) {
        var temp = chars[index];
        chars[index] = chars[i];
        chars[i] = temp;
        permute(chars, index + 1);
        temp = chars[index];
        chars[index] = chars[i];
        chars[i] = temp;
      }
    }

    permute(currentNumber.split(''), 0);
    setState(() {
      // เอาเลขที่ซ้ำออกและเพิ่มลงในรายการแทง
      draftBets.addAll(results.toSet().toList());
      currentNumber = ""; // ล้างช่องกรอก
      isListExpanded = true; // เปิดแถบข้างเพื่อโชว์เลขที่กลับแล้ว
    });
  }

  // บันทึกลง Firebase ทั้งหมดที่มีในรายการข้างๆ
  Future<void> _submitAllBets() async {
    if (draftBets.isEmpty && currentNumber.isEmpty) return;

    List<String> finalBets = List.from(draftBets);
    if (currentNumber.isNotEmpty) finalBets.add(currentNumber);

    try {
      final user = FirebaseAuth.instance.currentUser;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var num in finalBets) {
        DocumentReference ref = FirebaseFirestore.instance
            .collection('bets')
            .doc();
        batch.set(ref, {
          'uid': user?.uid,
          'lotto_type': widget.lottoTitle,
          'category': selectedCategory,
          'number': num,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ส่งโพยเรียบร้อย!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lottoTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF11998E),
        actions: [
          IconButton(
            icon: Icon(isListExpanded ? Icons.list_alt : Icons.list),
            onPressed: () => setState(() => isListExpanded = !isListExpanded),
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Sidebar ด้านซ้าย (รายการแทง) - ย่อ/ขยายได้
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isListExpanded ? 100 : 0,
            color: Colors.blueGrey[900],
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "รายการ",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: draftBets.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          draftBets[index],
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        trailing: InkWell(
                          onTap: () =>
                              setState(() => draftBets.removeAt(index)),
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (draftBets.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    onPressed: () => setState(() => draftBets.clear()),
                  ),
              ],
            ),
          ),

          // 2. ส่วนกรอกเลขหลัก
          Expanded(
            child: Column(
              children: [
                // หมวดหมู่
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 5,
                    children: categories.map((cat) {
                      bool isSelected = selectedCategory == cat['name'];
                      return ChoiceChip(
                        label: Text(
                          cat['name']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF11998E),
                        onSelected: (val) =>
                            setState(() => selectedCategory = cat['name']!),
                      );
                    }).toList(),
                  ),
                ),

                // ช่องโชว์เลข
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentNumber.isEmpty ? "---" : currentNumber,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                    ),
                  ),
                ),

                // ปุ่มกลับเลข
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: currentNumber.length >= 2
                        ? _reverseNumber
                        : null,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text("กลับเลข"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF11998E),
                    ),
                  ),
                ),

                const Spacer(),

                // แป้นพิมพ์
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
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
                              return ElevatedButton(
                                onPressed: () => _onKeyPress(key),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 1,
                                ),
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _submitAllBets,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF11998E),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          draftBets.isEmpty
                              ? "ส่งโพย"
                              : "ส่งโพย (${draftBets.length} ชุด)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
