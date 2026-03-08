// lib/models/transaction.dart
// Core data model — mirrors Ledgie's JS parser output

class Posting {
  final String acc;
  final double val;
  final String rawAmt;
  final String comm;
  final String pos; // 'left' | 'right' | ''
  final bool isImplicit;
  final String? comment;

  const Posting({
    required this.acc,
    required this.val,
    this.rawAmt = '',
    this.comm = '',
    this.pos = '',
    this.isImplicit = false,
    this.comment,
  });
}

class Transaction {
  final int id;
  final String date;
  final String desc;
  final String flag; // '' | '*' | '!'
  final String? code;
  final String? comment;
  final List<Posting> posts;
  final Map<String, dynamic> tags;
  final String? error;

  const Transaction({
    required this.id,
    required this.date,
    required this.desc,
    this.flag = '',
    this.code,
    this.comment,
    required this.posts,
    this.tags = const {},
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;

  /// Net amount for display (largest absolute posting)
  double get displayAmount {
    if (posts.isEmpty) return 0;
    return posts.map((p) => p.val.abs()).reduce((a, b) => a > b ? a : b);
  }

  /// Dominant commodity
  String get commodity {
    for (final p in posts) {
      if (p.comm.isNotEmpty) return p.comm;
    }
    return '';
  }

  bool get isExpense => posts.any((p) => p.acc.startsWith('expenses') && p.val > 0);
  bool get isIncome => posts.any((p) => p.acc.startsWith('income') && p.val < 0);
  bool get isCleared => flag == '*';
  bool get isPending => flag == '!';
}

class BalanceAssertion {
  final String date;
  final String acc;
  final double val;
  final String comm;
  final String raw;

  const BalanceAssertion({
    required this.date,
    required this.acc,
    required this.val,
    required this.comm,
    required this.raw,
  });
}

class ParseResult {
  final List<Transaction> transactions;
  final List<BalanceAssertion> assertions;
  final List<String> headerLines;
  final List<String> directiveLines;
  final Set<String> accounts;
  final Set<String> tags;
  final Map<String, String> aliases;
  final Set<String> commodities;

  const ParseResult({
    required this.transactions,
    required this.assertions,
    required this.headerLines,
    required this.directiveLines,
    required this.accounts,
    required this.tags,
    required this.aliases,
    required this.commodities,
  });

  static ParseResult empty() => ParseResult(
        transactions: [],
        assertions: [],
        headerLines: [],
        directiveLines: [],
        accounts: {},
        tags: {},
        aliases: {},
        commodities: {},
      );
}
