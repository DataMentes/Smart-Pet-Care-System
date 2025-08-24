// lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../domain/pet_device.dart';
import '../widgets/add_device_screen.dart'; // ✅ استيراد الشاشة الجديدة
import '../widgets/device_card.dart';
import '../widgets/device_summary_card.dart'; // ✅ استيراد الويدجت الجديد

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات وهمية مؤقتة (سيتم جلبها من الـ backend لاحقاً)
    final List<PetDevice> devices = [
      PetDevice(name: 'Device 1', foodWeightGrams: 120, waterAmountLiters: 1.5, foodStorageLevel: 0.8, isWaterTankFull: true),
      PetDevice(name: 'Device 2', foodWeightGrams: 80, waterAmountLiters: 0.2, foodStorageLevel: 0.2, isWaterTankFull: false),
    ];
    
    // حساب إجمالي البيانات
    final totalFoodGrams = devices.map((d) => d.foodWeightGrams).fold(0.0, (sum, item) => sum + item);
    final totalWaterLiters = devices.map((d) => d.waterAmountLiters).fold(0.0, (sum, item) => sum + item);
    final totalFoodStorage = devices.map((d) => d.foodStorageLevel).fold(0.0, (sum, item) => sum + item) / devices.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // هنا يتم تنفيذ منطق تسجيل الخروج
              // Navigator.of(context).pushAndRemoveUntil(...) للعودة لشاشة الدخول
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ✅ إضافة ملخص الأجهزة
            DeviceSummaryCard(
              totalFoodGrams: totalFoodGrams,
              totalWaterLiters: totalWaterLiters,
              totalFoodStorage: totalFoodStorage,
            ),
            const SizedBox(height: 24),

            // قائمة الأجهزة
            ...devices.map((device) => DeviceCard(device: device)).toList(),
            const SizedBox(height: 16),

            // زر لإضافة جهاز جديد
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add New Device'),
                onPressed: () {
                  // ✅ الانتقال إلى شاشة إضافة جهاز
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}