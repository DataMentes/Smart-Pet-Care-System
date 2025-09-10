// lib/features/history/presentation/widgets/analytics_card.dart
import 'package:flutter/material.dart';
import '../../domain/models/history_data.dart';

class AnalyticsCard extends StatelessWidget {
  final AnalyticsData analytics;

  const AnalyticsCard({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Consumption Analytics',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildStatRow(
              context,
              icon: Icons.pie_chart_outline_rounded,
              label: 'Total Consumed',
              value: '${analytics.totalConsumedGrams} g',
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              icon: Icons.show_chart_rounded,
              label: 'Average Daily',
              value:
                  '${analytics.averageDailyConsumptionGrams.toStringAsFixed(1)} g / day',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
