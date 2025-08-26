// lib/features/home/presentation/widgets/device_summary_card.dart
import 'package:flutter/material.dart';

class DeviceSummaryCard extends StatelessWidget {
  final double totalFoodGrams;
  final double totalWaterLiters;
  final double totalFoodStorage;

  const DeviceSummaryCard({
    super.key,
    required this.totalFoodGrams,
    required this.totalWaterLiters,
    required this.totalFoodStorage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Devices Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              context,
              icon: Icons.fastfood_rounded,
              label: 'Food in Bowls',
              value: '${totalFoodGrams.toStringAsFixed(0)} g',
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              icon: Icons.local_drink_rounded,
              label: 'Water Available',
              value: '${totalWaterLiters.toStringAsFixed(1)} L',
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              icon: Icons.inventory_2_rounded,
              label: 'Total Food Storage',
              value: '${(totalFoodStorage * 100).toStringAsFixed(0)}%',
              isPercentage: true,
              percentageValue: totalFoodStorage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isPercentage = false,
    double? percentageValue,
  }) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
        if (isPercentage)
          Expanded(
            child: LinearProgressIndicator(
              value: percentageValue,
              backgroundColor: Colors.grey.shade300,
              color: percentageValue! < 0.2 ? Colors.red : Theme.of(context).primaryColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        if (!isPercentage)
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}