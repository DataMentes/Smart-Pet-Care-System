// lib/features/history/presentation/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../widgets/consumption_chart.dart';

class HistoryScreen extends StatefulWidget {
  final String deviceName;
  const HistoryScreen({super.key, required this.deviceName});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _pickDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
    }
  }

  List<ChartDataPoint> _generateMockChartData() {
    final random = Random();
    final int count = switch (_tabController.index) {
      0 => 24,
      1 => 7,
      _ => 12,
    };
    return List.generate(
      count,
      (index) => ChartDataPoint(
        x: index.toDouble(),
        y: (random.nextDouble() * 100) + 50,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mockLogs = {'9:00 AM': '150g', '12:30 PM': '100g', '6:00 PM': '200g'};

    return Scaffold(
      appBar: AppBar(title: Text('${widget.deviceName} History')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDatePicker(),
          const SizedBox(height: 20),

          _buildChartCard(
            title: 'Food Consumption',
            chart: ConsumptionChart(points: _generateMockChartData()),
          ),
          const SizedBox(height: 20),

          // ✅  التصحيح: تم حذف قسم "Stock Trends" بالكامل من هنا
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feeding Times (Logs)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  ...mockLogs.entries.map(
                    (entry) => ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      title: Text(entry.key),
                      trailing: Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download Report (CSV/PDF)'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exporting data... (Not Implemented)'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    // ... (الكود هنا لم يتغير)
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Period',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${_selectedDateRange.start.toLocal().toString().split(' ')[0]} - ${_selectedDateRange.end.toLocal().toString().split(' ')[0]}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: _pickDateRange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    // ... (الكود هنا لم يتغير)
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
              ],
              onTap: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            chart,
          ],
        ),
      ),
    );
  }
}
