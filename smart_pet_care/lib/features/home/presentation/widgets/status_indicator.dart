// lib/features/home/presentation/widgets/status_indicator.dart
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final String status;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // ✅  التصحيح: تمت إضافة منطق لمعالجة الحالات الثلاث

    // تحديد اللون والنص بناءً على الحالة
    Color color;
    String text;

    switch (status.toLowerCase()) {
      case 'high':
        color = Colors.green;
        text = 'High';
        break;
      case 'low':
        color = Colors.orange;
        text = 'Low';
        break;
      default: // الحالة الافتراضية لأي نص آخر مثل "Unknown"
        color = Colors.grey;
        text = 'Unknown';
        break;
    }

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
