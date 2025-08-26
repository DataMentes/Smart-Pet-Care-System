// lib/features/auth/presentation/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../widgets/auth_card.dart';
import '../widgets/login_view.dart';
// ✅  التصحيح: استيراد ملف الواجهة الجديدة
import '../widgets/signup_view.dart';
// لم نعد بحاجة لهذا الملف هنا
// import '../widgets/placeholder_view.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AuthCard(
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Signup'),
                ],
                tabViews: [
                  const LoginView(),
                  // ✅  التصحيح: استخدام الواجهة الجديدة
                  const SignupView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
