// lib/screens/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/ledger_provider.dart';
import '../services/ledger_service.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final engine = provider.engine;
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();

    final txns = _query.isEmpty
        ? (List.from(provider.transactions)
          ..sort((a, b) => b.date.compareTo(a.date)))
        : (engine.search(_query)
          ..sort((a, b) => b.date.compareTo(a.date)));

    // Dominant comm
    final stats = engine.dashStats();
    String fmt(double v) => fmtNum(v, comm: stats.dominantComm, pos: stats.dominantPos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
            ),
          ),
        ],
      ),
      body: txns.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 56, color: scheme.secondary),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty ? 'No transactions' : 'No results',
                    style: TextStyle(color: scheme.secondary),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Count banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: scheme.surfaceContainerHighest.withOpacity(0.4),
                  child: Row(
                    children: [
                      Text(
                        '${txns.length} transaction${txns.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.secondary,
                          fontFamily: mono.fontFamily,
                        ),
                      ),
                      const Spacer(),
                      if (_query.isNotEmpty)
                        Text(
                          'Filter: $_query',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.primary,
                            fontFamily: mono.fontFamily,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: txns.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: scheme.surface),
                    itemBuilder: (context, i) {
                      final t = txns[i];
                      return _TxnTile(
                        txn: t,
                        fmt: fmt,
                        scheme: scheme,
                        mono: mono,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(txn: t),
                          ),
                        ),
                        onDelete: () => _confirmDelete(context, provider, t),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, LedgerProvider provider, Transaction t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('${t.date} — ${t.desc}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteTransaction(t.id);
  }
}

class _TxnTile extends StatelessWidget {
  final Transaction txn;
  final String Function(double) fmt;
  final ColorScheme scheme;
  final TextStyle mono;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TxnTile({
    required this.txn,
    required this.fmt,
    required this.scheme,
    required this.mono,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExp = txn.isExpense;
    final isInc = txn.isIncome;
    final amtColor =
        isExp ? scheme.error : isInc ? scheme.tertiary : scheme.secondary;
    final sign = isExp ? '−' : isInc ? '+' : '';

    // Left border color
    final borderColor =
        isExp ? scheme.error : isInc ? scheme.tertiary : scheme.secondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            SizedBox(
              width: 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.date.substring(5), // MM-DD
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: mono.fontFamily,
                      color: scheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    txn.date.substring(0, 4), // YYYY
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: mono.fontFamily,
                      color: scheme.secondary.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Desc & accounts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (txn.flag.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            txn.flag,
                            style: TextStyle(
                                color: scheme.primary, fontSize: 12),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          txn.desc,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    txn.posts
                        .map((p) => p.acc.split(':').last)
                        .take(3)
                        .join(' · '),
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.secondary.withOpacity(0.7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Amount + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${fmt(txn.displayAmount)}',
                  style: TextStyle(
                    fontFamily: mono.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: amtColor,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline,
                      size: 16, color: scheme.secondary.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
