// lib/services/ledger_service.dart
// All ledger computations: balances, P&L, dash stats, register, graph data

import '../models/transaction.dart';
import 'parser.dart';

const List<String> kFixedRoots = [
  'assets',
  'liabilities',
  'equity',
  'income',
  'expenses',
];

String fmtNum(double v, {String comm = '', String pos = 'right'}) {
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  // Format with thousands separator
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final formatted = '$intPart.${parts[1]}';
  if (comm.isEmpty) return '$sign$formatted';
  if (pos == 'left') return '$sign$comm$formatted';
  return '$sign$formatted $comm';
}

class AccountBalance {
  final String account;
  final double balance;
  final String comm;

  const AccountBalance(this.account, this.balance, this.comm);
}

class DashStats {
  final double assets;
  final double liabilities;
  final double netWorth;
  final double monthIncome;
  final double monthExpenses;
  final double monthNet;
  final double lastMonthIncome;
  final double lastMonthExpenses;
  final double savingsRate;
  final Map<String, double> topCategories;
  final String dominantComm;
  final String dominantPos;
  final int txnCount;
  final int errorCount;
  final int activeDays;

  const DashStats({
    required this.assets,
    required this.liabilities,
    required this.netWorth,
    required this.monthIncome,
    required this.monthExpenses,
    required this.monthNet,
    required this.lastMonthIncome,
    required this.lastMonthExpenses,
    required this.savingsRate,
    required this.topCategories,
    required this.dominantComm,
    required this.dominantPos,
    required this.txnCount,
    required this.errorCount,
    required this.activeDays,
  });
}

class LedgerEngine {
  final List<Transaction> transactions;
  final ParseResult parseResult;

  LedgerEngine(this.transactions, this.parseResult);

  // ─── ACCOUNTS ─────────────────────────────────────────────────────────────

  List<String> get accounts {
    final all = <String>{};
    for (final t in transactions) {
      for (final p in t.posts) {
        all.add(p.acc);
      }
    }
    all.addAll(parseResult.accounts);
    return all.toList()..sort();
  }

  // ─── BALANCES ─────────────────────────────────────────────────────────────

  Map<String, double> balances({
    String? filter,
    List<String> exclude = const [],
    String? dateBefore,
  }) {
    final bals = <String, double>{};
    for (final t in transactions) {
      if (dateBefore != null && t.date.compareTo(dateBefore) > 0) continue;
      for (final p in t.posts) {
        final acc = p.acc;
        if (filter != null && !acc.toLowerCase().contains(filter.toLowerCase())) {
          continue;
        }
        if (exclude.any((e) => acc.toLowerCase().contains(e.toLowerCase()))) {
          continue;
        }
        bals[acc] = (bals[acc] ?? 0) + p.val;
      }
    }
    return bals;
  }

  /// Hierarchical balance rollup: returns map of account → sum including children
  Map<String, double> rolledBalances({String? filter}) {
    final flat = balances(filter: filter);
    final rolled = <String, double>{};
    for (final entry in flat.entries) {
      final parts = entry.key.split(':');
      for (int i = 1; i <= parts.length; i++) {
        final parent = parts.take(i).join(':');
        rolled[parent] = (rolled[parent] ?? 0) + entry.value;
      }
    }
    return rolled;
  }

  // ─── DASHBOARD STATS ──────────────────────────────────────────────────────

