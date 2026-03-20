import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Admin4DigitConfig extends StatelessWidget {
  const Admin4DigitConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "จัดการหวย 4 หลัก (Array)",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // 1. ดึงข้อมูล Array จาก configs/setnum4
        stream: FirebaseFirestore.instance
            .collection('configs')
            .doc('setnum4')
            .snapshots(),
        builder: (context, configSnap) {
          if (configSnap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          // ดึงรายการ Array ปัจจุบัน (ถ้าไม่มีให้เป็น List ว่าง)
          List<String> enabledLottos = [];
          if (configSnap.hasData && configSnap.data!.exists) {
            enabledLottos = List<String>.from(
              configSnap.data!.get('lottotype') ?? [],
            );
          }

          return StreamBuilder<QuerySnapshot>(
            // 2. ดึงรายชื่อหวยทั้งหมดจาก lottogrid มาแสดงเป็นตัวเลือก
            stream: FirebaseFirestore.instance
                .collection('configs')
                .doc('lottogen')
                .collection('lottogrid')
                .orderBy('number')
                .snapshots(),
            builder: (context, listSnap) {
              if (!listSnap.hasData)
                return const Center(child: CircularProgressIndicator());

              final docs = listSnap.data!.docs;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.orange.withOpacity(0.1),
                    child: const Text(
                      "ติ๊กถูกหน้าชื่อหวยที่ต้องการให้ 'แทง 4 ตัวได้' ระบบจะบันทึกลง Array อัตโนมัติ",
                      style: TextStyle(fontSize: 13, color: Colors.green),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String lottotype =
                            data['lottotype'] ??
                            ""; // ใช้ id เช่น 'thai', 'lao'
                        final String lottoname =
                            data['lottoname'] ?? "ไม่ระบุชื่อ";

                        bool isSelected = enabledLottos.contains(lottotype);

                        return CheckboxListTile(
                          secondary: const Icon(
                            Icons.filter_4,
                            color: Colors.blue,
                          ),
                          title: Text(
                            lottoname,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Type ID: $lottotype"),
                          value: isSelected,
                          activeColor: const Color(0xFF11998E),
                          onChanged: (bool? value) async {
                            // ✅ อัปเดตข้อมูลใน Array
                            if (value == true) {
                              // เพิ่มเข้า Array
                              await FirebaseFirestore.instance
                                  .collection('configs')
                                  .doc('setnum4')
                                  .set({
                                    'lottotype': FieldValue.arrayUnion([
                                      lottotype,
                                    ]),
                                  }, SetOptions(merge: true));
                            } else {
                              // ลบออกจาก Array
                              await FirebaseFirestore.instance
                                  .collection('configs')
                                  .doc('setnum4')
                                  .update({
                                    'lottotype': FieldValue.arrayRemove([
                                      lottotype,
                                    ]),
                                  });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
