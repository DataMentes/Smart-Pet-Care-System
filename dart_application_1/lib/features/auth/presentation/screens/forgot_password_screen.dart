// lib/features/auth/presentation/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../widgets/enter_email_view.dart';
import '../widgets/enter_otp_view.dart';
import '../widgets/reset_password_view.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final PageController _pageController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    // تحديث النص قبل الانتقال لضمان ظهوره في شاشة الـ OTP
    setState(() {});
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              EnterEmailView(
                emailController: _emailController,
                onSendOtpPressed: _goToNextPage,
              ),
              EnterOtpView(
                email: _emailController.text,
                onVerifyPressed: _goToNextPage,
              ),
              ResetPasswordView(
                onResetPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
