// lib/features/home/presentation/widgets/device_card.dart
import 'package:flutter/material.dart';

import '../domain/pet_device.dart';
import 'status_indicator.dart';

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
            // اسم الجهاز
            Text(device.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // وزن الأكل وكمية الماء
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoRow(
                  context,
                  icon: Icons.restaurant,
                  label: 'Food',
                  value: '${device.foodWeightGrams.toStringAsFixed(0)} g',
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.local_drink,
                  label: 'Water',
                  value: '${device.waterAmountLiters.toStringAsFixed(1)} L',
                ),
              ],
            ),
            const Divider(height: 24),

            // مستوى مخزون الأكل
            _buildStockIndicator(context),
            const Divider(height: 24),

            // حالة التانكات والأزرار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // حالة تانك المياه
                StatusIndicator(label: 'Water Tank', isFull: device.isWaterTankFull),
                // أزرار التحكم
                Row(
                  children: [
                    TextButton(onPressed: () {}, child: const Text('History')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: () {}, child: const Text('Control')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _buildStockIndicator(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Food Stock Level:'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: device.foodStorageLevel,
          backgroundColor: Colors.grey.shade300,
          color: device.foodStorageLevel < 0.2 ? Colors.red : Theme.of(context).primaryColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}