// lib/services/parser.dart
// Full hledger plaintext parser — ported from Ledgie's JS engine

import '../models/transaction.dart';

class CommodityResult {
  final double val;
  final String comm;
  final String pos; // 'left' | 'right' | ''
  const CommodityResult(this.val, this.comm, this.pos);
}

CommodityResult parseCommodity(String rawAmt) {
  if (rawAmt.isEmpty) return const CommodityResult(0, '', '');

  // Strip balance assertion suffix "1000 TRY = 1000 TRY"
  String rest = rawAmt.replaceFirst(RegExp(r'\s*=\s*[\d.,]+\s*\S*\s*$'), '').trim();

  // Strip @ price annotation
  final atIdx = rest.indexOf(' @ ');
  if (atIdx != -1) rest = rest.substring(0, atIdx).trim();

  // Strip lot price {150 USD}
  rest = rest.replaceFirst(RegExp(r'\s*\{[^}]+\}'), '').trim();

  // European format detection: 1.000,50
  final isEuro = RegExp(r',\d{1,2}$').hasMatch(rest) && rest.contains('.');
  String valStr = rest;
  if (isEuro) {
    valStr = rest.replaceAll('.', '').replaceAll(',', '.');
  } else {
    valStr = rest.replaceAll(',', '');
  }

  // Match: left-symbol ($100) or right-symbol (100 TRY)
  final mLeft = RegExp(r'^([^\d.\-+]+?)(-?[\d.]+)\s*([A-Za-z_][A-Za-z\d_]*)?\s*$').firstMatch(valStr);
  final mRight = RegExp(r'^(-?[\d.]+)\s*([A-Za-z_][A-Za-z\d_]*)\s*$').firstMatch(valStr);
  final mPlain = RegExp(r'^(-?[\d.]+)\s*$').firstMatch(valStr);

  if (mLeft != null) {
    final sym = mLeft.group(1)!.trim();
    final num = double.tryParse(mLeft.group(2)!) ?? 0;
    final r = mLeft.group(3) ?? '';
    return CommodityResult(num, sym.isNotEmpty ? sym : r, sym.isNotEmpty ? 'left' : 'right');
  }
  if (mRight != null) {
    final num = double.tryParse(mRight.group(1)!) ?? 0;
    final sym = mRight.group(2)!;
    return CommodityResult(num, sym, 'right');
  }
  if (mPlain != null) {
    return CommodityResult(double.tryParse(mPlain.group(1)!) ?? 0, '', '');
  }
  return CommodityResult(double.tryParse(valStr) ?? 0, '', '');
}

Map<String, dynamic> parseTags(String? comment) {
  final tags = <String, dynamic>{};
  if (comment == null || comment.isEmpty) return tags;
  final matches = RegExp(
    r'(?:^|\s)(?:#([\w-]+)|([\w][\w-]*):([^\s,;]*)?)',
    unicode: true,
  ).allMatches(comment);
  for (final m in matches) {
    if (m.group(1) != null) {
      tags[m.group(1)!] = true;
    } else if (m.group(2) != null) {
      tags[m.group(2)!] = m.group(3) ?? true;
    }
  }
  return tags;
}

