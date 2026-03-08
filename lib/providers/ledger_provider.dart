// lib/providers/ledger_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import '../services/parser.dart';
import '../services/ledger_service.dart';

const _kPrefsKey = 'ledgie_raw_ledger';
const _kBackupPrefix = 'ledgie_backup_';

class LedgerProvider extends ChangeNotifier {
  String _raw = '';
  ParseResult _parseResult = ParseResult.empty();
  LedgerEngine _engine = LedgerEngine([], ParseResult.empty());

  bool _isLoading = true;
  String? _mountedFilePath;
  String _currentLedger = 'default';

  // Getters
  String get raw => _raw;
  ParseResult get parseResult => _parseResult;
  LedgerEngine get engine => _engine;
  List<Transaction> get transactions => _parseResult.transactions;
  bool get isLoading => _isLoading;
  String? get mountedFilePath => _mountedFilePath;
  String get currentLedger => _currentLedger;
  bool get isMounted => _mountedFilePath != null;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString(_kPrefsKey);

    if (saved == null || saved.trim().isEmpty) {
      // Load bundled sample
      saved = await rootBundle.loadString('assets/sample_ledger.hledger');
    }

    _loadRaw(saved);
    _isLoading = false;
    notifyListeners();
  }

  // ─── LOAD / PARSE ─────────────────────────────────────────────────────────

  void _loadRaw(String raw) {
    _raw = raw;
    _parseResult = HledgerParser.parse(raw);
    _engine = LedgerEngine(_parseResult.transactions, _parseResult);
  }

  Future<void> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    final content = await file.readAsString();
    _autoBackup();
    _mountedFilePath = path;
    _currentLedger = path.split('/').last.replaceAll('.hledger', '');
    _loadRaw(content);
    await _save();
    notifyListeners();
  }

  Future<void> importRaw(String content, {String? name}) async {
    _autoBackup();
    _loadRaw(content);
    if (name != null) _currentLedger = name;
    await _save();
    notifyListeners();
  }

  // ─── SAVE ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, _raw);

    // Write back to mounted file if any
    if (_mountedFilePath != null) {
      try {
        await File(_mountedFilePath!).writeAsString(_raw);
      } catch (_) {}
    }
  }

  // ─── ADD TRANSACTION ──────────────────────────────────────────────────────

  Future<void> appendRaw(String transactionText) async {
    _autoBackup();
    final trimmed = transactionText.trim();
    if (trimmed.isEmpty) return;
    final newRaw = _raw.trimRight() + '\n\n' + trimmed + '\n';
    _loadRaw(newRaw);
    await _save();
    notifyListeners();
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────

  Future<bool> deleteTransaction(int id) async {
    if (id < 0 || id >= _parseResult.transactions.length) return false;
    _autoBackup();

    final txn = _parseResult.transactions[id];
    final lines = _raw.split('\n');
    // Find the line block for this transaction by date+desc
    final header = '${txn.date}';
    int startLine = -1;

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(header) && lines[i].contains(txn.desc)) {
        startLine = i;
        break;
      }
    }

    if (startLine == -1) return false;

    // Find end of transaction block (next blank line or EOF)
    int endLine = startLine + 1;
    while (endLine < lines.length && lines[endLine].trim().isNotEmpty) {
      endLine++;
    }

    final newLines = [...lines.sublist(0, startLine), ...lines.sublist(endLine)];
    _loadRaw(newLines.join('\n'));
    await _save();
    notifyListeners();
    return true;
  }

  // ─── ACCOUNT MANAGEMENT ───────────────────────────────────────────────────

  Future<void> addAccount(String name) async {
    if (_parseResult.accounts.contains(name)) return;
    final newRaw = 'account $name\n' + _raw;
    _loadRaw(newRaw);
    await _save();
    notifyListeners();
  }

  // ─── BACKUP ───────────────────────────────────────────────────────────────

  void _autoBackup() async {
    if (_raw.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final key = '$_kBackupPrefix$ts';

    // Keep max 5 backups
    final keys = prefs.getKeys().where((k) => k.startsWith(_kBackupPrefix)).toList()..sort();
    while (keys.length >= 5) {
      await prefs.remove(keys.removeAt(0));
    }
    await prefs.setString(key, _raw);
  }

  Future<List<String>> listBackups() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys()
        .where((k) => k.startsWith(_kBackupPrefix))
        .toList()
      ..sort()
      ..reversed;
  }

  Future<void> restoreBackup(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final content = prefs.getString(key);
    if (content != null) {
      _loadRaw(content);
      await _save();
      notifyListeners();
    }
  }

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  String exportHledger() => _raw;

  // ─── RESET ────────────────────────────────────────────────────────────────

  Future<void> reset() async {
    _autoBackup();
    final sample = await rootBundle.loadString('assets/sample_ledger.hledger');
    _mountedFilePath = null;
    _currentLedger = 'default';
    _loadRaw(sample);
    await _save();
    notifyListeners();
  }
}
