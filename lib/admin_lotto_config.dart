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

// หน้าจอสำหรับจัดการข้อมูลหวยและราคาจ่าย
class _AdminLottoConfigState extends State<AdminLottoConfig> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ตัวเลือกวันในสัปดาห์สำหรับ UI
  final List<String> _daysOfWeek = ["จ.", "อ.", "พ.", "พฤ.", "ศ.", "ส.", "อา."];

  Future<void> _uploadImage(TextEditingController controller) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 40,
      );

      if (image == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF11998E)),
        ),
      );

      File file = File(image.path);
      String fileName =
          'lotto_flags/${DateTime.now().millisecondsSinceEpoch}.png';
      Reference storageRef = _storage.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          controller.text = downloadUrl;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("อัปโหลดรูปธงสำเร็จ")));
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context))
          Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
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
              bool isLottoActive = data['lottostatus'] ?? true;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLottoActive
                        ? const Color(0xFF1A3D5D)
                        : Colors.grey,
                    backgroundImage:
                        (data['lottolink'] != null && data['lottolink'] != "")
                        ? NetworkImage(data['lottolink'])
                        : null,
                    child:
                        (data['lottolink'] == null || data['lottolink'] == "")
                        ? Text(
                            data['number'].toString(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(
                    data['lottoname'] ?? 'ไม่ระบุชื่อ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLottoActive ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    "ปิดรับ: ${data['closeTime'] ?? '15:30'} | ล่วงหน้า: ${data['preOpenDays'] ?? 0} วัน",
                  ),
                  trailing: Switch(
                    value: isLottoActive,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      _db
                          .collection('configs')
                          .doc('lottogen')
                          .collection('lottogrid')
                          .doc(docId)
                          .update({'lottostatus': val});
                    },
                  ),
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

  void _showEditDialog(
    String docId,
    Map<String, dynamic> data, {
    required bool isNew,
  }) async {
    int nextNumber = isNew ? 1 : (data['number'] ?? 0);
    if (isNew) {
      var lastDoc = await _db
          .collection('configs')
          .doc('lottogen')
          .collection('lottogrid')
          .orderBy('number', descending: true)
          .limit(1)
          .get();
      if (lastDoc.docs.isNotEmpty)
        nextNumber = (lastDoc.docs.first.get('number') ?? 0) + 1;
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
    TextEditingController openTimeController = TextEditingController(
      text: data['openTime'] ?? "06:00",
    );
    TextEditingController closeTimeController = TextEditingController(
      text: data['closeTime'] ?? "15:30",
    );
    TextEditingController specificDatesController = TextEditingController(
      text: data['specificDates'] ?? "",
    );

    // ✅ เพิ่ม Controller สำหรับวันเปิดล่วงหน้า
    TextEditingController preOpenDaysController = TextEditingController(
      text: (data['preOpenDays'] ?? "0").toString(),
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

    List<int> selectedDays = List<int>.from(
      data['playDays'] ?? [1, 2, 3, 4, 5, 6, 7],
    );
    bool currentStatus = data['lottostatus'] ?? true;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
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

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          "เวลาเปิด",
                          openTimeController,
                          hint: "06:00",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          "เวลาปิด",
                          closeTimeController,
                          hint: "15:30",
                        ),
                      ),
                    ],
                  ),

                  const Divider(),
                  const Text(
                    "วันเปิดรับแทง (เลือกวันในสัปดาห์)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (index) {
                      bool isSel = selectedDays.contains(index + 1);
                      return ChoiceChip(
                        label: Text(
                          _daysOfWeek[index],
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.black,
                            fontSize: 11,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF11998E),
                        onSelected: (val) {
                          setDlgState(() {
                            val
                                ? selectedDays.add(index + 1)
                                : selectedDays.remove(index + 1);
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    "ระบุวันที่เปิด (เช่น 1,16)",
                    specificDatesController,
                    hint: "เว้นว่างไว้หากใช้ จ-อา",
                  ),

                  // ✅ ฟิลด์ใหม่: เปิดรับล่วงหน้า
                  _buildTextField(
                    "เปิดรับล่วงหน้า (กี่วันก่อนหวยออก)",
                    preOpenDaysController,
                    isNum: true,
                    hint: "เช่น 5",
                  ),

                  const Divider(),
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
                        child: _buildPriceField(
                          "โต๊ด (swift)",
                          swiftController,
                        ),
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
                  'openTime': openTimeController.text,
                  'closeTime': closeTimeController.text,
                  'playDays': selectedDays,
                  'specificDates': specificDatesController.text.trim(),
                  // ✅ บันทึกค่าเปิดล่วงหน้า
                  'preOpenDays': int.tryParse(preOpenDaysController.text) ?? 0,
                  'digit4': int.tryParse(d4.text) ?? 0,
                  'digit3': int.tryParse(d3.text) ?? 0,
                  'digit2': int.tryParse(d2.text) ?? 0,
                  'digit1': double.tryParse(d1.text) ?? 0.0,
                  'swift': int.tryParse(swiftController.text) ?? 0,
                  'lottostatus': currentStatus,
                };

                final col = _db
                    .collection('configs')
                    .doc('lottogen')
                    .collection('lottogrid');
                isNew
                    ? await col.add(finalData)
                    : await col.doc(docId).update(finalData);
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                "บันทึก",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
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
