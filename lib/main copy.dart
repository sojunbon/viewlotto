import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import ไฟล์หน้าจอของคุณ (ตรวจสอบชื่อไฟล์ให้ตรงกับที่คุณสร้าง)
import 'login_page.dart';
import 'home_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // การตั้งค่า Firebase สำหรับโปรเจกต์ viewlotto
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
        // ตั้งค่า Theme สีเขียว Green Liquid ตามที่คุณต้องการ
        primaryColor: const Color(0xFF11998E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF11998E),
          primary: const Color(0xFF11998E),
          secondary: const Color(0xFF38EF7D),
        ),
        useMaterial3: true,
        fontFamily: 'Kanit', // หากมีฟอนต์ภาษาไทย
      ),
      // ส่วนที่ใช้เช็คว่า Login ค้างไว้หรือไม่
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // หากกำลังตรวจสอบสถานะ ให้ขึ้น Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF11998E)),
            ),
          );
        }

        // หากมีข้อมูล User (Login แล้ว) ไปหน้า Home
        if (snapshot.hasData) {
          return const HomeWrapper();
        }

        // หากไม่มีข้อมูล User ไปหน้า Login
        return const LoginPage();
      },
    );
  }
}
