// lib/features/auth/presentation/widgets/login_view.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅  التصحيح: استيراد مكتبة الإشعارات
import '../../../../core/api_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../screens/forgot_password_screen.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      final response = await _apiService.login(
        _emailController.text,
        _passwordController.text,
        fcmToken ?? 'no_fcm_token_found',
      );

      if (response.statusCode == 200 && mounted) {
        await _apiService.saveToken(response.body);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else if (mounted) {
        final error =
            jsonDecode(response.body)['error'] ?? 'Invalid credentials';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        CustomTextField(
          labelText: 'Username or Email',
          controller: _emailController,
        ),
        const SizedBox(height: 20),
        CustomTextField(
          labelText: 'Password',
          isPassword: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: Text(
              'Forgot password?',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          CustomButton(text: 'Login', onPressed: _handleLogin),
      ],
    );
  }
}
