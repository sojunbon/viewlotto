import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ✅ Import หน้าจอของคุณให้ครบถ้วน
import 'login_page.dart';
import 'home_wrapper.dart';
import 'admin_dashboard.dart';
import 'admin_user_management.dart';
import 'admin_lotto_config.dart';
import 'admin_4digit_config.dart';
import 'deposit_screen.dart';
import 'wallet_screen.dart';
import 'admin_set_result_screen.dart';
import 'admin_transaction_screen.dart';

void main() async {
  // 1. ตรวจสอบให้แน่ใจว่า Flutter Binding พร้อมใช้งานก่อนเริ่ม Firebase
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      // ✅ สำหรับ WEB: ระบุค่า Options เสมอ
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
      // ✅ สำหรับ ANDROID: พยายามโหลดจาก google-services.json
      try {
        await Firebase.initializeApp();
      } catch (e) {
        // ⚠️ กรณีระบบ Auto-detect มีปัญหา ให้ใช้ค่า Manual ของ Android แทน
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyDsGoK7L3CoSei0Jqs1oz0TczuqGnOjsQY",
            appId: "1:987472618400:android:5c06deff209dc626673ac5",
            messagingSenderId: "987472618400",
            projectId: "viewlotto-3736a",
            storageBucket: "viewlotto-3736a.firebasestorage.app",
          ),
        );
      }
    }
    debugPrint("Firebase Initialized Successfully");
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
        fontFamily: 'Kanit',
      ),
      // ✅ กำหนด Routes หลักเพื่อความสะดวกในการจัดการ Stack
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomeWrapper(),
        '/admin': (context) => const AdminDashboard(),
        '/user_management': (context) => const AdminUserManagement(),
        '/lotto_config': (context) => const AdminLottoConfig(),
        '/admin_4digit_config': (context) => const Admin4DigitConfig(),
        '/wallet': (context) => const WalletScreen(),
        '/deposit': (context) => const DepositScreen(),
        '/adminresult': (context) =>
            const AdminSetResultScreen(), // ✅ เพิ่ม Route สำหรับตั้งค่าผลหวย เช็คผลหวย Admin
        '/admintransactions': (context) => const AdminTransactionScreen(),
      },
      home: const AuthGate(),
    );
  }
}

// --- ส่วนที่ใช้ตรวจสอบสถานะ และแยกสิทธิ์ Admin/User ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. ดักฟังสถานะ Login/Logout ตลอดเวลา
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ระหว่างรอผลการเชื่อมต่อ
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF11998E)),
            ),
          );
        }

        // 2. ถ้ามีการ Login อยู่ (รวมถึงตอนสมัคร User ใหม่สำเร็จ)
        if (snapshot.hasData && snapshot.data != null) {
          // ✅ เช็ค Role จาก Firestore เพื่อเลือกหน้าจอที่ถูกต้อง
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF11998E)),
                  ),
                );
              }

              // ถ้าดึงข้อมูล User จาก Firestore สำเร็จ
              if (userSnap.hasData && userSnap.data!.exists) {
                String role = userSnap.data!.get('role') ?? 'user';

                if (role == 'admin') {
                  return const AdminDashboard(); // ไปหน้า Admin
                }
              }

              // ถ้าไม่มี Role หรือเป็น user ปกติ ไปหน้าแทงหวย
              return const HomeWrapper();
            },
          );
        }

        // 3. ถ้าไม่ได้ Login หรือเพิ่งกด SignOut ให้ไปหน้า Login ทันที
        return const LoginPage();
      },
    );
  }
}
