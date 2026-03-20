import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLottoConfig extends StatelessWidget {
  const AdminLottoConfig({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ตั้งค่าราคาจ่าย & ข้อมูลหวย",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A3D5D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("ยังไม่มีรายการหวย กดปุ่ม + เพื่อเพิ่ม"),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: data['lottolink'] != null && data['lottolink'] != ""
                      ? Image.network(
                          data['lottolink'],
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports_esports,
                            color: Colors.grey,
                          ), // ✅ แก้ไขตรงนี้
                        ),
                  title: Text(
                    data['lottoname'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "3ตัว: x${data['digit3']} | 2ตัว: x${data['digit2']} | โต๊ด(swift): x${data['swift']}",
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.blue),
                  onTap: () =>
                      _showEditDialog(context, docId, data, isNew: false),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF11998E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditDialog(context, "", {}, isNew: true),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data, {
    required bool isNew,
  }) {
    // ข้อมูลทั่วไป
    TextEditingController nameController = TextEditingController(
      text: data['lottoname'] ?? "",
    );
    TextEditingController typeController = TextEditingController(
      text: data['lottotype'] ?? "",
    );
    TextEditingController linkController = TextEditingController(
      text: data['lottolink'] ?? "",
    );

    // ข้อมูลราคาจ่าย (แปลงเป็น String เพื่อใส่ใน TextField)
    TextEditingController d4 = TextEditingController(
      text: (data['digit4'] ?? "8000").toString(),
    );
    TextEditingController d3 = TextEditingController(
      text: (data['digit3'] ?? "920").toString(),
    );
    TextEditingController d2 = TextEditingController(
      text: (data['digit2'] ?? "92").toString(),
    );
    TextEditingController d1 = TextEditingController(
      text: (data['digit1'] ?? "3.2").toString(),
    );
    TextEditingController swiftController = TextEditingController(
      text: (data['swift'] ?? "150").toString(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isNew ? "เพิ่มหวยใหม่" : "แก้ไข: ${data['lottoname']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader("ข้อมูลพื้นฐาน"),
                _buildTextField(
                  "ชื่อหวย",
                  nameController,
                  hint: "เช่น ฮานอยปกติ",
                ),
                _buildTextField(
                  "ประเภท (lottotype)",
                  typeController,
                  hint: "เช่น thai, lao, hanoy",
                ),
                _buildTextField(
                  "ลิงก์รูปภาพ (lottolink)",
                  linkController,
                  hint: "https://...",
                ),

                const SizedBox(height: 10),
                _buildHeader("ราคาจ่ายต่อ 1 บาท"),
                Row(
                  children: [
                    Expanded(child: _buildPriceField("4 ตัวบน", d4)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPriceField("3 ตัวบน", d3)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildPriceField("2 ตัวบน", d2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPriceField("โต๊ด (swift)", swiftController),
                    ), // ✅ เพิ่ม Swift
                  ],
                ),
                _buildPriceField("วิ่งบน", d1),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF11998E),
            ),
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final collection = FirebaseFirestore.instance
                  .collection('configs')
                  .doc('lottogen')
                  .collection('lottogrid');

              Map<String, dynamic> updateData = {
                'lottoname': nameController.text,
                'lottotype': typeController.text,
                'lottolink': linkController.text,
                'digit4': int.tryParse(d4.text) ?? 0,
                'digit3': int.tryParse(d3.text) ?? 0,
                'digit2': int.tryParse(d2.text) ?? 0,
                'digit1': double.tryParse(d1.text) ?? 0.0,
                'swift':
                    int.tryParse(swiftController.text) ?? 0, // ✅ บันทึก Swift
              };

              if (isNew) {
                // หาเลขลำดับถัดไป
                var lastDoc = await collection
                    .orderBy('number', descending: true)
                    .limit(1)
                    .get();
                int nextNumber = lastDoc.docs.isNotEmpty
                    ? (lastDoc.docs.first.get('number') ?? 0) + 1
                    : 1;
                updateData['number'] = nextNumber;
                updateData['lottostatus'] = true;

                await collection.add(updateData);
              } else {
                await collection.doc(docId).update(updateData);
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              "บันทึกข้อมูล",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixText: "x ",
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
