// lib/features/device_control/presentation/screens/device_control_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../../domain/models/feeding_schedule.dart';
import '../widgets/schedule_list_item.dart';

class DeviceControlScreen extends StatefulWidget {
  final String deviceName;
  const DeviceControlScreen({super.key, required this.deviceName});

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  // قائمة الجداول الزمنية (بيانات وهمية)
  final List<FeedingSchedule> _schedules = [
    FeedingSchedule(
      id: '1',
      time: const TimeOfDay(hour: 9, minute: 0),
      amountGrams: 150,
    ),
    FeedingSchedule(
      id: '2',
      time: const TimeOfDay(hour: 18, minute: 30),
      amountGrams: 200,
      isActive: false,
    ),
  ];

  final _feedNowController = TextEditingController();

  // دالة لإظهار مربع حوار لإضافة أو تعديل جدول
  void _showAddEditScheduleDialog({FeedingSchedule? existingSchedule}) async {
    final timeController = TextEditingController();
    final amountController = TextEditingController();
    TimeOfDay? selectedTime = existingSchedule?.time;

    if (existingSchedule != null) {
      timeController.text = existingSchedule.time.format(context);
      amountController.text = existingSchedule.amountGrams.toString();
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingSchedule == null ? 'Add Schedule' : 'Edit Schedule',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // حقل الوقت
            TextField(
              controller: timeController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Time',
                suffixIcon: Icon(Icons.timer_outlined),
              ),
              onTap: () async {
                selectedTime = await showTimePicker(
                  context: context,
                  initialTime: selectedTime ?? TimeOfDay.now(),
                );
                if (selectedTime != null) {
                  timeController.text = selectedTime!.format(context);
                }
              },
            ),
            const SizedBox(height: 16),
            // حقل الكمية
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (grams)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedTime != null && amountController.text.isNotEmpty) {
                final amount = int.tryParse(amountController.text) ?? 0;
                setState(() {
                  if (existingSchedule == null) {
                    _schedules.add(
                      FeedingSchedule(
                        id: DateTime.now().toString(), // ID فريد
                        time: selectedTime!,
                        amountGrams: amount,
                      ),
                    );
                  } else {
                    existingSchedule.time = selectedTime!;
                    existingSchedule.amountGrams = amount;
                  }
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceName)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // قسم الإطعام الفوري
          _buildFeedNowCard(),
          const SizedBox(height: 24),
          // قسم الجداول الزمنية
          Text(
            'Feeding Schedules',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_schedules.isEmpty)
            const Center(child: Text('No schedules added yet.'))
          else
            ..._schedules.map(
              (schedule) => ScheduleListItem(
                schedule: schedule,
                onToggle: (isActive) =>
                    setState(() => schedule.isActive = isActive),
                onEdit: () =>
                    _showAddEditScheduleDialog(existingSchedule: schedule),
                onDelete: () => setState(
                  () => _schedules.removeWhere((s) => s.id == schedule.id),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEditScheduleDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFeedNowCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instant Feeding',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feedNowController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (grams)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // منطق الإطعام الفوري
                    final amount = _feedNowController.text;
                    if (amount.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Feeding $amount grams now...')),
                      );
                      _feedNowController.clear();
                    }
                  },
                  icon: const Icon(Icons.fastfood_outlined),
                  label: const Text('Feed'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