  DashStats dashStats() {
    double assets = 0, liabilities = 0, inc = 0, exp = 0;
    double lastInc = 0, lastExp = 0;
    final cats = <String, double>{};
    final commCount = <String, int>{};

    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastM = DateTime(now.year, now.month - 1, 1);
    final lastYm =
        '${lastM.year}-${lastM.month.toString().padLeft(2, '0')}';
    final activeDates = <String>{};

    for (final t in transactions) {
      final inThis = t.date.startsWith(ym);
      final inLast = t.date.startsWith(lastYm);
      if (inThis) activeDates.add(t.date);

      for (final p in t.posts) {
        if (p.comm.isNotEmpty) {
          commCount[p.comm] = (commCount[p.comm] ?? 0) + 1;
        }
        if (p.acc.startsWith('assets')) assets += p.val;
        if (p.acc.startsWith('liabilities')) liabilities += p.val;
        if (inThis) {
          if (p.acc.startsWith('income')) inc += p.val;
          if (p.acc.startsWith('expenses')) {
            exp += p.val;
            final cat = p.acc.split(':').length > 1 ? p.acc.split(':')[1] : 'misc';
            cats[cat] = (cats[cat] ?? 0) + p.val;
          }
        }
        if (inLast) {
          if (p.acc.startsWith('income')) lastInc += p.val;
          if (p.acc.startsWith('expenses')) lastExp += p.val;
        }
      }
    }

    final netWorth = assets + liabilities;
    final monthNet = inc + exp;
    final absInc = inc.abs();
    final savingsRate =
        absInc > 0.01 ? ((absInc - exp.abs()) / absInc * 100) : 0.0;

    // Dominant commodity
    String domComm = '';
    String domPos = 'right';
    if (commCount.isNotEmpty) {
      domComm = commCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      // Find position from first posting with this commodity
      outer:
      for (final t in transactions) {
        for (final p in t.posts) {
          if (p.comm == domComm) {
            domPos = p.pos.isEmpty ? 'right' : p.pos;
            break outer;
          }
        }
      }
    }

    return DashStats(
      assets: assets,
      liabilities: liabilities,
      netWorth: netWorth,
      monthIncome: inc,
      monthExpenses: exp,
      monthNet: monthNet,
      lastMonthIncome: lastInc,
      lastMonthExpenses: lastExp,
      savingsRate: savingsRate,
      topCategories: cats,
      dominantComm: domComm,
      dominantPos: domPos,
      txnCount: transactions.length,
      errorCount: transactions.where((t) => t.hasError).length,
      activeDays: activeDates.length,
    );
  }

  // ─── GRAPH DATA ───────────────────────────────────────────────────────────

