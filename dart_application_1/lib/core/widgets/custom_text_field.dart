// lib/core/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String labelText;
  final bool isPassword;
  // ✅  التصحيح: إضافة controller كمتغير
  final TextEditingController? controller;

  const CustomTextField({
    super.key,
    required this.labelText,
    this.isPassword = false,
    this.controller, // ✅  التصحيح: إضافته للـ constructor
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, // ✅  التصحيح: استخدامه هنا
      obscureText: isPassword,
      decoration: InputDecoration(labelText: labelText),
    );
  }
}
