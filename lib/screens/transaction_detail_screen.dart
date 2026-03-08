// lib/screens/transaction_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction txn;
  const TransactionDetailScreen({super.key, required this.txn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();

    return Scaffold(
      appBar: AppBar(
        title: Text(txn.desc, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildHledger()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          txn.date,
                          style: TextStyle(
                            fontFamily: mono.fontFamily,
                            fontSize: 16,
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (txn.flag.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: txn.isCleared
                                  ? scheme.tertiary.withOpacity(0.15)
                                  : scheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: txn.isCleared
                                    ? scheme.tertiary
                                    : scheme.primary,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              txn.isCleared ? 'CLEARED' : 'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                color: txn.isCleared
                                    ? scheme.tertiary
                                    : scheme.primary,
                                fontFamily: mono.fontFamily,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      txn.desc,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    if (txn.code != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(${txn.code})',
                        style: TextStyle(
                            fontSize: 12, color: scheme.secondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Postings
            Text(
              'POSTINGS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
                fontFamily: mono.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: txn.posts.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final isLast = i == txn.posts.length - 1;
                  final amtColor = p.val < 0
                      ? scheme.error
                      : p.val > 0
                          ? scheme.tertiary
                          : scheme.secondary;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.acc,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (p.comment != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      p.comment!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.secondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              p.isImplicit
                                  ? '(auto)'
                                  : p.rawAmt.isNotEmpty
                                      ? p.rawAmt
                                      : p.val.toStringAsFixed(2),
                              style: TextStyle(
                                fontFamily: mono.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.isImplicit
                                    ? scheme.secondary
                                    : amtColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(height: 1, color: scheme.surface),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Error if any
            if (txn.hasError) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: scheme.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: scheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txn.error!,
                        style: TextStyle(
                            fontSize: 12, color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Raw hledger source
            const SizedBox(height: 24),
            Text(
              'HLEDGER SOURCE',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
                fontFamily: mono.fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                _buildHledger(),
                style: TextStyle(
                  fontFamily: mono.fontFamily,
                  fontSize: 12,
                  color: const Color(0xFFCBD5E1),
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _buildHledger() {
    final sb = StringBuffer();
    if (txn.flag.isNotEmpty) {
      sb.write('${txn.date} ${txn.flag} ${txn.desc}');
    } else {
      sb.write('${txn.date} ${txn.desc}');
    }
    if (txn.comment != null) sb.write('  ${txn.comment}');
    sb.writeln();
    for (final p in txn.posts) {
      if (p.rawAmt.isNotEmpty) {
        sb.writeln('    ${p.acc}  ${p.rawAmt}');
      } else {
        sb.writeln('    ${p.acc}');
      }
    }
    return sb.toString().trimRight();
  }
}