  Map<String, double> graphData({
    required String account,
    String by = 'month',
    bool accumulate = false,
    bool useAbs = true,
    List<Transaction>? subset,
  }) {
    final source = subset ?? transactions;
    final buckets = <String, double>{};

    for (final t in source) {
      String key;
      if (by == 'month') {
        key = t.date.substring(0, 7);
      } else if (by == 'year') {
        key = t.date.substring(0, 4);
      } else {
        key = t.date;
      }

      double val = 0;
      for (final p in t.posts) {
        if (p.acc.toLowerCase().contains(account.toLowerCase())) {
          val += p.val;
        }
      }
      buckets[key] = (buckets[key] ?? 0) + val;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    final result = <String, double>{};
    double running = 0;
    for (final k in sortedKeys) {
      double y = buckets[k]!;
      if (useAbs) y = y.abs();
      if (accumulate) {
        running += y;
        y = running;
      }
      result[k] = (y * 100).round() / 100;
    }
    return result;
  }

  // ─── RECENT ───────────────────────────────────────────────────────────────

  List<Transaction> recent(int n) {
    return List.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date))
      ..take(n).toList();
  }

  // ─── SEARCH / FILTER ──────────────────────────────────────────────────────

  List<Transaction> search(String query) {
    if (query.trim().isEmpty) return transactions;
    final q = query.toLowerCase();
    return transactions.where((t) {
      if (t.desc.toLowerCase().contains(q)) return true;
      if (t.date.contains(q)) return true;
      if (t.posts.any((p) => p.acc.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  // ─── REGISTER ─────────────────────────────────────────────────────────────

  List<_RegisterRow> register(String query) {
    final filtered = search(query)
      ..sort((a, b) => a.date.compareTo(b.date));
    String? accFilter;
    final parts = query.toLowerCase().split(' ');
    for (final part in parts) {
      if (kFixedRoots.any((r) => part.startsWith(r))) {
        accFilter = part;
        break;
      }
    }

    double running = 0;
    final rows = <_RegisterRow>[];
    for (final t in filtered) {
      double txnAmt = 0;
      for (final p in t.posts) {
        if (accFilter == null ||
            p.acc.toLowerCase().contains(accFilter.toLowerCase())) {
          txnAmt += p.val;
        }
      }
      running += txnAmt;
      rows.add(_RegisterRow(txn: t, amount: txnAmt, balance: running));
    }
    return rows;
  }

  // ─── P&L ──────────────────────────────────────────────────────────────────

  PnlResult pnl({String? month}) {
    double income = 0, expenses = 0;
    final incomeByAcc = <String, double>{};
    final expByAcc = <String, double>{};

    for (final t in transactions) {
      if (month != null && !t.date.startsWith(month)) continue;
      for (final p in t.posts) {
        if (p.acc.startsWith('income')) {
          income += p.val;
          incomeByAcc[p.acc] = (incomeByAcc[p.acc] ?? 0) + p.val;
        }
        if (p.acc.startsWith('expenses')) {
          expenses += p.val;
          expByAcc[p.acc] = (expByAcc[p.acc] ?? 0) + p.val;
        }
      }
    }

    return PnlResult(
      income: income,
      expenses: expenses,
      net: income + expenses,
      incomeByAcc: incomeByAcc,
      expensesByAcc: expByAcc,
    );
  }

  // ─── WATERFALL DATA ───────────────────────────────────────────────────────

  List<WaterfallStep> waterfallSteps({String? query}) {
    final pnlData = pnl();
    final steps = <WaterfallStep>[];

    final absInc = pnlData.income.abs();
    steps.add(WaterfallStep(
      label: 'Income',
      value: absInc,
      isPositive: true,
      isNet: false,
    ));

    final sortedExp = pnlData.expensesByAcc.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    for (final e in sortedExp) {
      steps.add(WaterfallStep(
        label: e.key.replaceFirst('expenses:', ''),
        value: e.value.abs(),
        isPositive: false,
        isNet: false,
      ));
    }

    steps.add(WaterfallStep(
      label: 'Net',
      value: pnlData.net,
      isPositive: pnlData.net >= 0,
      isNet: true,
    ));

    return steps;
  }

  // ─── FORECAST ─────────────────────────────────────────────────────────────

  List<ForecastEntry> forecast(int days) {
    final descDates = <String, List<String>>{};
    for (final t in transactions) {
      final key = t.desc.toLowerCase();
      descDates[key] = [...(descDates[key] ?? []), t.date];
    }

    final cutoff = DateTime.now().add(Duration(days: days));
    final results = <ForecastEntry>[];

    for (final entry in descDates.entries) {
      final dates = entry.value..sort();
      if (dates.length < 2) continue;

      final diffs = <int>[];
      for (int i = 1; i < dates.length; i++) {
        final d1 = DateTime.parse(dates[i - 1]);
        final d2 = DateTime.parse(dates[i]);
        diffs.add(d2.difference(d1).inDays);
      }
      final avgDiff =
          diffs.fold<int>(0, (s, d) => s + d) / diffs.length;
      if (avgDiff < 20 || avgDiff > 40) continue;

      final lastDate = DateTime.parse(dates.last);
      final nextDate =
          lastDate.add(Duration(days: avgDiff.round()));
      if (nextDate.isBefore(DateTime.now()) || nextDate.isAfter(cutoff)) {
        continue;
      }

      // Find last transaction's amount
      final lastTxn = transactions.lastWhere(
        (t) => t.desc.toLowerCase() == entry.key,
        orElse: () => transactions.first,
      );
      final amt = lastTxn.posts
          .where((p) => !p.isImplicit)
          .fold<double>(0, (s, p) => s + p.val);

      results.add(ForecastEntry(
        desc: entry.key,
        nextDate: nextDate.toIso8601String().substring(0, 10),
        amount: amt,
        periodDays: avgDiff.round(),
      ));
    }

    results.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return results;
  }
}

class _RegisterRow {
  final Transaction txn;
  final double amount;
  final double balance;
  const _RegisterRow({
    required this.txn,
    required this.amount,
    required this.balance,
  });
}

class PnlResult {
  final double income;
  final double expenses;
  final double net;
  final Map<String, double> incomeByAcc;
  final Map<String, double> expensesByAcc;
  const PnlResult({
    required this.income,
    required this.expenses,
    required this.net,
    required this.incomeByAcc,
    required this.expensesByAcc,
  });
}

class WaterfallStep {
  final String label;
  final double value;
  final bool isPositive;
  final bool isNet;
  const WaterfallStep({
    required this.label,
    required this.value,
    required this.isPositive,
    required this.isNet,
  });
}

class ForecastEntry {
  final String desc;
  final String nextDate;
  final double amount;
  final int periodDays;
  const ForecastEntry({
    required this.desc,
    required this.nextDate,
    required this.amount,
    required this.periodDays,
  });
}
