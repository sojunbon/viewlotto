import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class NumberInputScreen extends StatefulWidget {
  final String lottoTitle; // ชื่อภาษาไทยสำหรับโชว์
  final String lottoKey; // คีย์ภาษาอังกฤษสำหรับเช็ค Config (เช่น thai, lao)

  const NumberInputScreen({
    super.key,
    required this.lottoTitle,
    required this.lottoKey,
  });

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  String selectedCategory = "สามตัวบน";
  String currentNumber = "";
  List<String> draftBets = []; // รายการเลขที่รอส่งโพย
  bool isListExpanded = false; // สถานะ Sidebar ซ้าย
  bool canPlay4Digits = false; // สถานะเปิด/ปิด เมนู 4 ตัว

  @override
  void initState() {
    super.initState();
    _check4DigitConfig();
  }

  // ✅ ตรวจสอบว่า lottotype นี้อนุญาตให้เล่น 4 ตัวไหม
  Future<void> _check4DigitConfig() async {
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('configs')
          .doc('setnum4')
          .get();

      if (snap.exists) {
        List<dynamic> allowedList = snap.get('lottotype') ?? [];
        setState(() {
          canPlay4Digits = allowedList.contains(widget.lottoKey);
          // ถ้าเล่น 4 ตัวไม่ได้ แต่ค่าเริ่มต้นเป็น 4 ตัว ให้ปรับเป็น 3 ตัว
          if (!canPlay4Digits && selectedCategory == "สี่ตัวบน") {
            selectedCategory = "สามตัวบน";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching setnum4: $e");
    }
  }

  void _onKeyPress(String value) {
    setState(() {
      if (value == "⌫") {
        if (currentNumber.isNotEmpty) {
          currentNumber = currentNumber.substring(0, currentNumber.length - 1);
        }
      } else if (value == "สุ่ม") {
        _generateRandom();
      } else {
        int max = _getMaxLength();
        if (currentNumber.length < max) currentNumber += value;
      }
    });
  }

  int _getMaxLength() {
    if (selectedCategory.contains("สี่")) return 4;
    if (selectedCategory.contains("สาม")) return 3;
    return 2; // สองตัวบน/ล่าง
  }

  void _generateRandom() {
    int max = _getMaxLength();
    Random random = Random();
    String res = "";
    for (int i = 0; i < max; i++) {
      res += random.nextInt(10).toString();
    }
    setState(() => currentNumber = res);
  }

  // ✅ ฟังก์ชันกลับเลข (2, 3, 4 หลัก)
  void _reverseNumber() {
    if (currentNumber.length < 2) return;

    Set<String> results = {};
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
      draftBets.addAll(results.toList());
      currentNumber = ""; // ล้างช่องกรอกหลังจากกลับเลขแล้ว
      isListExpanded = true; // เปิดแถบข้างเพื่อดูผล
    });
  }

  // ✅ ส่งโพยทั้งหมดเข้า Firebase
  Future<void> _submitAllBets() async {
    List<String> finalItems = List.from(draftBets);
    if (currentNumber.isNotEmpty) finalItems.add(currentNumber);

    if (finalItems.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var num in finalItems) {
        DocumentReference ref = FirebaseFirestore.instance
            .collection('bets')
            .doc();
        batch.set(ref, {
          'uid': user?.uid,
          'email': user?.email,
          'lotto_type': widget.lottoTitle,
          'lotto_key': widget.lottoKey,
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
            content: Text("ส่งโพยสำเร็จ!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              isListExpanded
                  ? Icons.keyboard_arrow_left
                  : Icons.format_list_bulleted,
            ),
            onPressed: () => setState(() => isListExpanded = !isListExpanded),
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Sidebar รายการเลข (พับได้)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isListExpanded ? 110 : 0,
            color: const Color(0xFF263238),
            child: _buildSidebar(),
          ),

          // 2. พื้นที่กรอกเลขหลัก
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCategorySelector(),
                        _buildNumberDisplay(),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
                _buildKeypad(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "รายการ",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const Divider(color: Colors.white24),
        Expanded(
          child: ListView.builder(
            itemCount: draftBets.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(
                draftBets[index],
                style: const TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              trailing: InkWell(
                onTap: () => setState(() => draftBets.removeAt(index)),
                child: const Icon(Icons.close, color: Colors.red, size: 16),
              ),
            ),
          ),
        ),
        if (draftBets.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white54),
            onPressed: () => setState(() => draftBets.clear()),
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    List<String> cats = [
      if (canPlay4Digits) "สี่ตัวบน",
      "สามตัวบน",
      "สามตัวโต๊ด",
      "สองตัวบน",
      "สองตัวล่าง",
    ];
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cats.map((name) {
          bool isSel = selectedCategory == name;
          return ChoiceChip(
            label: Text(
              name,
              style: TextStyle(
                color: isSel ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
            selected: isSel,
            selectedColor: const Color(0xFF11998E),
            onSelected: (val) => setState(() {
              selectedCategory = name;
              currentNumber = "";
            }),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumberDisplay() {
    int len = _getMaxLength();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          len,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 55,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF11998E), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                currentNumber.length > i ? currentNumber[i] : "-",
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: currentNumber.length >= 2 ? _reverseNumber : null,
              icon: const Icon(Icons.sync),
              label: const Text("กลับเลข"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF11998E),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (currentNumber.isNotEmpty)
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() {
                  draftBets.add(currentNumber);
                  currentNumber = "";
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: const Text(
                  "เพิ่มเลข",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children:
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "สุ่ม", "0", "⌫"]
                    .map(
                      (k) => ElevatedButton(
                        onPressed: () => _onKeyPress(k),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 15),
          InkWell(
            onTap: _submitAllBets,
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  draftBets.isEmpty
                      ? "ส่งโพย"
                      : "ส่งโพยทั้งหมด (${draftBets.length + (currentNumber.isNotEmpty ? 1 : 0)})",
                  style: const TextStyle(
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