class HledgerParser {
  static ParseResult parse(String source) {
    final transactions = <Transaction>[];
    final assertions = <BalanceAssertion>[];
    final headerLines = <String>[];
    final directiveLines = <String>[];
    final accounts = <String>{};
    final tags = <String>{};
    final aliases = <String, String>{};
    final commodities = <String>{};

    final lines = source.split('\n');
    _TxnBuilder? current;

    void flush() {
      if (current != null) {
        transactions.add(current!.build(transactions.length));
        current = null;
      }
    }

    for (final rawLine in lines) {
      final stripped = rawLine.trimLeft();

      // Pure comment line
      if (stripped.startsWith(';') ||
          stripped.startsWith('#') ||
          stripped.startsWith('%')) {
        if (current == null) headerLines.add(rawLine);
        continue;
      }

      // Inline comment split
      final semiIdx = rawLine.indexOf(';');
      final clean = (semiIdx != -1 ? rawLine.substring(0, semiIdx) : rawLine).trimRight();
      final comment = semiIdx != -1 ? rawLine.substring(semiIdx).trim() : '';

      // Blank line — flush
      if (clean.trim().isEmpty) {
        if (current != null) {
          flush();
        } else {
          headerLines.add(rawLine);
        }
        continue;
      }

      // account directive
      if (RegExp(r'^account\s+').hasMatch(clean)) {
        directiveLines.add(rawLine);
        final name = clean.replaceFirst(RegExp(r'^account\s+'), '').trim();
        if (name.isNotEmpty) accounts.add(name);
        continue;
      }

      // commodity directive
      if (RegExp(r'^commodity\s+').hasMatch(clean)) {
        final comm = clean
            .replaceFirst(RegExp(r'^commodity\s+'), '')
            .trim()
            .split(RegExp(r'\s'))[0];
        if (comm.isNotEmpty) commodities.add(comm);
        directiveLines.add(rawLine);
        continue;
      }

      // Other directives
      if (RegExp(r'^(include|P |D |Y )').hasMatch(clean) ||
          clean.startsWith('apply account') ||
          clean.startsWith('end apply') ||
          clean.startsWith('~')) {
        directiveLines.add(rawLine);
        continue;
      }

      // alias directive
      final aliasM = RegExp(r'^alias\s+(.*?)\s*=\s*(.*)$').firstMatch(clean);
      if (aliasM != null) {
        directiveLines.add(rawLine);
        aliases[aliasM.group(1)!.trim()] = aliasM.group(2)!.trim();
        continue;
      }

      // Balance assertion: DATE balance ACCOUNT AMOUNT
      final balM = RegExp(
              r'^(\d{4}[-/.]\d{2}[-/.]\d{2})\s+balance\s+([\w:"\'()\[\]]+)\s+(.*)')
          .firstMatch(clean);
      if (balM != null) {
        flush();
        final p = parseCommodity(balM.group(3)!);
        assertions.add(BalanceAssertion(
          date: balM.group(1)!,
          acc: balM.group(2)!,
          val: p.val,
          comm: p.comm,
          raw: rawLine,
        ));
        continue;
      }

      // Transaction header: DATE [FLAG] [CODE] DESC
      final dM = RegExp(
        r'^(\d{4}[-/.]\d{2}[-/.]\d{2})(?:=(\d{4}[-/.]\d{2}[-/.]\d{2}))?\s*([!*])?\s*(?:\(([^)]*)\)\s*)?(.*)',
      ).firstMatch(clean);
      if (dM != null) {
        flush();
        current = _TxnBuilder(
          date: dM.group(1)!,
          flag: dM.group(3) ?? '',
          code: dM.group(4),
          desc: dM.group(5)?.trim() ?? '',
          comment: comment.isNotEmpty ? comment : null,
        );
        // Collect tags from header comment
        final headerTags = parseTags(comment);
        for (final k in headerTags.keys) {
          tags.add('tag:$k');
        }
        continue;
      }

      // Posting line (starts with whitespace)
      if (rawLine.startsWith(' ') || rawLine.startsWith('\t')) {
        if (current != null) {
          _parsePosting(clean.trim(), comment, current!, accounts, commodities);
        }
        continue;
      }
    }

    // Flush last transaction
    flush();

    return ParseResult(
      transactions: transactions,
      assertions: assertions,
      headerLines: headerLines,
      directiveLines: directiveLines,
      accounts: accounts,
      tags: tags,
      aliases: aliases,
      commodities: commodities,
    );
  }

