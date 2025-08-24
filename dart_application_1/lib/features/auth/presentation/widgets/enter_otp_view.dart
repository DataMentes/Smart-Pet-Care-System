// lib/features/auth/presentation/widgets/enter_otp_view.dart
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/widgets/custom_button.dart';

class EnterOtpView extends StatelessWidget {
  final String email;
  final VoidCallback onVerifyPressed;

  const EnterOtpView({
    super.key,
    required this.email,
    required this.onVerifyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Enter OTP Code',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Enter the 6-digit code sent to\n$email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 40),
        Pinput(
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: Theme.of(context).primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 40),
        CustomButton(text: 'Verify', onPressed: onVerifyPressed),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code?",
              style: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            TextButton(onPressed: () {}, child: const Text('Resend')),
          ],
        ),
      ],
    );
  }
}
