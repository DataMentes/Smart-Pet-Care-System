// lib/features/auth/presentation/widgets/placeholder_view.dart
import 'package:flutter/material.dart';

class PlaceholderView extends StatelessWidget {
  final String text;
  const PlaceholderView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, color: Colors.grey),
      ),
    );
  }
}
