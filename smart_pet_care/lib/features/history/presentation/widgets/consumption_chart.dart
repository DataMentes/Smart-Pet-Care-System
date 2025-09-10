// lib/features/history/presentation/widgets/consumption_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ChartDataPoint {
  final double x;
  final double y;
  ChartDataPoint({required this.x, required this.y});

  // ✅  التصحيح: التأكد من أن الـ fromJson يقرأ "grams"
  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      x: (json['x'] ?? 0.0).toDouble(), // سنفترض أننا نستخدم index للـ x
      y: (json['grams'] ?? 0.0).toDouble(),
    );
  }
}

class ConsumptionChart extends StatelessWidget {
  final List<ChartDataPoint> points;
  final Color lineColor;

  const ConsumptionChart({
    super.key,
    required this.points,
    this.lineColor = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) =>
                  Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(0)} grams',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          minX: 0,
          maxX: points.isNotEmpty
              ? points.length.toDouble() - 1
              : 1, // تجنب الخطأ لو كانت القائمة فارغة
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: points.map((point) => FlSpot(point.x, point.y)).toList(),
              isCurved: true,
              color: lineColor,
              barWidth: 4,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
