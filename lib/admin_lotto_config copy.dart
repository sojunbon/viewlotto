import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdminLottoConfig extends StatefulWidget {
  const AdminLottoConfig({super.key});

  @override
  State<AdminLottoConfig> createState() => _AdminLottoConfigState();
}

class _AdminLottoConfigState extends State<AdminLottoConfig> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- ฟังก์ชันอัปโหลดรูปภาพ ---
  Future<void> _uploadImage(TextEditingController controller) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      try {
        // แสดง Loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF11998E)),
          ),
        );

        String fileName =
            'lotto_flags/${DateTime.now().millisecondsSinceEpoch}.png';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        UploadTask uploadTask = storageRef.putFile(File(image.path));
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        if (mounted) {
          Navigator.pop(context); // ปิด Loading
          setState(() {
            controller.text = downloadUrl; // ใส่ลิงก์ลงใน Controller ทันที
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("อัปโหลดรูปภาพสำเร็จ")));
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        debugPrint("Upload Error: $e");
      }
    }
  }

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
        stream: _db
            .collection('configs')
            .doc('lottogen')
            .collection('lottogrid')
            .orderBy('number')
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
              final int lottoNumber = data['number'] ?? 0;

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
                    "ID: ${data['lottotype'] ?? '-'} | โต๊ด: x${data['swift'] ?? 0}",
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.blue),
                  onTap: () => _showEditDialog(docId, data, isNew: false),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF11998E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEditDialog("", {}, isNew: true),
      ),
    );
  }

  // --- Dialog สำหรับเพิ่มและแก้ไข ---
  void _showEditDialog(
    String docId,
    Map<String, dynamic> data, {
    required bool isNew,
  }) async {
    int nextNumber = 1;
    if (isNew) {
      var lastDoc = await _db
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

    if (!mounted) return;

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
                        "ลำดับ",
                        numController,
                        isNum: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildTextField("ชื่อหวย", nameController),
                    ),
                  ],
                ),
                _buildTextField(
                  "ประเภท (ID)",
                  typeController,
                  hint: "เช่น thai, lao, hanoy",
                ),

                // ✅ ฟิลด์ Link พร้อมปุ่ม Upload
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: linkController,
                    decoration: InputDecoration(
                      labelText: "ลิงก์รูปธง (lottolink)",
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFF11998E),
                        ),
                        onPressed: () => _uploadImage(linkController),
                      ),
                    ),
                  ),
                ),

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
                'number': int.tryParse(numController.text) ?? nextNumber,
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

              final col = _db
                  .collection('configs')
                  .doc('lottogen')
                  .collection('lottogrid');
              if (isNew) {
                await col.add(finalData);
              } else {
                await col.doc(docId).update(finalData);
              }
              if (mounted) Navigator.pop(context);
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
