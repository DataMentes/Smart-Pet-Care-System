// lib/features/device_control/presentation/widgets/schedule_list_item.dart
import 'package:flutter/material.dart';
import '../../domain/models/feeding_schedule.dart';

class ScheduleListItem extends StatelessWidget {
  final FeedingSchedule schedule;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleListItem({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // لتنسيق الوقت بشكل جميل مثل "09:30 AM"
    final formattedTime = schedule.time.format(context);
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      decoration: schedule.isActive ? null : TextDecoration.lineThrough,
      color: schedule.isActive ? null : Colors.grey,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          Icons.timer_outlined,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          formattedTime,
          style: textStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${schedule.amountGrams} grams', style: textStyle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: schedule.isActive, onChanged: onToggle),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
