import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ เพิ่มตัวนี้
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ เพิ่มตัวนี้เพื่อจัดการ format ตัวเลข
import 'dart:math';
import 'price_input_screen.dart';

// หน้าจอสำหรับเลือกประเภทการแทงและใส่ตัวเลข โดยดึงข้อมูลการตั้งค่าจาก Firestore แบบ Real-time
// ✅ Theme Colors
const Color kMainGreen = Color(0xFF11998E);
const Color kLightGreen = Color(0xFF38EF7D);
const Color kDeepBlue = Color(0xFF1A3D5D);

class NumberInputScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? lottoList;

  const NumberInputScreen({super.key, this.lottoList});

  @override
  State<NumberInputScreen> createState() => _NumberInputScreenState();
}

class _NumberInputScreenState extends State<NumberInputScreen> {
  Set<String> selectedCategories = {"สามตัวบน"};
  String currentNumber = "";
  List<Map<String, String>> draftBets = [];
  bool canPlay4Digits = false;
  bool isReverseMode = false;

  String get lottoTitle =>
      (widget.lottoList != null && widget.lottoList!.isNotEmpty)
      ? widget.lottoList!.first['lottoname'] ?? "แทงหวย"
      : "แทงหวย";

  String get lottoKey =>
      (widget.lottoList != null && widget.lottoList!.isNotEmpty)
      ? widget.lottoList!.first['lottotype'] ?? "thai"
      : "thai";

  @override
  void initState() {
    super.initState();
    _check4DigitConfig();
  }

  // ✅ ฟังก์ชันสร้าง Badge แสดงเครดิตคงเหลือ (Real-time)
  Widget _buildCreditBadge() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        double credit = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          credit = (snapshot.data!.get('credit') ?? 0).toDouble();
        }

        return Container(
          margin: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black26, // พื้นหลังโปร่งแสงเล็กน้อย
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

  Future<void> _check4DigitConfig() async {
    try {
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection('configs')
          .doc('setnum4')
          .get();
      if (snap.exists) {
        List<dynamic> allowedList = snap.get('lottotype') ?? [];
        setState(() => canPlay4Digits = allowedList.contains(lottoKey));
      }
    } catch (e) {
      debugPrint("Config Error: $e");
    }
  }

  void _onCategoryTap(String name) {
    setState(() {
      if (selectedCategories.contains(name)) {
        if (selectedCategories.length > 1) {
          selectedCategories.remove(name);
        }
      } else {
        selectedCategories.add(name);
      }
      currentNumber = "";
    });
  }

  Map<String, List<Map<String, dynamic>>> _getGroupedBets() {
    Map<String, List<Map<String, dynamic>>> groups = {};
    for (int i = 0; i < draftBets.length; i++) {
      String cat = draftBets[i]['cat']!;
      if (!groups.containsKey(cat)) groups[cat] = [];
      groups[cat]!.add({'index': i, 'num': draftBets[i]['num']});
    }
    return groups;
  }

  void _onKeyPress(String value) {
    setState(() {
      if (value == "del") {
        if (currentNumber.isNotEmpty) {
          currentNumber = currentNumber.substring(0, currentNumber.length - 1);
        }
      } else if (value == "สุ่ม") {
        _generateRandom();
      } else {
        int max = _getMaxLength();
        if (currentNumber.length < max) {
          currentNumber += value;
          if (currentNumber.length == max) {
            for (var cat in selectedCategories) {
              if (isReverseMode && currentNumber.length >= 2) {
                _processReverseAndAddForCat(cat);
              } else {
                draftBets.insert(0, {"num": currentNumber, "cat": cat});
              }
            }
            currentNumber = "";
          }
        }
      }
    });
  }

  void _processReverseAndAddForCat(String cat) {
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
      draftBets.insert(0, {"num": n, "cat": cat});
    }
  }

  int _getMaxLength() {
    if (selectedCategories.any((c) => c.contains("สี่"))) return 4;
    if (selectedCategories.any((c) => c.contains("สาม"))) return 3;
    return 2;
  }

  void _generateRandom() {
    int max = _getMaxLength();
    String res = "";
    for (int i = 0; i < max; i++) {
      res += Random().nextInt(10).toString();
    }
    setState(() {
      currentNumber = res;
      for (var cat in selectedCategories) {
        if (isReverseMode) {
          _processReverseAndAddForCat(cat);
        } else {
          draftBets.insert(0, {"num": currentNumber, "cat": cat});
        }
      }
      currentNumber = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          lottoTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kMainGreen,
        centerTitle:
            false, // ✅ ปรับเป็น false เพื่อให้ Credit Badge มีพื้นที่ด้านขวา
        toolbarHeight: 45,
        iconTheme: const IconThemeData(color: Colors.white, size: 18),
        actions: [
          _buildCreditBadge(), // ✅ เพิ่มยอดเงินที่นี่
        ],
      ),
      body: Column(
        children: [
          _buildCategoryGridStream(),
          _buildTopActions(),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildNumberDisplay(),
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

  Widget _buildCategoryGridStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configs')
          .doc('lottogen')
          .collection('lottogrid')
          .where('lottotype', isEqualTo: lottoKey)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = {
          'digit4': '8000',
          'digit3': '920',
          'swift': '120',
          'digit2': '92',
          'digit1': '3.2',
        };
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        }

        List<Map<String, String>> categories = [
          if (canPlay4Digits)
            {"name": "สี่ตัวบน", "pay": "x${data['digit4'] ?? 8000}"},
          {"name": "สามตัวบน", "pay": "x${data['digit3'] ?? 920}"},
          {"name": "สามตัวโต๊ด", "pay": "x${data['swift'] ?? 120}"},
          {"name": "สองตัวบน", "pay": "x${data['digit2'] ?? 92}"},
          {"name": "สองตัวล่าง", "pay": "x${data['digit2'] ?? 92}"},
          {"name": "วิ่งบน", "pay": "x${data['digit1'] ?? 3.2}"},
          {"name": "วิ่งล่าง", "pay": "x${data['digit1'] ?? 4.2}"},
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: categories.map((cat) {
              bool isSelected = selectedCategories.contains(cat['name']);
              return InkWell(
                onTap: () => _onCategoryTap(cat['name']!),
                child: Container(
                  width: (MediaQuery.of(context).size.width / 2) - 8,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? kMainGreen : Colors.black12,
                      width: 1.5,
                    ),
                    color: isSelected
                        ? kMainGreen.withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat['name']!,
                        style: TextStyle(
                          color: isSelected ? kMainGreen : Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: kMainGreen,
                        ),
                      if (!isSelected)
                        Text(
                          cat['pay']!,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => isReverseMode = !isReverseMode),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isReverseMode ? kMainGreen : Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync, color: Colors.white, size: 14),
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
          if (draftBets.isNotEmpty)
            InkWell(
              onTap: () => setState(() => draftBets.clear()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.redAccent.withOpacity(0.8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "ลบทั้งหมด",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
        onTap: () {
          if (draftBets.isEmpty) return;
          List<Map<String, String>> finalBets = draftBets.map((bet) {
            return {
              "num": bet["num"]!,
              "cat": bet["cat"]!,
              "lottoKey": lottoKey,
              "lottoTitle": lottoTitle,
            };
          }).toList();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PriceInputScreen(draftBets: finalBets),
            ),
          );
        },
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
