// lib/features/auth/presentation/widgets/reset_password_view.dart
import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class ResetPasswordView extends StatelessWidget {
  final VoidCallback onResetPressed;
  final TextEditingController passwordController; // ✅  التصحيح
  final TextEditingController confirmPasswordController; // ✅  التصحيح

  const ResetPasswordView({
    super.key,
    required this.onResetPressed,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create New Password',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Your new password must be different from the previous one.',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 40),
        CustomTextField(
          labelText: 'New Password',
          isPassword: true,
          controller: passwordController,
        ), // ✅  التصحيح
        const SizedBox(height: 20),
        CustomTextField(
          labelText: 'Confirm New Password',
          isPassword: true,
          controller: confirmPasswordController,
        ), // يمكنك إضافة controller آخر هنا للتحقق
        const SizedBox(height: 40),
        CustomButton(text: 'Reset Password', onPressed: onResetPressed),
      ],
    );
  }
}
