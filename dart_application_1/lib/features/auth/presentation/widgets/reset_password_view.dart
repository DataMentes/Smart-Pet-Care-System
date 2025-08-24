// lib/features/auth/presentation/widgets/reset_password_view.dart
import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class ResetPasswordView extends StatelessWidget {
  final VoidCallback onResetPressed;

  const ResetPasswordView({super.key, required this.onResetPressed});

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
        const CustomTextField(labelText: 'New Password', isPassword: true),
        const SizedBox(height: 20),
        const CustomTextField(
          labelText: 'Confirm New Password',
          isPassword: true,
        ),
        const SizedBox(height: 40),
        CustomButton(text: 'Reset Password', onPressed: onResetPressed),
      ],
    );
  }
}
