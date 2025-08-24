// lib/features/auth/presentation/widgets/signup_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
// ✅  التصحيح: استيراد الشاشة الرئيسية
import '../../../home/presentation/screens/home_screen.dart';

class SignupView extends StatelessWidget {
  const SignupView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildForm(),
          const SizedBox(height: 20),
          _buildButtons(context), // تمرير الـ context
          const SizedBox(height: 20),
          _buildLoginLink(context),
        ],
      ),
    );
  }

  Widget _buildForm() {
    // ... (الكود هنا لم يتغير)
    return const Column(
      children: [
        CustomTextField(labelText: 'First Name'),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Last Name'),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Email'),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Device ID'),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Device Name'),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Password', isPassword: true),
        SizedBox(height: 20),
        CustomTextField(labelText: 'Confirm Password', isPassword: true),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    // استقبال الـ context
    return CustomButton(
      text: 'Signup',
      // ✅  التصحيح: إضافة منطق الانتقال هنا
      onPressed: () {
        // في التطبيق الحقيقي، هنا تضع كود التحقق من البيانات وإرسالها للـ Backend
        // وبعد التأكد من نجاح التسجيل، تنفذ أمر الانتقال التالي:

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) =>
              false, // هذا السطر يمسح كل الشاشات السابقة (المصادقة)
        );
      },
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    // ... (الكود هنا لم يتغير)
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
        children: [
          const TextSpan(text: 'Already have an account? '),
          TextSpan(
            text: 'Login',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
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
