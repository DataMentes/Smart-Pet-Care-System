// lib/features/device_control/presentation/screens/device_control_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/api_service.dart';
import '../../domain/models/feeding_schedule.dart';
import '../widgets/schedule_list_item.dart';

class DeviceControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const DeviceControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final ApiService _apiService = ApiService();
  final _feedNowController = TextEditingController();

  List<FeedingSchedule>? _schedules;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchSchedulesFromServer();
  }

  @override
  void dispose() {
    _feedNowController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedulesFromServer() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _apiService.getSchedules(widget.deviceId);
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load schedules: $e')));
      }
    }
  }

  Future<void> _saveSchedulesToServer() async {
    if (_schedules == null) return;
    setState(() => _isSaving = true);
    try {
      await _apiService.updateDeviceSchedule(widget.deviceId, _schedules!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save schedule: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddEditScheduleDialog({FeedingSchedule? existingSchedule}) {
    final amountController = TextEditingController();
    TimeOfDay? selectedTime = existingSchedule?.time;

    if (existingSchedule != null) {
      amountController.text = existingSchedule.amountGrams.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        // ✅  التصحيح: استخدام StatefulBuilder لإدارة حالة مربع الحوار بشكل آمن
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existingSchedule == null ? 'Add Schedule' : 'Edit Schedule',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(selectedTime?.format(context) ?? 'Select Time'),
                    trailing: const Icon(Icons.timer_outlined),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        // استخدام دالة setDialogState لتحديث واجهة مربع الحوار فقط
                        setDialogState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (grams)',
                    ),
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
                    if (selectedTime != null &&
                        amountController.text.isNotEmpty) {
                      final amount = int.tryParse(amountController.text) ?? 0;
                      setState(() {
                        if (existingSchedule == null) {
                          _schedules?.add(
                            FeedingSchedule(
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
                      _saveSchedulesToServer();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deviceName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFeedNowCard(),
                Padding(
                  padding: const EdgeInsets.all(
                    16.0,
                  ).copyWith(bottom: 0, top: 8),
                  child: Row(
                    children: [
                      Text(
                        'Feeding Schedules',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (_isSaving)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchSchedulesFromServer,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        80,
                      ), // مساحة للـ FAB
                      itemCount: _schedules?.length ?? 0,
                      itemBuilder: (ctx, index) {
                        final schedule = _schedules![index];
                        return ScheduleListItem(
                          schedule: schedule,
                          onEdit: () => _showAddEditScheduleDialog(
                            existingSchedule: schedule,
                          ),
                          onDelete: () {
                            setState(() {
                              _schedules!.removeAt(index);
                            });
                            _saveSchedulesToServer();
                          },
                        );
                      },
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
      margin: const EdgeInsets.all(16),
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
                  onPressed: () async {
                    final amount = int.tryParse(_feedNowController.text);
                    if (amount != null && amount > 0) {
                      try {
                        final response = await _apiService.feedNow(
                          widget.deviceId,
                          amount,
                        );
                        if (response.statusCode == 200 && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Feeding $amount grams now...'),
                            ),
                          );
                          _feedNowController.clear();
                        } else if (mounted) {
                          final error = jsonDecode(response.body)['message'];
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $error')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('An error occurred: $e')),
                          );
                        }
                      }
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
