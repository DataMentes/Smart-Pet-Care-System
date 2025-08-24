// lib/features/auth/presentation/widgets/login_view.dart
import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../screens/forgot_password_screen.dart';
// ✅  التصحيح: استيراد الشاشة الرئيسية
import '../../../home/presentation/screens/home_screen.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildForm(context),
        const SizedBox(height: 30),
        _buildButtons(context), // تمرير الـ context
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    // ... (الكود هنا لم يتغير)
    return Column(
      children: [
        const CustomTextField(labelText: 'Username or Email'),
        const SizedBox(height: 20),
        const CustomTextField(labelText: 'Password', isPassword: true),
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
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    // استقبال الـ context
    return Column(
      children: [
        CustomButton(
          text: 'Login',
          // ✅  التصحيح: إضافة منطق الانتقال هنا
          onPressed: () {
            // تمامًا مثل شاشة التسجيل، نمسح كل الشاشات السابقة وننتقل للشاشة الرئيسية
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ],
    );
  }
}
