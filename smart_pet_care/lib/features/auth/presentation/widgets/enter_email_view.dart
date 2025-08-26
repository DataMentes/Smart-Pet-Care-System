// lib/features/auth/presentation/widgets/enter_email_view.dart
import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class EnterEmailView extends StatelessWidget {
  final VoidCallback onSendOtpPressed;
  final TextEditingController emailController;

  const EnterEmailView({
    super.key,
    required this.onSendOtpPressed,
    required this.emailController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forgot Password',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Enter your email and we will send you a 6-digit code to reset your password.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 40),
        CustomButton(text: 'Send OTP', onPressed: onSendOtpPressed),
      ],
    );
  }
}
