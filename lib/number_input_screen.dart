import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';

// ✅ Theme Green Liquid
const Color kMainGreen = Color(0xFF11998E);
const Color kLightGreen = Color(0xFF38EF7D);
const Color kDeepBlue = Color(0xFF1A3D5D);

class NumberInputScreen extends StatefulWidget {
  final String lottoTitle;
  final String lottoKey;

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
  List<Map<String, String>> draftBets = [];
  bool canPlay4Digits = false;

  // ✅ 2. ตัวแปรสำหรับสถานะปุ่มกลับเลข (Toggle)
  bool isReverseMode = false;

  @override
  void initState() {
    super.initState();
    _check4DigitConfig();
  }

  Future<void> _check4DigitConfig() async {
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('configs')
          .doc('setnum4')
          .get();
      if (snap.exists) {
        List<dynamic> allowedList = snap.get('lottotype') ?? [];
        setState(() => canPlay4Digits = allowedList.contains(widget.lottoKey));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ✅ 4. ฟังก์ชันจัดการการพิมพ์เลขและส่งไปรายการด้านซ้าย
  void _onKeyPress(String value) {
    setState(() {
      if (value == "del") {
        if (currentNumber.isNotEmpty)
          currentNumber = currentNumber.substring(0, currentNumber.length - 1);
      } else if (value == "สุ่ม") {
        _generateRandom();
      } else {
        int max = _getMaxLength();
        if (currentNumber.length < max) {
          currentNumber += value;

          // เมื่อกรอกครบหลักตาม Step 4
          if (currentNumber.length == max) {
            if (isReverseMode && currentNumber.length >= 2) {
              _processReverseAndAdd();
            } else {
              _addSingleBet(currentNumber);
            }
            currentNumber = ""; // ล้างช่องกรอกเพื่อรอเลขถัดไป
          }
        }
      }
    });
  }

  void _addSingleBet(String num) {
    draftBets.insert(0, {"num": num, "cat": selectedCategory});
  }

  // ฟังก์ชันคำนวณการกลับเลข
  void _processReverseAndAdd() {
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
    for (var n in results) {
      _addSingleBet(n);
    }
  }

  int _getMaxLength() => selectedCategory.contains("สี่")
      ? 4
      : (selectedCategory.contains("สาม") ? 3 : 2);

  void _generateRandom() {
    int max = _getMaxLength();
    String res = "";
    for (int i = 0; i < max; i++) {
      res += Random().nextInt(10).toString();
    }
    setState(() {
      currentNumber = res;
      if (isReverseMode)
        _processReverseAndAdd();
      else
        _addSingleBet(currentNumber);
      currentNumber = "";
    });
  }

  // ✅ จัดกลุ่มข้อมูลสำหรับ Sidebar
  Map<String, List<Map<String, dynamic>>> _getGroupedBets() {
    Map<String, List<Map<String, dynamic>>> groups = {};
    for (int i = 0; i < draftBets.length; i++) {
      String cat = draftBets[i]['cat']!;
      if (!groups.containsKey(cat)) groups[cat] = [];
      groups[cat]!.add({'index': i, 'num': draftBets[i]['num']});
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.lottoTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kMainGreen,
        centerTitle: true,
        toolbarHeight: 40,
        iconTheme: const IconThemeData(color: Colors.white, size: 18),
      ),
      body: Column(
        children: [
          _buildCategoryGrid(), // Step 1
          _buildTopActions(), // Step 2
          Expanded(
            child: Row(
              children: [
                _buildSidebar(), // รายการที่จัดกลุ่มแล้ว
                Expanded(
                  child: Column(
                    children: [
                      _buildNumberDisplay(), // Step 3
                      Expanded(child: _buildKeypad()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    List<Map<String, String>> categories = [
      if (canPlay4Digits) {"name": "สี่ตัวบน", "pay": "x8000"},
      {"name": "สามตัวบน", "pay": "x920"},
      {"name": "สามตัวโต๊ด", "pay": "x120"},
      {"name": "สองตัวบน", "pay": "x92"},
      {"name": "สองตัวล่าง", "pay": "x92"},
      {"name": "วิ่งบน", "pay": "x3.2"},
      {"name": "วิ่งล่าง", "pay": "x4.2"},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: categories.map((cat) {
          bool isSelected = selectedCategory == cat['name'];
          return InkWell(
            onTap: () => setState(() {
              selectedCategory = cat['name']!;
              currentNumber = "";
            }),
            child: Container(
              width: (MediaQuery.of(context).size.width / 2) - 8,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? kMainGreen : Colors.black12,
                ),
                color: isSelected ? kMainGreen.withOpacity(0.08) : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cat['name']!,
                    style: TextStyle(
                      color: isSelected ? kMainGreen : Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    cat['pay']!,
                    style: TextStyle(
                      color: isSelected ? kMainGreen : Colors.black45,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // ✅ Step 2: ปุ่มกลับเลขแบบ Toggle
          Expanded(
            child: InkWell(
              onTap: () => setState(() => isReverseMode = !isReverseMode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isReverseMode ? kMainGreen : Colors.black,
                  borderRadius: BorderRadius.circular(4),
                  border: isReverseMode
                      ? Border.all(color: kLightGreen, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sync,
                      color: isReverseMode ? Colors.white : Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReverseMode ? "โหมดกลับเลข: เปิด" : "กลับเลข",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _actionBtn("สุ่ม", Icons.shuffle, _generateRandom),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    var grouped = _getGroupedBets();
    return Container(
      width: 105,
      color: kDeepBlue,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black38,
            child: const Center(
              child: Text(
                "รายการแทง",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white12,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: kLightGreen,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white10,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['num'],
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(
                                () => draftBets.removeAt(item['index']),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white38,
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberDisplay() {
    int max = _getMaxLength();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          max,
          (i) => Container(
            width: 32,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                currentNumber.length > i ? currentNumber[i] : "-",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    List<String> keys = [
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
      "del",
    ];
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        String k = keys[index];
        bool isSpecial = k == "สุ่ม" || k == "del";
        return InkWell(
          onTap: () => _onKeyPress(k),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.black12),
              color: isSpecial ? kDeepBlue.withOpacity(0.05) : Colors.white,
            ),
            child: Center(
              child: k == "del"
                  ? const Icon(Icons.backspace_outlined, size: 16)
                  : Text(
                      k,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSpecial ? kDeepBlue : Colors.black87,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: InkWell(
        onTap: () {},
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kMainGreen, kLightGreen]),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              "ใส่ราคา (${draftBets.length} รายการ)",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
