// lib/widgets/mini_bar_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MiniBarChart extends StatelessWidget {
  final Map<String, double> expenseData;
  final Map<String, double> incomeData;
  final ColorScheme scheme;
  final TextStyle mono;

  const MiniBarChart({
    super.key,
    required this.expenseData,
    required this.incomeData,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    // Get last 6 months
    final now = DateTime.now();
    final months = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}';
      months.add(key);
    }

    final expVals = months.map((m) => expenseData[m] ?? 0.0).toList();
    final incVals = months.map((m) => incomeData[m] ?? 0.0).toList();

    final maxVal = [
      ...expVals,
      ...incVals,
    ].fold<double>(0, (m, v) => v > m ? v : m);

    if (maxVal == 0) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(color: scheme.secondary, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              minY: 0,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          months[i].substring(5), // MM
                          style: TextStyle(
                            fontFamily: mono.fontFamily,
                            fontSize: 9,
                            color: scheme.secondary,
                          ),
                        ),
                      );
                    },
                    reservedSize: 20,
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              groupsSpace: 6,
              barGroups: months.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  groupVertically: false,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: incVals[e.key],
                      color: scheme.tertiary.withOpacity(0.8),
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: expVals[e.key],
                      color: scheme.error.withOpacity(0.8),
                      width: 8,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: scheme.tertiary, label: 'Income'),
            const SizedBox(width: 16),
            _Legend(color: scheme.error, label: 'Expenses'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
