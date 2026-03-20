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
            .orderBy('number') // ✅ เรียงตามลำดับเลขที่ตั้งไว้
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text("ยังไม่มีรายการหวย"));

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final int lottoNumber = data['number'] ?? 0; // ✅ แสดงเลขลำดับ

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1A3D5D),
                    child: Text(
                      lottoNumber.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  title: Text(
                    data['lottoname'] ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "ID: ${data['lottotype'] ?? '-'} | 3ตัว: x${data['digit3']}",
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
  }) async {
    // --- Logic Auto Run Number ---
    int nextNumber = 1;
    if (isNew) {
      // ดึงข้อมูลตัวสุดท้ายเพื่อหาเลขลำดับล่าสุด
      var lastDoc = await FirebaseFirestore.instance
          .collection('configs')
          .doc('lottogen')
          .collection('lottogrid')
          .orderBy('number', descending: true)
          .limit(1)
          .get();

      if (lastDoc.docs.isNotEmpty) {
        nextNumber = (lastDoc.docs.first.get('number') ?? 0) + 1;
      }
    } else {
      nextNumber = data['number'] ?? 0;
    }

    // เตรียม Controller
    TextEditingController numController = TextEditingController(
      text: nextNumber.toString(),
    );
    TextEditingController nameController = TextEditingController(
      text: data['lottoname'] ?? "",
    );
    TextEditingController typeController = TextEditingController(
      text: data['lottotype'] ?? "",
    );
    TextEditingController linkController = TextEditingController(
      text: data['lottolink'] ?? "",
    );
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

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isNew ? "เพิ่มหวยใหม่" : "แก้ไขข้อมูล"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "ลำดับ (Auto)",
                        numController,
                        isNum: true,
                      ),
                    ), // ✅ ฟิลด์ number
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildTextField("ชื่อหวย", nameController),
                    ),
                  ],
                ),
                _buildTextField(
                  "ประเภท (lottotype)",
                  typeController,
                  hint: "เช่น thai, lao",
                ),
                _buildTextField("ลิงก์รูปภาพ", linkController),
                const Divider(),
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
                    ),
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

              Map<String, dynamic> finalData = {
                'number':
                    int.tryParse(numController.text) ??
                    nextNumber, // ✅ บันทึก number
                'lottoname': nameController.text,
                'lottotype': typeController.text,
                'lottolink': linkController.text,
                'digit4': int.tryParse(d4.text) ?? 0,
                'digit3': int.tryParse(d3.text) ?? 0,
                'digit2': int.tryParse(d2.text) ?? 0,
                'digit1': double.tryParse(d1.text) ?? 0.0,
                'swift': int.tryParse(swiftController.text) ?? 0,
                'lottostatus': data['lottostatus'] ?? true,
              };

              final collection = FirebaseFirestore.instance
                  .collection('configs')
                  .doc('lottogen')
                  .collection('lottogrid');

              if (isNew) {
                await collection.add(finalData);
              } else {
                await collection.doc(docId).update(finalData);
              }
              Navigator.pop(ctx);
            },
            child: const Text("บันทึก", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isNum = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
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