  static void _parsePosting(
    String line,
    String comment,
    _TxnBuilder txn,
    Set<String> accounts,
    Set<String> commodities,
  ) {
    if (line.isEmpty) return;

    // Match: ACCOUNT  [  AMOUNT  ]
    // Account name may contain: letters, digits, :, -, _, (, ), [, ]
    final m = RegExp(
      r'^((?:\(|\[)?[\w:"\'\-.()\[\] ]+?)(?:\s{2,}|\t)(.*?)$',
    ).firstMatch(line);

    String accName;
    String rawAmt = '';

    if (m != null) {
      accName = m.group(1)!.trim();
      rawAmt = m.group(2)!.split(';')[0].trim();
    } else {
      // Implicit posting (no amount)
      accName = line.replaceFirst(RegExp(r'\s*;.*$'), '').trim();
    }

    // Resolve alias
    // (alias resolution done in LedgerService after parse)
    accounts.add(accName);

    if (rawAmt.isEmpty) {
      txn.posts.add(_PostBuilder(
        acc: accName,
        rawAmt: '',
        val: 0,
        comm: '',
        pos: '',
        isImplicit: true,
        comment: comment.isNotEmpty ? comment : null,
      ));
    } else {
      final p = parseCommodity(rawAmt);
      if (p.comm.isNotEmpty) commodities.add(p.comm);
      txn.posts.add(_PostBuilder(
        acc: accName,
        rawAmt: rawAmt,
        val: p.val,
        comm: p.comm,
        pos: p.pos,
        isImplicit: false,
        comment: comment.isNotEmpty ? comment : null,
      ));
    }
  }
}

class _PostBuilder {
  final String acc;
  final String rawAmt;
  final double val;
  final String comm;
  final String pos;
  final bool isImplicit;
  final String? comment;
  _PostBuilder({
    required this.acc,
    required this.rawAmt,
    required this.val,
    required this.comm,
    required this.pos,
    required this.isImplicit,
    this.comment,
  });

  Posting toPosting(double resolvedVal) => Posting(
        acc: acc,
        val: resolvedVal,
        rawAmt: rawAmt,
        comm: comm,
        pos: pos,
        isImplicit: isImplicit,
        comment: comment,
      );
}

class _TxnBuilder {
  final String date;
  final String flag;
  final String? code;
  final String desc;
  final String? comment;
  final List<_PostBuilder> posts = [];

  _TxnBuilder({
    required this.date,
    required this.flag,
    this.code,
    required this.desc,
    this.comment,
  });

  Transaction build(int id) {
    // Resolve implicit posting
    final explicit = posts.where((p) => !p.isImplicit).toList();
    final implicit = posts.where((p) => p.isImplicit).toList();

    // Group by commodity for balance
    final sums = <String, double>{};
    for (final p in explicit) {
      final key = p.comm.isEmpty ? '__' : p.comm;
      sums[key] = (sums[key] ?? 0) + p.val;
    }

    String? error;
    final resolvedPosts = <Posting>[];

    for (final p in posts) {
      if (p.isImplicit) {
        // Auto-balance: subtract sum of same commodity
        final key = p.comm.isEmpty ? '__' : p.comm;
        final autoVal = -(sums[key] ?? 0);
        resolvedPosts.add(p.toPosting(autoVal));
      } else {
        resolvedPosts.add(p.toPosting(p.val));
      }
    }

    // Balance check (single commodity)
    if (implicit.isEmpty && explicit.isNotEmpty) {
      for (final entry in sums.entries) {
        if (entry.value.abs() > 0.005) {
          error = 'Not balanced (off by ${entry.value.toStringAsFixed(2)} ${entry.key == '__' ? '' : entry.key})';
          break;
        }
      }
    }

    // Parse tags from header comment
    final txnTags = parseTags(comment);

    return Transaction(
      id: id,
      date: date,
      flag: flag,
      code: code,
      desc: desc,
      comment: comment,
      posts: resolvedPosts,
      tags: txnTags,
      error: error,
    );
  }
}
