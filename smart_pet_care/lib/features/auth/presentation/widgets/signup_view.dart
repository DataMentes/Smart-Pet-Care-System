// lib/features/auth/presentation/widgets/signup_view.dart
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅  التصحيح: إضافة استيراد Firebase Messaging
import '../../../../core/api_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../home/presentation/screens/home_screen.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _pageController = PageController();
  final _apiService = ApiService();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {});
  }

  @override
  void dispose() {
    _pageController.removeListener(() {});
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response =
          await _apiService.signupRequestOtp(_emailController.text);
      if (response.statusCode == 200 && mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (mounted) {
        final error = jsonDecode(response.body)['error'] ?? 'An error occurred';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyAndSignup() async {
    setState(() => _isLoading = true);
    try {
      // ✅  التصحيح: جلب التوكن الفعلي قبل إرسال الطلب
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final signupData = {
        "email": _emailController.text,
        "password": _passwordController.text,
        "first_name": _firstNameController.text,
        "last_name": _lastNameController.text,
        "otp": _otpController.text,
        "fcm_token": fcmToken ??
            "no_fcm_token_found", // ✅  التصحيح: استخدام التوكن الحقيقي
      };

      final response = await _apiService.signupVerify(signupData);

      if (response.statusCode == 201 && mounted) {
        await _apiService.saveToken(response.body);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else if (mounted) {
        final error = jsonDecode(response.body)['error'] ?? 'An error occurred';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildDetailsPage(), _buildOtpPage()],
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          CustomTextField(
              labelText: 'First Name', controller: _firstNameController),
          const SizedBox(height: 20),
          CustomTextField(
              labelText: 'Last Name', controller: _lastNameController),
          const SizedBox(height: 20),
          CustomTextField(labelText: 'Email', controller: _emailController),
          const SizedBox(height: 20),
          CustomTextField(
              labelText: 'Password',
              isPassword: true,
              controller: _passwordController),
          const SizedBox(height: 30),
          CustomButton(
              text: 'Send Verification Code', onPressed: _handleRequestOtp),
          const SizedBox(height: 20),
          _buildLoginLink(context),
        ],
      ),
    );
  }

  Widget _buildOtpPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const Text('Enter Verification Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('A 6-digit code has been sent to\n${_emailController.text}',
              textAlign: TextAlign.center),
          const SizedBox(height: 30),
          Pinput(length: 6, controller: _otpController),
          const SizedBox(height: 30),
          CustomButton(
              text: 'Verify & Create Account',
              onPressed: _handleVerifyAndSignup),
        ],
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withOpacity(0.7)),
        children: [
          const TextSpan(text: 'Already have an account? '),
          TextSpan(
            text: 'Login',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                DefaultTabController.of(context).animateTo(0);
              },
          ),
        ],
      ),
    );
  }
}
