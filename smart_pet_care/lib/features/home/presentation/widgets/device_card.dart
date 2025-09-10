// lib/features/home/presentation/widgets/device_card.dart
import 'package:flutter/material.dart';
import '../../domain/models/pet_device.dart';
import '../../../device_control/presentation/screens/device_control_screen.dart';
import '../../../history/presentation/screens/history_screen.dart';
import 'status_indicator.dart'; // ✅ التأكد من استيراد هذا الويدجت

class DeviceCard extends StatelessWidget {
  final PetDevice device;
  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.restaurant,
                    color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text('Food in Bowl:',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${device.foodWeightGrams.toStringAsFixed(0)} g',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ✅  التحسين الثاني: استخدام مؤشر الحالة الملون
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusIndicator(
                        label: 'Food Stock', status: device.foodStockStatus),
                    const SizedBox(height: 8),
                    StatusIndicator(
                        label: 'Water Tank', status: device.waterStockStatus),
                  ],
                ),

                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => HistoryScreen(
                              deviceName: device.name, deviceId: device.id),
                        ));
                      },
                      child: const Text('Insights'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => DeviceControlScreen(
                              deviceId: device.id, deviceName: device.name),
                        ));
                      },
                      child: const Text('Control'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
