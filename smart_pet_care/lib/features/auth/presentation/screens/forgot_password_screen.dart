// lib/features/auth/presentation/screens/forgot_password_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
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
  late final TextEditingController _otpController;
  late final TextEditingController _passwordController;
  // ✅  التصحيح: إضافة Controller جديد لحقل تأكيد كلمة المرور
  late final TextEditingController _confirmPasswordController;

  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _emailController = TextEditingController();
    _otpController = TextEditingController();
    _passwordController = TextEditingController();
    // ✅  التصحيح: تهيئة الـ Controller الجديد
    _confirmPasswordController = TextEditingController();

    _pageController.addListener(() {});
  }

  @override
  void dispose() {
    _pageController.removeListener(() {});
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    // ✅  التصحيح: التأكد من تنظيف الـ Controller الجديد
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRequestOtp() async {
    // ... (هذه الدالة لم تتغير)
  }

  Future<void> _handleVerifyOtp() async {
    // ... (هذه الدالة لم تتغير)
  }

  Future<void> _handleResetPassword() async {
    // ✅  التصحيح: إضافة تحقق من تطابق كلمتي المرور قبل إرسال الطلب
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return; // إيقاف العملية إذا لم تتطابق
    }

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.passwordResetConfirm(
        _emailController.text,
        _otpController.text,
        _passwordController.text,
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password reset successfully! Please log in.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (mounted) {
        final error = jsonDecode(response.body)['message'];
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onBackground),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  EnterEmailView(
                    emailController: _emailController,
                    onSendOtpPressed: _handleRequestOtp,
                  ),
                  EnterOtpView(
                    email: _emailController.text,
                    otpController: _otpController,
                    onVerifyPressed: _handleVerifyOtp,
                  ),
                  // ✅  التصحيح: تمرير الـ Controller الجديد إلى الويدجت
                  ResetPasswordView(
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    onResetPressed: _handleResetPassword,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
