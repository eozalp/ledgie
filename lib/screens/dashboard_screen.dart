// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../services/ledger_service.dart';
import '../models/transaction.dart';
import '../widgets/stat_card.dart';
import '../widgets/mini_bar_chart.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final engine = provider.engine;
    final stats = engine.dashStats();
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    String fmt(double v) => fmtNum(
          v,
          comm: stats.dominantComm,
          pos: stats.dominantPos,
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ledgie'),
            Text(
              provider.currentLedger.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: scheme.primary,
                fontFamily: mono.fontFamily,
              ),
            ),
          ],
        ),
        actions: [
          if (provider.isMounted)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: const Text('MOUNTED'),
                labelStyle: TextStyle(
                  fontSize: 10,
                  color: scheme.primary,
                  fontFamily: mono.fontFamily,
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: scheme.primary.withOpacity(0.1),
                side: BorderSide(color: scheme.primary, width: 0.5),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            ),
            tooltip: 'Add transaction',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => provider.init(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Net Worth card ──────────────────────────────────────────
              _NetWorthCard(
                netWorth: stats.netWorth,
                assets: stats.assets,
                liabilities: stats.liabilities,
                fmt: fmt,
                scheme: scheme,
                mono: mono,
              ),
              const SizedBox(height: 16),

              // ── This month headline ─────────────────────────────────────
              Text(
                monthLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: scheme.secondary,
                  fontFamily: mono.fontFamily,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Income',
                      value: fmt(stats.monthIncome.abs()),
                      color: scheme.tertiary,
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Expenses',
                      value: fmt(stats.monthExpenses.abs()),
                      color: scheme.error,
                      icon: Icons.trending_down,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Net',
                      value: fmt(stats.monthNet.abs()),
                      color: stats.monthNet >= 0 ? scheme.tertiary : scheme.error,
                      icon: stats.monthNet >= 0
                          ? Icons.savings_outlined
                          : Icons.warning_amber_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Savings Rate',
                      value: '${stats.savingsRate.toStringAsFixed(1)}%',
                      color: stats.savingsRate >= 20
                          ? scheme.tertiary
                          : scheme.secondary,
                      icon: Icons.percent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Top categories ──────────────────────────────────────────
              if (stats.topCategories.isNotEmpty) ...[
                Text(
                  'TOP SPENDING',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: scheme.secondary,
                    fontFamily: mono.fontFamily,
                  ),
                ),
                const SizedBox(height: 8),
                _TopCategoriesCard(
                  categories: stats.topCategories,
                  totalExp: stats.monthExpenses,
                  fmt: fmt,
                  scheme: scheme,
                  mono: mono,
                ),
                const SizedBox(height: 16),
              ],

              // ── 6-month expense chart ───────────────────────────────────
              _MonthlyChart(engine: engine, scheme: scheme, mono: mono),
              const SizedBox(height: 16),

              // ── Recent transactions ─────────────────────────────────────
              Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: scheme.secondary,
                  fontFamily: mono.fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              _RecentList(
                transactions: provider.transactions
                    .take(provider.transactions.length)
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date)),
                fmt: fmt,
                scheme: scheme,
              ),

              // Bottom padding for FAB
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New transaction'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.surface,
      ),
    );
  }
}

// ── Net Worth ────────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final double netWorth, assets, liabilities;
  final String Function(double) fmt;
  final ColorScheme scheme;
  final TextStyle mono;

  const _NetWorthCard({
    required this.netWorth,
    required this.assets,
    required this.liabilities,
    required this.fmt,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.15),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET WORTH',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: scheme.secondary,
              fontFamily: mono.fontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fmt(netWorth),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: netWorth >= 0 ? scheme.primary : scheme.error,
              fontFamily: mono.fontFamily,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _NetRow(
                label: 'Assets',
                value: fmt(assets),
                color: scheme.tertiary,
                mono: mono,
              ),
              const SizedBox(width: 24),
              _NetRow(
                label: 'Liabilities',
                value: fmt(liabilities.abs()),
                color: scheme.error,
                mono: mono,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final TextStyle mono;
  const _NetRow({
    required this.label,
    required this.value,
    required this.color,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color.withOpacity(0.7), fontFamily: mono.fontFamily)),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: mono.fontFamily)),
      ],
    );
  }
}

// ── Top categories ───────────────────────────────────────────────────────────

class _TopCategoriesCard extends StatelessWidget {
  final Map<String, double> categories;
  final double totalExp;
  final String Function(double) fmt;
  final ColorScheme scheme;
  final TextStyle mono;

  const _TopCategoriesCard({
    required this.categories,
    required this.totalExp,
    required this.fmt,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: top.map((e) {
            final pct = totalExp.abs() > 0.01
                ? (e.value.abs() / totalExp.abs()).clamp(0.0, 1.0)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        fmt(e.value.abs()),
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: mono.fontFamily,
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: scheme.error.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                          scheme.error.withOpacity(0.7)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Monthly chart ─────────────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final LedgerEngine engine;
  final ColorScheme scheme;
  final TextStyle mono;

  const _MonthlyChart({
    required this.engine,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final expData = engine.graphData(account: 'expenses', by: 'month');
    final incData = engine.graphData(account: 'income', by: 'month', useAbs: true);

    if (expData.isEmpty && incData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '6-MONTH OVERVIEW',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: scheme.secondary,
            fontFamily: mono.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MiniBarChart(
              expenseData: expData,
              incomeData: incData,
              scheme: scheme,
              mono: mono,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Recent list ───────────────────────────────────────────────────────────────

class _RecentList extends StatelessWidget {
  final List<Transaction> transactions;
  final String Function(double) fmt;
  final ColorScheme scheme;

  const _RecentList({
    required this.transactions,
    required this.fmt,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(10).toList();
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No transactions yet.\nTap + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.secondary),
          ),
        ),
      );
    }

    return Column(
      children: recent.map((t) {
        final isExp = t.isExpense;
        final isInc = t.isIncome;
        final color = isExp
            ? scheme.error
            : isInc
                ? scheme.tertiary
                : scheme.secondary;
        final sign = isExp ? '−' : isInc ? '+' : '';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 18,
            child: Icon(
              isInc
                  ? Icons.arrow_downward
                  : isExp
                      ? Icons.arrow_upward
                      : Icons.swap_horiz,
              size: 16,
              color: color,
            ),
          ),
          title: Text(
            t.desc,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${t.date}  ·  ${t.posts.map((p) => p.acc.split(':').last).take(2).join(' → ')}',
            style: TextStyle(fontSize: 11, color: scheme.secondary),
          ),
          trailing: Text(
            '$sign${fmt(t.displayAmount)}',
            style: TextStyle(
              fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
