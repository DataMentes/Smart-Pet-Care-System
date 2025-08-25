// lib/features/device_control/domain/models/feeding_schedule.dart
import 'package:flutter/material.dart';

class FeedingSchedule {
  TimeOfDay time;
  int amountGrams;

  FeedingSchedule({required this.time, required this.amountGrams});

  factory FeedingSchedule.fromJson(Map<String, dynamic> json) {
    final timeParts = json['feed_time'].split(':');
    return FeedingSchedule(
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      amountGrams: json['amount_grams'],
    );
  }

  // دالة لتحويل الكائن إلى JSON لإرساله للخادم
  Map<String, dynamic> toJson() {
    return {
      'time':
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'amount': amountGrams,
    };
  }
}
