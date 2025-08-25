// lib/features/history/presentation/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
import '../../domain/models/history_data.dart';
import '../widgets/consumption_chart.dart';

class HistoryScreen extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  const HistoryScreen({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  late Future<HistoryData> _historyFuture;

  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_refreshHistory);
    _historyFuture = _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.removeListener(_refreshHistory);
    _tabController.dispose();
    super.dispose();
  }

  Future<HistoryData> _fetchHistory() {
    final periods = ['daily', 'weekly', 'monthly'];
    final selectedPeriod = periods[_tabController.index];
    // ✅  التصحيح: استخدام اسم الدالة الصحيح
    return _apiService.getHistoryFullReport(
      widget.deviceId,
      _selectedDateRange,
      selectedPeriod,
    );
  }

  void _refreshHistory() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _historyFuture = _fetchHistory();
      });
    }
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
      _refreshHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.deviceName} History')),
      body: FutureBuilder<HistoryData>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No history data found.'));
          }

          final historyData = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDatePicker(),
              const SizedBox(height: 20),
              _buildChartCard(
                title: 'Food Consumption',
                chart: ConsumptionChart(points: historyData.consumptionPoints),
              ),
              const SizedBox(height: 20),
              _buildLogsCard(historyData.feedingLogs),
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
          );
        },
      ),
    );
  }

  Widget _buildDatePicker() {
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
            ),
            const SizedBox(height: 20),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildLogsCard(List<FeedingLog> logs) {
    return Card(
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
            if (logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No logs for this period.'),
                ),
              )
            else
              ...logs.map(
                (log) => ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: Text(log.time),
                  trailing: Text(
                    '${log.amountGrams}g',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
