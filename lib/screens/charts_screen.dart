// lib/screens/charts_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../services/ledger_service.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _view = 'monthly';
  String _account = 'expenses';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final engine = provider.engine;
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();
    final stats = engine.dashStats();
    String fmt(double v) =>
        fmtNum(v, comm: stats.dominantComm, pos: stats.dominantPos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View selector
            _ViewChips(
              selected: _view,
              onChanged: (v) => setState(() => _view = v),
              scheme: scheme,
              mono: mono,
            ),
            const SizedBox(height: 16),

            // Account selector for monthly/trend
            if (_view == 'monthly' || _view == 'trend') ...[
              _AccountChips(
                selected: _account,
                onChanged: (v) => setState(() => _account = v),
                scheme: scheme,
                mono: mono,
              ),
              const SizedBox(height: 16),
            ],

            // Chart
            if (_view == 'monthly')
              _MonthlyBarChart(
                engine: engine,
                account: _account,
                scheme: scheme,
                mono: mono,
                fmt: fmt,
              )
            else if (_view == 'pnl')
              _PnlWaterfallChart(
                engine: engine,
                scheme: scheme,
                mono: mono,
                fmt: fmt,
              )
            else if (_view == 'donut')
              _ExpenseDonutChart(
                engine: engine,
                scheme: scheme,
                mono: mono,
                fmt: fmt,
              )
            else if (_view == 'trend')
              _TrendLineChart(
                engine: engine,
                account: _account,
                scheme: scheme,
                mono: mono,
                fmt: fmt,
              )
            else if (_view == 'forecast')
              _ForecastList(
                engine: engine,
                scheme: scheme,
                mono: mono,
                fmt: fmt,
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── View selector ────────────────────────────────────────────────────────────

class _ViewChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextStyle mono;

  const _ViewChips({
    required this.selected,
    required this.onChanged,
    required this.scheme,
    required this.mono,
  });

  static const _options = [
    ('monthly', 'Monthly', Icons.bar_chart),
    ('donut', 'Breakdown', Icons.pie_chart_outline),
    ('trend', 'Trend', Icons.show_chart),
    ('pnl', 'P&L', Icons.waterfall_chart),
    ('forecast', 'Forecast', Icons.upcoming_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _options.map((o) {
          final isSelected = selected == o.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                children: [
                  Icon(o.$3, size: 14,
                      color: isSelected ? scheme.surface : scheme.secondary),
                  const SizedBox(width: 4),
                  Text(o.$2),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(o.$1),
              selectedColor: scheme.primary,
              labelStyle: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 12,
                color: isSelected ? scheme.surface : scheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AccountChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;
  final TextStyle mono;

  const _AccountChips({
    required this.selected,
    required this.onChanged,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    const options = ['expenses', 'income', 'assets', 'liabilities'];
    return Row(
      children: options.map((a) {
        final sel = selected == a;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(a),
            selected: sel,
            onSelected: (_) => onChanged(a),
            labelStyle: TextStyle(
              fontFamily: mono.fontFamily,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Monthly bar chart ────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final LedgerEngine engine;
  final String account;
  final ColorScheme scheme;
  final TextStyle mono;
  final String Function(double) fmt;

  const _MonthlyBarChart({
    required this.engine,
    required this.account,
    required this.scheme,
    required this.mono,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final data = engine.graphData(account: account, by: 'month');
    if (data.isEmpty) {
      return _EmptyChart(message: 'No $account data', scheme: scheme);
    }

    // Last 12 months
    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final last12 = entries.length > 12 ? entries.sublist(entries.length - 12) : entries;
    final maxVal = last12.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final isIncome = account.startsWith('income');
    final barColor = isIncome ? scheme.tertiary : scheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.toUpperCase(),
              style: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.15,
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gIdx, rod, rodIdx) {
                        final label = last12[gIdx].key;
                        return BarTooltipItem(
                          '$label\n${fmt(rod.toY)}',
                          TextStyle(
                            color: barColor,
                            fontFamily: mono.fontFamily,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= last12.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            last12[i].key.substring(5), // MM
                            style: TextStyle(
                              fontFamily: mono.fontFamily,
                              fontSize: 9,
                              color: scheme.secondary,
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (v, meta) {
                          if (v == 0 || v == meta.max) {
                            return Text(
                              _shortNum(v),
                              style: TextStyle(
                                fontFamily: mono.fontFamily,
                                fontSize: 9,
                                color: scheme.secondary,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.secondary.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: last12.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: barColor,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─── Expense donut chart ──────────────────────────────────────────────────────

class _ExpenseDonutChart extends StatelessWidget {
  final LedgerEngine engine;
  final ColorScheme scheme;
  final TextStyle mono;
  final String Function(double) fmt;

  const _ExpenseDonutChart({
    required this.engine,
    required this.scheme,
    required this.mono,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = engine.pnl();
    if (pnl.expensesByAcc.isEmpty) {
      return _EmptyChart(message: 'No expenses', scheme: scheme);
    }

    final sorted = pnl.expensesByAcc.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final total = sorted.fold<double>(0, (s, e) => s + e.value.abs());
    final palette = [
      scheme.error,
      scheme.primary,
      scheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'EXPENSE BREAKDOWN',
              style: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 55,
                  sections: sorted.take(7).toList().asMap().entries.map((e) {
                    final pct = total > 0 ? e.value.value.abs() / total : 0.0;
                    final color = palette[e.key % palette.length];
                    return PieChartSectionData(
                      value: e.value.value.abs(),
                      color: color,
                      title: pct > 0.08
                          ? '${(pct * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: TextStyle(
                        fontFamily: mono.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      radius: 60,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sorted.take(7).toList().asMap().entries.map((e) {
                final color = palette[e.key % palette.length];
                final name = e.value.key.replaceFirst('expenses:', '');
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$name  ${fmt(e.value.value.abs())}',
                      style: TextStyle(
                          fontFamily: mono.fontFamily, fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trend line chart ─────────────────────────────────────────────────────────

class _TrendLineChart extends StatelessWidget {
  final LedgerEngine engine;
  final String account;
  final ColorScheme scheme;
  final TextStyle mono;
  final String Function(double) fmt;

  const _TrendLineChart({
    required this.engine,
    required this.account,
    required this.scheme,
    required this.mono,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final data = engine.graphData(account: account, by: 'month');
    if (data.isEmpty) {
      return _EmptyChart(message: 'No data', scheme: scheme);
    }

    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final lineColor = account.startsWith('income') ? scheme.tertiary : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${account.toUpperCase()} TREND',
              style: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxVal * 1.15,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${entries[s.x.toInt()].key}\n${fmt(s.y)}',
                                TextStyle(
                                  fontFamily: mono.fontFamily,
                                  fontSize: 11,
                                  color: lineColor,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (entries.length / 6).ceilToDouble(),
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            entries[i].key.substring(5),
                            style: TextStyle(
                              fontFamily: mono.fontFamily,
                              fontSize: 9,
                              color: scheme.secondary,
                            ),
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.secondary.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: entries
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.value))
                          .toList(),
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: lineColor,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── P&L waterfall ───────────────────────────────────────────────────────────

class _PnlWaterfallChart extends StatelessWidget {
  final LedgerEngine engine;
  final ColorScheme scheme;
  final TextStyle mono;
  final String Function(double) fmt;

  const _PnlWaterfallChart({
    required this.engine,
    required this.scheme,
    required this.mono,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = engine.pnl();
    final steps = engine.waterfallSteps();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROFIT & LOSS',
              style: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 16),

            // Summary rows
            _PnlRow(
                label: '▲ Total Income',
                value: fmt(pnl.income.abs()),
                color: scheme.tertiary,
                mono: mono),
            const Divider(height: 8),
            ...pnl.expensesByAcc.entries
                .toList()
                .sorted((a, b) => b.value.abs().compareTo(a.value.abs()))
                .take(8)
                .map((e) => _PnlRow(
                      label: '  ↳ ${e.key.replaceFirst('expenses:', '')}',
                      value: '−${fmt(e.value.abs())}',
                      color: scheme.error.withOpacity(0.8),
                      mono: mono,
                      small: true,
                    )),
            const Divider(height: 8),
            _PnlRow(
              label: '▼ Total Expenses',
              value: '−${fmt(pnl.expenses.abs())}',
              color: scheme.error,
              mono: mono,
            ),
            const Divider(height: 8),
            _PnlRow(
              label: 'Net',
              value:
                  '${pnl.net >= 0 ? '+' : ''}${fmt(pnl.net.abs())}',
              color: pnl.net >= 0 ? scheme.tertiary : scheme.error,
              mono: mono,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PnlRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final TextStyle mono;
  final bool bold;
  final bool small;

  const _PnlRow({
    required this.label,
    required this.value,
    required this.color,
    required this.mono,
    this.bold = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 12 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono.fontFamily,
              fontSize: small ? 12 : 14,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forecast list ────────────────────────────────────────────────────────────

class _ForecastList extends StatelessWidget {
  final LedgerEngine engine;
  final ColorScheme scheme;
  final TextStyle mono;
  final String Function(double) fmt;

  const _ForecastList({
    required this.engine,
    required this.scheme,
    required this.mono,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final entries = engine.forecast(30);
    if (entries.isEmpty) {
      return _EmptyChart(
        message: 'No recurring patterns detected in the next 30 days',
        scheme: scheme,
      );
    }

    double projected = entries.fold(0, (s, e) => s + e.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FORECAST — Next 30 days',
              style: TextStyle(
                fontFamily: mono.fontFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
              ),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final color = e.amount < 0 ? scheme.error : scheme.tertiary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      e.nextDate.substring(5), // MM-DD
                      style: TextStyle(
                        fontFamily: mono.fontFamily,
                        fontSize: 12,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.desc,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '~${e.periodDays}d',
                      style: TextStyle(
                          fontSize: 10, color: scheme.secondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fmt(e.amount.abs()),
                      style: TextStyle(
                        fontFamily: mono.fontFamily,
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Projected net',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  fmt(projected.abs()),
                  style: TextStyle(
                    fontFamily: mono.fontFamily,
                    fontWeight: FontWeight.bold,
                    color: projected >= 0 ? scheme.tertiary : scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  final ColorScheme scheme;
  const _EmptyChart({required this.message, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(message,
              style: TextStyle(color: scheme.secondary),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

extension _ListSorted<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) {
    return List<T>.from(this)..sort(compare);
  }
}
