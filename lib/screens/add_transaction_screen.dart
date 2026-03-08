// lib/screens/add_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/ledger_provider.dart';
import '../services/parser.dart';
import '../services/ledger_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? prefill;
  const AddTransactionScreen({super.key, this.prefill});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _error = '';
  bool _saving = false;

  // Posting form state
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _flag = '';
  final List<_PostingForm> _postings = [
    _PostingForm(),
    _PostingForm(),
  ];

  bool _rawMode = false;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _ctrl.text = widget.prefill != null
        ? '$today ${widget.prefill}\n    \n    '
        : '$today ';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _descCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Transaction'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _rawMode = !_rawMode),
            icon: Icon(_rawMode ? Icons.tune : Icons.code, size: 16),
            label: Text(_rawMode ? 'Form' : 'Raw'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _rawMode
                  ? _buildRawEditor(provider, scheme, mono)
                  : _buildFormEditor(provider, scheme, mono),
            ),
          ),
          _buildBottomBar(context, provider, scheme),
        ],
      ),
    );
  }

  // ─── FORM MODE ─────────────────────────────────────────────────────────────

  Widget _buildFormEditor(
      LedgerProvider provider, ColorScheme scheme, TextStyle mono) {
    final accounts = provider.engine.accounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date + flag row
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                  child: Text(
                    DateFormat('yyyy-MM-dd').format(_date),
                    style: TextStyle(fontFamily: mono.fontFamily),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Flag selector
            _FlagSelector(
              value: _flag,
              onChanged: (v) => setState(() => _flag = v),
              scheme: scheme,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description with autocomplete
        _AccountAutocomplete(
          label: 'Description',
          hint: 'e.g. Migros market',
          icon: Icons.description_outlined,
          ctrl: _descCtrl,
          suggestions: provider.transactions
              .map((t) => t.desc)
              .toSet()
              .toList()
            ..sort(),
          mono: mono,
        ),
        const SizedBox(height: 20),

        // Postings
        Row(
          children: [
            Text(
              'POSTINGS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: scheme.secondary,
                fontFamily: mono.fontFamily,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _postings.add(_PostingForm())),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add posting'),
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ..._postings.asMap().entries.map((e) {
          final i = e.key;
          final form = e.value;
          return _PostingRow(
            form: form,
            index: i,
            accounts: accounts,
            onDelete: _postings.length > 2
                ? () => setState(() => _postings.removeAt(i))
                : null,
            mono: mono,
            scheme: scheme,
          );
        }),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.error.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(fontSize: 12, color: scheme.error)),
                ),
              ],
            ),
          ),
        ],

        // Preview
        const SizedBox(height: 20),
        Text(
          'PREVIEW',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: scheme.secondary,
            fontFamily: mono.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(
            _buildHledgerFromForm(),
            style: TextStyle(
              fontFamily: mono.fontFamily,
              fontSize: 12,
              color: const Color(0xFFCBD5E1),
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }

  String _buildHledgerFromForm() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    final flagStr = _flag.isNotEmpty ? ' $_flag' : '';
    final desc = _descCtrl.text.trim();
    final sb = StringBuffer('$dateStr$flagStr ${desc.isEmpty ? '…' : desc}\n');
    for (final p in _postings) {
      final acc = p.accCtrl.text.trim();
      final amt = p.amtCtrl.text.trim();
      if (acc.isEmpty && amt.isEmpty) {
        sb.writeln('    …');
      } else if (amt.isEmpty) {
        sb.writeln('    $acc');
      } else {
        sb.writeln('    $acc  $amt');
      }
    }
    return sb.toString().trimRight();
  }

  // ─── RAW MODE ─────────────────────────────────────────────────────────────

  Widget _buildRawEditor(
      LedgerProvider provider, ColorScheme scheme, TextStyle mono) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HLEDGER FORMAT',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: scheme.secondary,
            fontFamily: mono.fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        // Quick account chips
        _AccountChips(
          accounts: provider.engine.accounts,
          onTap: (acc) => _insertAtCursor('    $acc  '),
          scheme: scheme,
          mono: mono,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 8,
            style: TextStyle(
              fontFamily: mono.fontFamily,
              fontSize: 14,
              color: const Color(0xFFCBD5E1),
              height: 1.7,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(14),
              border: InputBorder.none,
              hintText:
                  '2024-01-15 Description\n    expenses:category  100 TRY\n    assets:bank',
            ),
            keyboardType: TextInputType.multiline,
          ),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error, style: TextStyle(color: scheme.error, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        Text(
          'FORMAT GUIDE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: scheme.secondary,
            fontFamily: mono.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        _FormatGuide(scheme: scheme, mono: mono),
      ],
    );
  }

  void _insertAtCursor(String text) {
    final start = _ctrl.selection.start;
    final end = _ctrl.selection.end;
    if (start < 0) {
      _ctrl.text += text;
    } else {
      _ctrl.text =
          _ctrl.text.substring(0, start) + text + _ctrl.text.substring(end);
      _ctrl.selection =
          TextSelection.collapsed(offset: start + text.length);
    }
  }

  // ─── BOTTOM BAR ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(
      BuildContext context, LedgerProvider provider, ColorScheme scheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: scheme.secondary.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _save(context, provider),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, LedgerProvider provider) async {
    setState(() {
      _error = '';
      _saving = true;
    });

    try {
      String raw;
      if (_rawMode) {
        raw = _ctrl.text.trim();
      } else {
        raw = _buildHledgerFromForm().trim();
        // Basic validation
        if (_descCtrl.text.trim().isEmpty) {
          setState(() {
            _error = 'Description is required';
            _saving = false;
          });
          return;
        }
        if (_postings.every((p) => p.accCtrl.text.trim().isEmpty)) {
          setState(() {
            _error = 'At least one posting is required';
            _saving = false;
          });
          return;
        }
      }

      if (raw.isEmpty) {
        setState(() {
          _error = 'Transaction cannot be empty';
          _saving = false;
        });
        return;
      }

      // Validate via parser
      final result = HledgerParser.parse(raw);
      if (result.transactions.isEmpty) {
        setState(() {
          _error = 'No valid transaction found. Check the format.';
          _saving = false;
        });
        return;
      }
      final txn = result.transactions.first;
      if (txn.hasError) {
        setState(() {
          _error = txn.error!;
          _saving = false;
        });
        return;
      }

      await provider.appendRaw(raw);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _PostingForm {
  final accCtrl = TextEditingController();
  final amtCtrl = TextEditingController();
}

class _PostingRow extends StatelessWidget {
  final _PostingForm form;
  final int index;
  final List<String> accounts;
  final VoidCallback? onDelete;
  final TextStyle mono;
  final ColorScheme scheme;

  const _PostingRow({
    required this.form,
    required this.index,
    required this.accounts,
    required this.onDelete,
    required this.mono,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '  ${index + 1}.',
            style: TextStyle(
              fontFamily: mono.fontFamily,
              fontSize: 13,
              color: scheme.secondary,
              height: 2.8,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _AccountAutocomplete(
              label: 'Account',
              hint: 'expenses:food',
              icon: Icons.account_tree_outlined,
              ctrl: form.accCtrl,
              suggestions: accounts,
              mono: mono,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: form.amtCtrl,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '100 TRY',
                hintStyle: TextStyle(fontFamily: mono.fontFamily, fontSize: 12),
              ),
              style: TextStyle(fontFamily: mono.fontFamily, fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close, size: 16, color: scheme.secondary),
              padding: const EdgeInsets.only(top: 8, left: 4),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _AccountAutocomplete extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final TextEditingController ctrl;
  final List<String> suggestions;
  final TextStyle mono;

  const _AccountAutocomplete({
    required this.label,
    required this.hint,
    required this.icon,
    required this.ctrl,
    required this.suggestions,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const [];
        return suggestions
            .where((s) =>
                s.toLowerCase().contains(value.text.toLowerCase()))
            .take(8);
      },
      onSelected: (s) => ctrl.text = s,
      fieldViewBuilder: (ctx, ctrl2, focusNode, onSubmit) {
        // Sync external controller value
        ctrl2.text = ctrl.text;
        ctrl.addListener(() {
          if (ctrl2.text != ctrl.text) ctrl2.text = ctrl.text;
        });
        return TextField(
          controller: ctrl2,
          focusNode: focusNode,
          onEditingComplete: onSubmit,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, size: 16),
          ),
          style: TextStyle(fontFamily: mono.fontFamily, fontSize: 13),
          onChanged: (v) => ctrl.text = v,
        );
      },
      optionsViewBuilder: (ctx, onSel, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final opt = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(opt,
                        style: TextStyle(
                            fontFamily: mono.fontFamily, fontSize: 13)),
                    onTap: () => onSel(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlagSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;

  const _FlagSelector({
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FlagChip(
          label: 'None',
          flag: '',
          selected: value == '',
          onTap: () => onChanged(''),
          scheme: scheme,
        ),
        const SizedBox(width: 4),
        _FlagChip(
          label: '* Cleared',
          flag: '*',
          selected: value == '*',
          onTap: () => onChanged('*'),
          scheme: scheme,
        ),
        const SizedBox(width: 4),
        _FlagChip(
          label: '! Pending',
          flag: '!',
          selected: value == '!',
          onTap: () => onChanged('!'),
          scheme: scheme,
        ),
      ],
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label, flag;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _FlagChip({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? scheme.primary : scheme.secondary.withOpacity(0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? scheme.primary : scheme.secondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _AccountChips extends StatelessWidget {
  final List<String> accounts;
  final ValueChanged<String> onTap;
  final ColorScheme scheme;
  final TextStyle mono;

  const _AccountChips({
    required this.accounts,
    required this.onTap,
    required this.scheme,
    required this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final top = accounts.take(12).toList();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: top.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ActionChip(
          label: Text(
            top[i].split(':').last,
            style:
                TextStyle(fontSize: 11, fontFamily: mono.fontFamily),
          ),
          onPressed: () => onTap(top[i]),
          side: BorderSide(color: scheme.secondary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _FormatGuide extends StatelessWidget {
  final ColorScheme scheme;
  final TextStyle mono;

  const _FormatGuide({required this.scheme, required this.mono});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['DATE', '2024-01-15'],
      ['FLAG', '* cleared · ! pending'],
      ['POSTING', '    account  amount'],
      ['IMPLICIT', '    account  (blank = auto)'],
      ['COMMENT', '; after amount or line'],
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    r[0],
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: mono.fontFamily,
                      color: scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  r[1],
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: mono.fontFamily,
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
