// lib/screens/accounts_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/ledger_provider.dart';
import '../services/ledger_service.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _tabs = [
    'All',
    'Assets',
    'Liabilities',
    'Income',
    'Expenses',
  ];

  static const _roots = [
    '',
    'assets',
    'liabilities',
    'income',
    'expenses',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final engine = provider.engine;
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();
    final stats = engine.dashStats();

    String fmt(double v) => fmtNum(
          v,
          comm: stats.dominantComm,
          pos: stats.dominantPos,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: _tabs
              .map((t) => Tab(text: t, height: 36))
              .toList(),
          labelStyle: TextStyle(
            fontFamily: mono.fontFamily,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Filter accounts…',
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
          const SizedBox(height: 8),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _roots.map((root) {
                final rolled = engine.rolledBalances(
                    filter: root.isEmpty ? null : root);

                var entries = rolled.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));

                // Filter by root
                if (root.isNotEmpty) {
                  entries = entries
                      .where((e) =>
                          e.key.startsWith(root) ||
                          e.key == root)
                      .toList();
                }

                // Filter by search
                if (_query.isNotEmpty) {
                  entries = entries
                      .where((e) => e.key
                          .toLowerCase()
                          .contains(_query.toLowerCase()))
                      .toList();
                }

                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'No accounts',
                      style: TextStyle(color: scheme.secondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: entries.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (ctx, i) {
                    final acc = entries[i].key;
                    final bal = entries[i].value;
                    final depth = ':'.allMatches(acc).length;

                    // Detect type for color
                    final isAsset = acc.startsWith('assets');
                    final isLiab = acc.startsWith('liabilities');
                    final isInc = acc.startsWith('income');
                    final isExp = acc.startsWith('expenses');

                    Color balColor = scheme.secondary;
                    if (isAsset) {
                      balColor = bal >= 0 ? scheme.tertiary : scheme.error;
                    } else if (isLiab) {
                      balColor = bal <= 0 ? scheme.tertiary : scheme.error;
                    } else if (isInc) {
                      balColor = scheme.tertiary;
                    } else if (isExp) {
                      balColor = scheme.error;
                    }

                    final parts = acc.split(':');
                    final name = parts.last;
                    final isParent = entries
                        .skip(i + 1)
                        .any((e) => e.key.startsWith('$acc:'));

                    return Card(
                      margin: EdgeInsets.only(
                        left: (depth * 12).toDouble(),
                        bottom: 4,
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          _iconFor(acc),
                          size: 16,
                          color: balColor.withOpacity(0.7),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isParent
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: depth > 0
                            ? Text(
                                acc,
                                style: TextStyle(
                                    fontSize: 10, color: scheme.secondary),
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          fmt(bal),
                          style: TextStyle(
                            fontFamily: mono.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: balColor,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () => _addAccountDialog(context, provider),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _iconFor(String acc) {
    if (acc.startsWith('assets:bank')) return Icons.account_balance;
    if (acc.startsWith('assets:cash')) return Icons.money;
    if (acc.startsWith('assets')) return Icons.savings;
    if (acc.startsWith('liabilities:creditcard')) return Icons.credit_card;
    if (acc.startsWith('liabilities')) return Icons.warning_amber_outlined;
    if (acc.startsWith('income')) return Icons.trending_up;
    if (acc.startsWith('expenses:food')) return Icons.restaurant;
    if (acc.startsWith('expenses:transport')) return Icons.directions_car;
    if (acc.startsWith('expenses')) return Icons.shopping_bag_outlined;
    if (acc.startsWith('equity')) return Icons.balance;
    return Icons.folder_outlined;
  }

  Future<void> _addAccountDialog(
      BuildContext context, LedgerProvider provider) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add account'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'expenses:category',
            labelText: 'Account name',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await provider.addAccount(ctrl.text.trim());
    }
  }
}
