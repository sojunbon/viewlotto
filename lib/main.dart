import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import หน้าจอของคุณ
import 'login_page.dart';
import 'home_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      // ✅ สำหรับ WEB: ต้องระบุค่า Options เสมอ
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyC98JVx_eZbnQYOyuzQmI_rDjhP7RCpvoA",
          authDomain: "viewlotto-3736a.firebaseapp.com",
          projectId: "viewlotto-3736a",
          storageBucket: "viewlotto-3736a.firebasestorage.app",
          messagingSenderId: "987472618400",
          appId: "1:987472618400:web:ca930cde524b2478673ac5",
          measurementId: "G-RE45H60QEF",
        ),
      );
    } else {
      // ✅ สำหรับ ANDROID: พยายามโหลดจาก google-services.json ก่อน
      // หากตั้งค่า Gradle ถูกต้องตามที่คุณส่งมา ตัวนี้จะทำงานได้ทันที
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // ⚠️ กรณีระบบ Auto-detect มีปัญหา ให้ใช้ค่า Manual ของ Android แทน
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey:
                "AIzaSyDsGoK7L3CoSei0Jqs1oz0TczuqGnOjsQY", // API Key Android
            appId:
                "1:987472618400:android:5c06deff209dc626673ac5", // App ID Android
            messagingSenderId: "987472618400",
            projectId: "viewlotto-3736a",
            storageBucket: "viewlotto-3736a.firebasestorage.app",
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'View Lotto',
      theme: ThemeData(
        primaryColor: const Color(0xFF11998E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF11998E),
          primary: const Color(0xFF11998E),
          secondary: const Color(0xFF38EF7D),
        ),
        useMaterial3: true,
        fontFamily: 'Kanit', // อย่าลืมใส่ font ใน pubspec.yaml
      ),
      home: const AuthGate(),
    );
  }
}

// --- ส่วนที่ใช้ตรวจสอบว่า User ล็อกอินค้างไว้หรือไม่ ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. ระหว่างรอผลการเชื่อมต่อจาก Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              //child: CircularProgressIndicator(color: Color(0xFF11998E)),
              child: Text("Firebase connect."),
            ),
          );
        }

        // 2. ถ้ามีการ Login อยู่แล้ว ให้ไปหน้า Home
        if (snapshot.hasData) {
          return const HomeWrapper();
        }

        // 3. ถ้ายังไม่ได้ Login หรือ Logout ออกไปแล้ว ให้ไปหน้า Login
        return const LoginPage();
      },
    );
  }
}
