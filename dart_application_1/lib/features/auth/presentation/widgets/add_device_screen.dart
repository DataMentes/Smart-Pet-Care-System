// lib/features/home/presentation/screens/add_device_screen.dart
import 'package:flutter/material.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class AddDeviceScreen extends StatelessWidget {
  const AddDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link a New Device',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter the Device ID and a custom name to add it to your account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            const CustomTextField(labelText: 'Device ID'),
            const SizedBox(height: 20),
            const CustomTextField(labelText: 'Device Name'),
            const SizedBox(height: 40),
            CustomButton(
              text: 'Add Device',
              onPressed: () {
                // هنا يتم تنفيذ منطق إضافة الجهاز الجديد
                // بعد النجاح، يمكن إغلاق هذه الشاشة
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}