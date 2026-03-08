// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/ledger_provider.dart';
import '../services/ledger_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Ledger stats ─────────────────────────────────────────────────
          _SectionHeader('LEDGER', scheme, mono),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Current ledger'),
            subtitle: Text(provider.currentLedger),
            trailing: provider.isMounted
                ? Chip(
                    label: Text(
                      'MOUNTED',
                      style: TextStyle(
                          fontFamily: mono.fontFamily,
                          fontSize: 10,
                          color: scheme.primary),
                    ),
                    backgroundColor: scheme.primary.withOpacity(0.1),
                    side: BorderSide(color: scheme.primary, width: 0.5),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.numbers_outlined),
            title: const Text('Transactions'),
            trailing: Text(
              '${provider.transactions.length}',
              style: TextStyle(fontFamily: mono.fontFamily),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Accounts'),
            trailing: Text(
              '${engine.accounts.length}',
              style: TextStyle(fontFamily: mono.fontFamily),
            ),
          ),
          if (stats.dominantComm.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('Primary currency'),
              trailing: Text(
                stats.dominantComm,
                style: TextStyle(
                  fontFamily: mono.fontFamily,
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const Divider(),

          // ── Import ────────────────────────────────────────────────────────
          _SectionHeader('IMPORT', scheme, mono),
          ListTile(
            leading:
                Icon(Icons.upload_file_outlined, color: scheme.primary),
            title: const Text('Import .hledger file'),
            subtitle: const Text('Replaces current ledger data'),
            onTap: () => _importFile(context, provider),
          ),
          ListTile(
            leading: Icon(Icons.paste_outlined, color: scheme.primary),
            title: const Text('Paste hledger text'),
            subtitle: const Text('Import from clipboard'),
            onTap: () => _importClipboard(context, provider),
          ),

          const Divider(),

          // ── Export ────────────────────────────────────────────────────────
          _SectionHeader('EXPORT', scheme, mono),
          ListTile(
            leading:
                Icon(Icons.share_outlined, color: scheme.tertiary),
            title: const Text('Share .hledger file'),
            onTap: () => _shareFile(context, provider),
          ),
          ListTile(
            leading:
                Icon(Icons.copy_outlined, color: scheme.tertiary),
            title: const Text('Copy to clipboard'),
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: provider.exportHledger()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Ledger copied to clipboard')),
              );
            },
          ),
          ListTile(
            leading:
                Icon(Icons.save_outlined, color: scheme.tertiary),
            title: const Text('Save to device'),
            subtitle: const Text('Saves to Downloads folder'),
            onTap: () => _saveToDevice(context, provider),
          ),

          const Divider(),

          // ── Raw editor ────────────────────────────────────────────────────
          _SectionHeader('RAW EDITOR', scheme, mono),
          ListTile(
            leading: Icon(Icons.edit_note_outlined, color: scheme.secondary),
            title: const Text('Edit raw hledger'),
            subtitle: const Text('Full-text editor for advanced users'),
            onTap: () => _openRawEditor(context, provider),
          ),

          const Divider(),

          // ── Backup & reset ────────────────────────────────────────────────
          _SectionHeader('BACKUP', scheme, mono),
          ListTile(
            leading: Icon(Icons.history_outlined, color: scheme.secondary),
            title: const Text('View backups'),
            onTap: () => _showBackups(context, provider),
          ),
          ListTile(
            leading:
                Icon(Icons.restart_alt_outlined, color: scheme.error),
            title: const Text('Reset to sample data'),
            subtitle: const Text('Replaces with demo ledger'),
            onTap: () => _confirmReset(context, provider),
          ),

          const Divider(),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('ABOUT', scheme, mono),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Ledgie'),
            subtitle: const Text('v1.3 — hledger-compatible personal ledger'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Format'),
            subtitle: const Text('hledger plaintext accounting'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _importFile(
      BuildContext context, LedgerProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['hledger', 'journal', 'ledger'],
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      await provider.importFile(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${result.files.single.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _importClipboard(
      BuildContext context, LedgerProvider provider) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }
    await provider.importRaw(data.text!, name: 'clipboard');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported from clipboard')),
      );
    }
  }

  Future<void> _shareFile(
      BuildContext context, LedgerProvider provider) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ledgie_export.hledger');
    await file.writeAsString(provider.exportHledger());
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Ledgie export',
    );
  }

  Future<void> _saveToDevice(
      BuildContext context, LedgerProvider provider) async {
    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/ledgie_$ts.hledger');
      await file.writeAsString(provider.exportHledger());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _openRawEditor(
      BuildContext context, LedgerProvider provider) async {
    final ctrl = TextEditingController(text: provider.exportHledger());
    final mono = GoogleFonts.jetBrainsMono();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scroll) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Text('Raw Editor',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await provider.importRaw(ctrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontFamily: mono.fontFamily,
                  fontSize: 12,
                  color: const Color(0xFFCBD5E1),
                  height: 1.6,
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                keyboardType: TextInputType.multiline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBackups(
      BuildContext context, LedgerProvider provider) async {
    final backups = await provider.listBackups();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-backups'),
        content: backups.isEmpty
            ? const Text('No backups yet')
            : SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: backups.reversed
                      .take(5)
                      .map((k) => ListTile(
                            dense: true,
                            title: Text(
                              k.replaceAll('ledgie_backup_', ''),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                await provider.restoreBackup(k);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Restore'),
                            ),
                          ))
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, LedgerProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to sample data?'),
        content: const Text(
            'This will replace your current ledger with demo data. Your data will be backed up first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset complete. Previous data backed up.')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ColorScheme scheme;
  final TextStyle mono;

  const _SectionHeader(this.title, this.scheme, this.mono);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          color: scheme.primary,
          fontFamily: mono.fontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
