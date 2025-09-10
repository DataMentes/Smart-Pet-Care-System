// lib/features/history/domain/models/history_data.dart
import '../../presentation/widgets/consumption_chart.dart';

// موديل جديد وبسيط لتخزين بيانات الإحصائيات
class AnalyticsData {
  final int totalConsumedGrams;
  final double averageDailyConsumptionGrams;

  AnalyticsData({
    required this.totalConsumedGrams,
    required this.averageDailyConsumptionGrams,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      totalConsumedGrams: json['total_consumed_grams'] ?? 0,
      averageDailyConsumptionGrams:
          (json['average_daily_consumption_grams'] ?? 0.0).toDouble(),
    );
  }
}

// الموديل الرئيسي الذي يجمع بيانات الشاشة
class HistoryData {
  final AnalyticsData analytics;
  final List<ChartDataPoint> chartPoints;

  HistoryData({required this.analytics, required this.chartPoints});

  factory HistoryData.fromFullReportJson(Map<String, dynamic> json) {
    // معالجة بيانات الإحصائيات
    final analyticsData = AnalyticsData.fromJson(json['analytics'] ?? {});

    // معالجة بيانات الرسم البياني
    final List<dynamic> chartDataRaw = json['chart_data'] ?? [];
    final points = chartDataRaw.asMap().entries.map((entry) {
      return ChartDataPoint(
        x: entry.key.toDouble(),
        y: (entry.value['grams'] ?? 0.0).toDouble(),
      );
    }).toList();

    return HistoryData(analytics: analyticsData, chartPoints: points);
  }
}
