import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class SlipService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> verifySlip(File imageFile) async {
    try {
      // 1. ดึงค่า config จาก Firebase (configs/easyslips)
      DocumentSnapshot config = await _db
          .collection('configs')
          .doc('easyslips')
          .get();

      if (!config.exists) {
        print("Error: ไม่พบการตั้งค่า easyslips ใน Firebase");
        return null;
      }

      final String apiKey = config.get('apikey') ?? "";
      final String apiUrl = config.get('urls') ?? "";

      if (apiKey.isEmpty || apiUrl.isEmpty) {
        print("Error: apikey หรือ urls ว่างเปล่า");
        return null;
      }

      // 2. เตรียมส่งข้อมูลไปที่ API
      var request = http.MultipartRequest("POST", Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $apiKey';

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // 3. ยิง Request และรอรับผล
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        return result['data']; // ส่งข้อมูลสลิปกลับไป
      } else {
        print("API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Exception in SlipService: $e");
      return null;
    }
  }
}
