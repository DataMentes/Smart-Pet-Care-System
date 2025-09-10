// lib/features/home/domain/models/pet_device.dart
import 'package:flutter/material.dart';

class PetDevice {
  final String id;
  final String name;
  final double foodWeightGrams;
  final String foodStockStatus;
  final String waterStockStatus;

  PetDevice({
    required this.id,
    required this.name,
    required this.foodWeightGrams,
    required this.foodStockStatus,
    required this.waterStockStatus,
  });

  factory PetDevice.fromJson(Map<String, dynamic> json) {
    // الخطوة 1: قراءة القائمة "reading" بأمان
    // الخادم يرسل قراءات الحساسات داخل قائمة اسمها "reading"
    final readingsList = json['reading'] as List<dynamic>?;
    Map<String, dynamic>? latestReading;

    // الخطوة 2: استخراج آخر قراءة (وهي القراءة الوحيدة في حالتك)
    if (readingsList != null && readingsList.isNotEmpty) {
      latestReading = readingsList.first as Map<String, dynamic>;
    }

    return PetDevice(
      id: json['device_id'],
      // الخطوة 3: قراءة الاسم من الحقل الصحيح "device_name"
      name: json['device_name'] ?? json['device_id'],

      // الخطوة 4: قراءة بيانات الحساسات من داخل كائن القراءة
      // نستخدم "?" للتعامل بأمان مع الأجهزة الجديدة التي ليس لها قراءات بعد
      foodWeightGrams: (latestReading?['food_weighted'] ?? 0.0).toDouble(),
      foodStockStatus: latestReading?['main_stock'] ?? 'Unknown',
      waterStockStatus: latestReading?['water_level'] ?? 'Unknown',
    );
  }
}
