// lib/features/history/domain/models/history_data.dart
import '../../presentation/widgets/consumption_chart.dart';

class FeedingLog {
  final String time;
  final int amountGrams;

  FeedingLog({required this.time, required this.amountGrams});

  factory FeedingLog.fromJson(Map<String, dynamic> json) {
    return FeedingLog(
      time: json['time'], // تأكد من أن الـ Backend يرسل هذا الحقل
      amountGrams: (json['amountGrams'] ?? 0).toInt(),
    );
  }
}

class HistoryData {
  final List<ChartDataPoint> consumptionPoints;
  final List<FeedingLog> feedingLogs;

  HistoryData({required this.consumptionPoints, required this.feedingLogs});

  // ✅ التصحيح: إضافة الدالة الجديدة هنا
  factory HistoryData.fromFullReportJson(Map<String, dynamic> json) {
    // معالجة بيانات الرسم البياني
    final List<dynamic> chartDataRaw = json['chart_data'] ?? [];
    final points = chartDataRaw.asMap().entries.map((entry) {
      int index = entry.key;
      var item = entry.value;
      return ChartDataPoint(
        x: index.toDouble(),
        y: (item['food_weighted'] ?? 0.0).toDouble(),
      );
    }).toList();

    // حاليًا الـ Backend لا يرسل سجلات نصية، سنتركها قائمة فارغة
    final logs = <FeedingLog>[];

    return HistoryData(consumptionPoints: points, feedingLogs: logs);
  }
}
