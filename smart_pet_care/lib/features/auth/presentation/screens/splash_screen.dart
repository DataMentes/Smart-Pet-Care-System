// lib/features/auth/presentation/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/api_service.dart';
import '../../../../firebase_options.dart';
import 'auth_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    // 1. إعداد خدمات Firebase الأساسية
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. طلب إذن الإشعارات والحصول على التوكن (يمكن دمجه هنا)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final fcmToken = await messaging.getToken();
    print('FCM Token: $fcmToken');

    // --- تم تعطيل منطق التحقق من تسجيل الدخول مؤقتًا ---
    final apiService = ApiService();
    final sessionToken = await apiService.getToken();
    // ---------------------------------------------------

    // 4. اتخاذ قرار الانتقال بناءً على وجود التوكن
    if (mounted) {
      // --- تم تعطيل الشرط مؤقتًا ---
      if (sessionToken != null) {
        // -----------------------------

        // ✅  التعديل: الانتقال مباشرة إلى الشاشة الرئيسية دائمًا
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );

        // --- تم تعطيل الجزء الخاص بشاشة تسجيل الدخول مؤقتًا ---
      } else {
        // إذا لم يوجد توكن، انتقل لشاشة تسجيل الدخول
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
      // ---------------------------------------------------------
    }
  }

  @override
  Widget build(BuildContext context) {
    // عرض شاشة تحميل أثناء عملية التحقق
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
