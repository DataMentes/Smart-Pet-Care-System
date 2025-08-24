// lib/features/device_control/domain/models/feeding_schedule.dart
import 'package:flutter/material.dart';

class FeedingSchedule {
  String id; // معرّف فريد لكل جدول
  TimeOfDay time; // لتخزين الساعة والدقيقة
  int amountGrams; // الكمية بالجرام
  bool isActive; // لتفعيل أو تعليق الجدول

  FeedingSchedule({
    required this.id,
    required this.time,
    required this.amountGrams,
    this.isActive = true,
  });
}
