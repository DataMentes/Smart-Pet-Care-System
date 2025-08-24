// lib/features/home/presentation/widgets/status_indicator.dart
// ✅  التصحيح: تم إصلاح الخطأ المطبعي هنا
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final bool isFull;

  const StatusIndicator({super.key, required this.label, required this.isFull});

  @override
  Widget build(BuildContext context) {
    final Color color = isFull ? Colors.green : Colors.orange;
    final String text = isFull ? 'Full' : 'Low';

    return Row(
      children: [
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
