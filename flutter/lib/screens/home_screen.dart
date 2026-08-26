import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/remittance_parser.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/account_picker.dart';
import '../widgets/account_name_field.dart';
import '../widgets/common.dart';
import '../widgets/preview_table.dart';
import '../widgets/settings_card.dart';
import '../widgets/fx_fields.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final index = switch (app.createTab) {
      'each' => 1,
      'manual' => 2,
      'charge' => 3,
      'profit' => 4,
      'ledger' => 5,
      _ => 0,
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const WakeedMark(size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('وكيد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (app.displayUserName.isNotEmpty)
                    Text(
                      app.displayUserName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: app.connected ? WakeedColors.accent.withValues(alpha: 0.15) : WakeedColors.err.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  app.connBadge,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: app.connected ? WakeedColors.green : WakeedColors.err),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (app.subscriptions.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: app.subscriptions.any((s) => s.ownerKey == app.selectedOwnerKey)
                    ? app.selectedOwnerKey
                    : app.subscriptions.first.ownerKey,
                items: [
                  for (final s in app.subscriptions)
                    DropdownMenuItem(value: s.ownerKey, child: Text(app.subscriptionLabel(s))),
                ],
                onChanged: (v) {
                  if (v != null) app.selectSubscription(v);
                },
              ),
            ),
          IconButton(
            tooltip: 'الوضع الليلي / الفاتح',
            onPressed: app.toggleTheme,
            icon: Icon(app.isDark ? Icons.dark_mode : Icons.light_mode),
          ),
          TextButton(onPressed: app.logout, child: const Text('خروج')),
        ],
      ),
      body: index == 5
          ? const LedgerTab()
          : ListView(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
              children: [
                const SettingsCard(),
                const SizedBox(height: 6),
                if (index == 0) const BatchTab(),
                if (index == 1) const EachTab(),
                if (index == 2) const ManualTab(),
                if (index == 3) const ChargeTab(),
                if (index == 4) const ProfitTab(),
              ],
            ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            app.setTab(['batch', 'each', 'manual', 'charge', 'profit', 'ledger'][i]);
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'جماعي'),
            const NavigationDestination(icon: Icon(Icons.person_outline), label: 'لكل عميل'),
            const NavigationDestination(icon: Icon(Icons.edit_note), label: 'فردي'),
            const NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'شحن'),
            const NavigationDestination(icon: Icon(Icons.trending_up), label: 'ربحي'),
            NavigationDestination(
              icon: Badge(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                largeSize: 12,
                textStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, height: 1),
                label: Text('${app.ownerLedger().length}'),
                isLabelVisible: app.ownerLedger().isNotEmpty,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              label: 'السجل',
            ),
          ],
        ),
      ),
    );
  }
}

class BatchTab extends StatefulWidget {
  const BatchTab({super.key});

  @override
  State<BatchTab> createState() => _BatchTabState();
}

class _BatchTabState extends State<BatchTab> {
  late final TextEditingController notes;
  late final TextEditingController data;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    notes = TextEditingController(text: app.notesBatch);
    data = TextEditingController(text: app.tableBatch);
  }

  @override
  void dispose() {
    notes.dispose();
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (app.tableBatch.isEmpty && data.text.isNotEmpty) data.clear();
    if (app.notesBatch.isEmpty && notes.text.isNotEmpty) notes.clear();
    final rows = app.currentRows('batch');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('جماعي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sheetTemplate));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ القالب')));
                  }
                },
                child: const Text('قالب'),
              ),
            ],
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(hintText: 'البيان'),
            onChanged: app.setNotesBatch,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: data,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(hintText: 'الاسم\tالمبلغ\tالدائن'),
            onChanged: app.setTableBatch,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.busy ? null : app.previewBatch,
                  child: const Text('معاينة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: app.submitJob.active ? null : app.submitBatch,
                  child: const Text('إنشاء'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JournalFxSummary(
            rows: rows,
            symbol: app.baseCurrencyQuote().symbol,
            leading: [
              StatChip(label: 'عملاء', value: '${(rows.length / 2).ceil()}'),
              const SizedBox(width: 6),
              StatChip(label: 'أسطر', value: '${rows.length}'),
            ],
          ),
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['#', 'البيان', 'حساب', 'طرف ثالث', 'مدين', 'دائن', 'محلول'],
            rows: [
              for (var i = 0; i < rows.length; i++)
                [
                  '${i + 1}',
                  app.composeNote(rows[i].description, app.sectionNote('batch')),
                  rows[i].account,
                  app.thirdPartyCell(rows[i]),
                  formatJournalAmount(rows[i], debit: true),
                  formatJournalAmount(rows[i], debit: false),
                  app.resolvedLabel(app.resolvedBatch, rows[i].account),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class EachTab extends StatefulWidget {
  const EachTab({super.key});

  @override
  State<EachTab> createState() => _EachTabState();
}

class _EachTabState extends State<EachTab> {
  late final TextEditingController notes;
  late final TextEditingController data;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    notes = TextEditingController(text: app.notesEach);
    data = TextEditingController(text: app.tableEach);
  }

  @override
  void dispose() {
    notes.dispose();
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (app.tableEach.isEmpty && data.text.isNotEmpty) data.clear();
    if (app.notesEach.isEmpty && notes.text.isNotEmpty) notes.clear();
    final rows = app.currentRows('each');
    final groups = groupCustomerRows(rows);
    final tableRows = <List<String>>[];
    var lineNo = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      for (final row in groups[gi].rows) {
        lineNo += 1;
        tableRows.add([
          '${gi + 1}',
          '$lineNo',
          app.composeNote(row.description, app.sectionNote('each')),
          row.account,
          app.thirdPartyCell(row),
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedEach, row.account),
        ]);
      }
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('لكل عميل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: sheetTemplate));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ القالب')));
                  }
                },
                child: const Text('قالب'),
              ),
            ],
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(hintText: 'البيان'),
            onChanged: app.setNotesEach,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: data,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(hintText: 'الاسم\tالمبلغ\tالدائن'),
            onChanged: app.setTableEach,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.busy ? null : app.previewEach,
                  child: const Text('معاينة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: app.submitJob.active ? null : app.submitEach,
                  child: const Text('إنشاء'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JournalFxSummary(
            rows: rows,
            symbol: app.baseCurrencyQuote().symbol,
            leading: [
              StatChip(label: 'سندات', value: '${groups.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'عملاء', value: '${groups.length}'),
            ],
          ),
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['سند', '#', 'البيان', 'حساب', 'طرف ثالث', 'مدين', 'دائن', 'محلول'],
            rows: tableRows,
          ),
        ],
      ),
    );
  }
}

class ManualTab extends StatelessWidget {
  const ManualTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    app.ensureManualEntries();
    final rows = app.manualRows();
    final groups = groupCustomerRows(rows);
    final tableRows = <List<String>>[];
    var lineNo = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      for (final row in groups[gi].rows) {
        lineNo += 1;
        tableRows.add([
          '${gi + 1}',
          '$lineNo',
          app.composeNote(row.description, row.clientNote),
          row.account,
          app.thirdPartyCell(row),
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedManual, row.account),
        ]);
      }
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('فردي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text('${app.manualEntries.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < app.manualEntries.length; i++)
            _ManualEntryCard(key: ValueKey(app.manualEntries[i].id), index: i, entry: app.manualEntries[i]),
          OutlinedButton(onPressed: app.addManualEntry, child: const Text('+ سند')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.busy ? null : app.previewManual,
                  child: const Text('معاينة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: app.submitJob.active ? null : app.submitManual,
                  child: const Text('تسجيل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JournalFxSummary(
            rows: rows,
            symbol: app.baseCurrencyQuote().symbol,
            leading: [
              StatChip(label: 'سندات', value: '${groups.length}'),
            ],
          ),
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['سند', '#', 'البيان', 'حساب', 'طرف ثالث', 'مدين', 'دائن', 'محلول'],
            rows: tableRows,
          ),
        ],
      ),
    );
  }
}

class _ManualEntryCard extends StatefulWidget {
  const _ManualEntryCard({super.key, required this.index, required this.entry});

  final int index;
  final ManualEntry entry;

  @override
  State<_ManualEntryCard> createState() => _ManualEntryCardState();
}

class _ManualEntryCardState extends State<_ManualEntryCard> {
  late final TextEditingController nameCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController creditCtrl;
  late final TextEditingController noteCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.entry.name);
    amountCtrl = TextEditingController(text: widget.entry.amount);
    creditCtrl = TextEditingController(text: widget.entry.credit);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ManualEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (nameCtrl.text != widget.entry.name && widget.entry.name.isEmpty) nameCtrl.clear();
    if (amountCtrl.text != widget.entry.amount && widget.entry.amount.isEmpty) amountCtrl.clear();
    if (noteCtrl.text != widget.entry.note && widget.entry.note.isEmpty) noteCtrl.clear();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    creditCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..credit = creditCtrl.text
      ..creditRate = ''
      ..note = noteCtrl.text;
    context.read<AppController>().updateManualEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
    final debitQ = app.currencyQuoteForAccount(app.debitAccount);
    final amt = num.tryParse(cleanAmount(amountCtrl.text)) ?? 0;
    final creditBase = amountToBaseFromQuote(amt, creditQ);
    final debitBase = amountToBaseFromQuote(amountFromBase(creditBase, debitQ.isBase ? 1 : debitQ.hawalaRate), debitQ);
    final mixed = !creditQ.isBase || !debitQ.isBase;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('سند ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: app.manualEntries.length > 1 ? () => app.removeManualEntry(widget.entry.id) : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(hintText: 'الاسم'),
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FxAmountField(
                  controller: amountCtrl,
                  symbol: creditQ.badge,
                  labelText: 'المبلغ',
                  hintText: '1500',
                  onChanged: (_) => _sync(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AccountNameField(
                  controller: creditCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: _sync,
                ),
              ),
              IconButton(
                tooltip: 'اختر',
                visualDensity: VisualDensity.compact,
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.credit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.green),
              ),
            ],
          ),
          if (mixed && amt > 0) ...[
            const SizedBox(height: 8),
            ProfitFxBar(
              diff: roundMoney(debitBase - creditBase),
              creditBase: creditBase,
              debitBase: debitBase,
              symbol: app.baseCurrencyQuote().symbol,
              compact: true,
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(hintText: 'البيان'),
            onChanged: (_) => _sync(),
          ),
        ],
      ),
    );
  }
}

class ChargeTab extends StatelessWidget {
  const ChargeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    app.ensureChargeEntries();
    final rows = app.chargeRows();
    final groups = groupCustomerRows(rows);
    final tableRows = <List<String>>[];
    var lineNo = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      for (final row in groups[gi].rows) {
        lineNo += 1;
        tableRows.add([
          '${gi + 1}',
          '$lineNo',
          app.composeNote(row.description, row.clientNote),
          row.account,
          app.thirdPartyCell(row),
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedCharge, row.account),
        ]);
      }
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('شحن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text('${app.chargeEntries.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < app.chargeEntries.length; i++)
            _ChargeEntryCard(key: ValueKey(app.chargeEntries[i].id), index: i, entry: app.chargeEntries[i]),
          OutlinedButton(onPressed: app.addChargeEntry, child: const Text('+ سند')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.busy ? null : app.previewCharge,
                  child: const Text('معاينة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: app.submitJob.active ? null : app.submitCharge,
                  child: const Text('تسجيل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JournalFxSummary(
            rows: rows,
            symbol: app.baseCurrencyQuote().symbol,
            leading: [
              StatChip(label: 'سندات', value: '${groups.length}'),
            ],
          ),
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['سند', '#', 'البيان', 'حساب', 'طرف ثالث', 'مدين', 'دائن', 'محلول'],
            rows: tableRows,
          ),
        ],
      ),
    );
  }
}

class _ChargeEntryCard extends StatefulWidget {
  const _ChargeEntryCard({super.key, required this.index, required this.entry});

  final int index;
  final ManualEntry entry;

  @override
  State<_ChargeEntryCard> createState() => _ChargeEntryCardState();
}

class _ChargeEntryCardState extends State<_ChargeEntryCard> {
  late final TextEditingController nameCtrl;
  late final TextEditingController amountCtrl;
  late final TextEditingController debitCtrl;
  late final TextEditingController creditCtrl;
  late final TextEditingController noteCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.entry.name);
    amountCtrl = TextEditingController(text: widget.entry.amount);
    debitCtrl = TextEditingController(text: widget.entry.debit);
    creditCtrl = TextEditingController(text: widget.entry.credit);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ChargeEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (debitCtrl.text != widget.entry.debit) debitCtrl.text = widget.entry.debit;
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (nameCtrl.text != widget.entry.name && widget.entry.name.isEmpty) nameCtrl.clear();
    if (amountCtrl.text != widget.entry.amount && widget.entry.amount.isEmpty) amountCtrl.clear();
    if (noteCtrl.text != widget.entry.note && widget.entry.note.isEmpty) noteCtrl.clear();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    debitCtrl.dispose();
    creditCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..debit = debitCtrl.text
      ..debitRate = ''
      ..credit = creditCtrl.text
      ..creditRate = ''
      ..note = noteCtrl.text;
    context.read<AppController>().updateChargeEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final debitQ = app.currencyQuoteForAccount(debitCtrl.text);
    final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
    final amt = num.tryParse(cleanAmount(amountCtrl.text)) ?? 0;
    final creditBase = amountToBaseFromQuote(amt, creditQ);
    final debitBase = amountToBaseFromQuote(amountFromBase(creditBase, debitQ.isBase ? 1 : debitQ.hawalaRate), debitQ);
    final mixed = !creditQ.isBase || !debitQ.isBase;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('سند ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: app.chargeEntries.length > 1 ? () => app.removeChargeEntry(widget.entry.id) : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(hintText: 'الاسم'),
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 6),
          FxAmountField(
            controller: amountCtrl,
            symbol: creditQ.badge.isNotEmpty ? creditQ.badge : debitQ.badge,
            labelText: 'المبلغ',
            hintText: '1500',
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AccountNameField(
                  controller: debitCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: _sync,
                  debit: true,
                ),
              ),
              IconButton(
                tooltip: 'اختر المدين',
                visualDensity: VisualDensity.compact,
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeDebit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.err),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AccountNameField(
                  controller: creditCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: _sync,
                ),
              ),
              IconButton(
                tooltip: 'اختر الدائن',
                visualDensity: VisualDensity.compact,
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeCredit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.green),
              ),
            ],
          ),
          if (mixed && amt > 0) ...[
            const SizedBox(height: 8),
            ProfitFxBar(
              diff: roundMoney(debitBase - creditBase),
              creditBase: creditBase,
              debitBase: debitBase,
              symbol: app.baseCurrencyQuote().symbol,
              compact: true,
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(hintText: 'البيان'),
            onChanged: (_) => _sync(),
          ),
        ],
      ),
    );
  }
}

class ProfitTab extends StatefulWidget {
  const ProfitTab({super.key});

  @override
  State<ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<ProfitTab> {
  late final TextEditingController notes;
  late final TextEditingController data;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    notes = TextEditingController(text: app.notesProfit);
    data = TextEditingController(text: app.tableProfit);
  }

  @override
  void dispose() {
    notes.dispose();
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    if (app.tableProfit.isEmpty && data.text.isNotEmpty) data.clear();
    if (app.notesProfit.isEmpty && notes.text.isNotEmpty) notes.clear();
    app.ensureProfitEntries();
    final rows = app.profitRows();
    final paste = app.currentProfitPaste();
    final pt = profitPasteTotals(paste);
    final profit = pt['diff'] ?? 0;
    final keyIndex = <String, int>{};
    var voucherNo = 0;
    final tableRows = <List<String>>[
      for (var i = 0; i < rows.length; i++)
        [
          () {
            final key = rows[i].groupKey.isEmpty ? 'r$i' : rows[i].groupKey;
            return '${keyIndex.putIfAbsent(key, () => ++voucherNo)}';
          }(),
          '${i + 1}',
          rows[i].balancing
              ? (rows[i].credit.isNotEmpty ? 'ربح' : 'كسر')
              : app.composeNote(
                  rows[i].description,
                  rows[i].clientNote.isNotEmpty ? rows[i].clientNote : app.sectionNote('profit'),
                ),
          () {
            final name = app.chartAccountName(rows[i].account);
            final account = name.isNotEmpty ? name : rows[i].account;
            if (rows[i].balancing && rows[i].thirdPartyName.isNotEmpty) {
              return account.isNotEmpty ? account : rows[i].thirdPartyName;
            }
            return account;
          }(),
          app.thirdPartyCell(rows[i]),
          _profitAmountCell(rows[i].debit, rows[i]),
          _profitAmountCell(rows[i].credit, rows[i]),
          app.resolvedLabel(app.resolvedProfit, rows[i].account),
        ],
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('ربحي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              if (app.profitMode != 'each')
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: profitSheetTemplate));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ القالب')));
                    }
                  },
                  child: const Text('قالب'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'batch', label: Text('جماعي')),
              ButtonSegment(value: 'split', label: Text('جماعي فردي')),
              ButtonSegment(value: 'each', label: Text('فردي')),
            ],
            selected: {app.profitMode == 'split' || app.profitMode == 'each' ? app.profitMode : 'batch'},
            onSelectionChanged: (v) => app.setProfitMode(v.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          if (app.profitMode != 'each') ...[
            TextField(
              controller: notes,
              decoration: const InputDecoration(hintText: 'البيان'),
              onChanged: app.setNotesProfit,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: data,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(hintText: 'الدائن\tمبلغ الدائن\tالمدين\tمبلغ المدين'),
              onChanged: app.setTableProfit,
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;
                final width = wide ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < app.profitEntries.length; i++)
                      SizedBox(
                        width: width,
                        child: _ProfitEntryCard(
                          key: ValueKey(app.profitEntries[i].id),
                          index: i,
                          entry: app.profitEntries[i],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: app.addProfitEntry, child: const Text('+ سند جديد')),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: app.busy ? null : app.previewProfit,
                  child: const Text('معاينة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: app.submitJob.active ? null : app.submitProfit,
                  child: const Text('إنشاء'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProfitFxBar(
            diff: profit,
            creditBase: pt['creditBase'] ?? pt['credit'] ?? 0,
            debitBase: pt['debitBase'] ?? pt['debit'] ?? 0,
            symbol: app.baseCurrencyQuote().symbol,
          ),
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['سند', '#', 'البيان', 'حساب', 'طرف ثالث', 'مدين', 'دائن', 'محلول'],
            rows: tableRows,
          ),
        ],
      ),
    );
  }

  String _profitAmountCell(String amount, JournalRow row) {
    if (amount.trim().isEmpty) return '';
    final badge = row.currencySymbol.trim().isNotEmpty ? row.currencySymbol : row.currencyCode;
    return badge.isEmpty ? amount : '$amount $badge';
  }
}

class _ProfitEntryCard extends StatefulWidget {
  const _ProfitEntryCard({super.key, required this.index, required this.entry});

  final int index;
  final ProfitEntry entry;

  @override
  State<_ProfitEntryCard> createState() => _ProfitEntryCardState();
}

class _ProfitEntryCardState extends State<_ProfitEntryCard> {
  late final TextEditingController nameCtrl;
  late final TextEditingController creditCtrl;
  late final TextEditingController creditAmtCtrl;
  late final TextEditingController debitCtrl;
  late final TextEditingController debitAmtCtrl;
  late final TextEditingController noteCtrl;

  static const _dense = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  static const _fieldStyle = TextStyle(fontSize: 12, height: 1.2);

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.entry.name);
    creditCtrl = TextEditingController(text: widget.entry.credit);
    creditAmtCtrl = TextEditingController(text: widget.entry.creditAmount);
    debitCtrl = TextEditingController(text: widget.entry.debit);
    debitAmtCtrl = TextEditingController(text: widget.entry.debitAmount);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ProfitEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (debitCtrl.text != widget.entry.debit) debitCtrl.text = widget.entry.debit;
    if (nameCtrl.text != widget.entry.name && widget.entry.name.isEmpty) nameCtrl.clear();
    if (creditAmtCtrl.text != widget.entry.creditAmount && widget.entry.creditAmount.isEmpty) {
      creditAmtCtrl.clear();
    }
    if (debitAmtCtrl.text != widget.entry.debitAmount && widget.entry.debitAmount.isEmpty) {
      debitAmtCtrl.clear();
    }
    if (noteCtrl.text != widget.entry.note && widget.entry.note.isEmpty) noteCtrl.clear();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    creditCtrl.dispose();
    creditAmtCtrl.dispose();
    debitCtrl.dispose();
    debitAmtCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync() {
    widget.entry
      ..name = nameCtrl.text
      ..credit = creditCtrl.text
      ..creditAmount = creditAmtCtrl.text
      ..creditRate = ''
      ..debit = debitCtrl.text
      ..debitAmount = debitAmtCtrl.text
      ..debitRate = ''
      ..note = noteCtrl.text;
    context.read<AppController>().updateProfitEntry(widget.entry);
  }

  Widget _currencyBadge(String symbol, Color color) {
    if (symbol.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 4),
      child: Text(
        symbol,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required bool debit,
    required String symbol,
  }) {
    final color = debit ? WakeedColors.err : WakeedColors.green;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 12, height: 1.2, color: color),
      decoration: partyFieldDecoration(
        debit: debit,
        base: _dense,
        hintText: 'المبلغ',
        suffixIcon: _currencyBadge(symbol, color),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      onChanged: (_) => _sync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
    final debitQ = app.currencyQuoteForAccount(debitCtrl.text);
    final c = num.tryParse(cleanAmount(creditAmtCtrl.text)) ?? 0;
    final d = num.tryParse(cleanAmount(debitAmtCtrl.text)) ?? 0;
    final creditBase = amountToBaseFromQuote(c, creditQ);
    final debitBase = amountToBaseFromQuote(d, debitQ);
    final profit = roundMoney(debitBase - creditBase);
    final baseSymbol = app.baseCurrencyQuote().symbol;
    final title = (c > 0 || d > 0)
        ? 'سند ${widget.index + 1} · ${profitKindLabel(profit)} ${formatProfitSigned(profit)} $baseSymbol'
        : 'سند ${widget.index + 1}';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: profit > 0.001
                        ? WakeedColors.green
                        : profit < -0.001
                            ? WakeedColors.err
                            : null,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                tooltip: 'حذف',
                onPressed: app.profitEntries.length > 1 ? () => app.removeProfitEntry(widget.entry.id) : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AccountNameField(
                  controller: creditCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: _sync,
                  dense: true,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'اختر الحساب',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.profitCredit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, size: 18, color: WakeedColors.green),
              ),
              Expanded(
                flex: 2,
                child: _amountField(controller: creditAmtCtrl, debit: false, symbol: creditQ.badge),
              ),
            ],
          ),
          if (!creditQ.isBase && creditCtrl.text.trim().isNotEmpty && c > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${formatProfitAmount(c)} ${creditQ.badge} = ${formatProfitAmount(creditBase)} $baseSymbol',
                  style: const TextStyle(fontSize: 11, color: WakeedColors.green),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AccountNameField(
                  controller: debitCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: _sync,
                  dense: true,
                  debit: true,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'اختر الحساب',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.profitDebit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, size: 18, color: WakeedColors.err),
              ),
              Expanded(
                flex: 2,
                child: _amountField(controller: debitAmtCtrl, debit: true, symbol: debitQ.badge),
              ),
            ],
          ),
          if (!debitQ.isBase && debitCtrl.text.trim().isNotEmpty && d > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '${formatProfitAmount(d)} ${debitQ.badge} = ${formatProfitAmount(debitBase)} $baseSymbol',
                  style: const TextStyle(fontSize: 11, color: WakeedColors.err),
                ),
              ),
            ),
          if (c > 0 || d > 0) ...[
            const SizedBox(height: 8),
            ProfitFxBar(
              diff: profit,
              creditBase: creditBase,
              debitBase: debitBase,
              symbol: baseSymbol,
              compact: true,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: _fieldStyle,
                  decoration: _dense.copyWith(hintText: 'الاسم'),
                  onChanged: (_) => _sync(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  style: _fieldStyle,
                  decoration: _dense.copyWith(hintText: 'البيان'),
                  onChanged: (_) => _sync(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LedgerTab extends StatelessWidget {
  const LedgerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final rows = app.filteredLedger();
    final pageSize = ledgerPageSizeFor(
      isWeb: kIsWeb,
      width: MediaQuery.sizeOf(context).width,
    );
    final window = ledgerPageWindow(
      total: rows.length,
      pageSize: pageSize,
      page: app.ledgerPage,
    );
    final pageRows = rows.isEmpty ? const <LedgerEntry>[] : rows.sublist(window.start, window.end);
    final vouchers = rows.map((r) => r.journalNumber.isNotEmpty ? r.journalNumber : (r.journalId.isNotEmpty ? r.journalId : r.id)).toSet();
    final sum = rows.fold<num>(0, (n, r) => n + r.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('السجل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(hintText: 'رقم، اسم، حساب...', prefixIcon: Icon(Icons.search)),
                onChanged: app.setLedgerSearch,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateBox(
                      label: 'من',
                      value: app.ledgerFrom,
                      onPick: app.setLedgerFrom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateBox(
                      label: 'إلى',
                      value: app.ledgerTo,
                      onPick: app.setLedgerTo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: app.ledgerKind,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('الكل')),
                  DropdownMenuItem(value: 'batch', child: Text('جماعي')),
                  DropdownMenuItem(value: 'each', child: Text('لكل عميل')),
                  DropdownMenuItem(value: 'charge', child: Text('شحن')),
                  DropdownMenuItem(value: 'profit', child: Text('ربحي')),
                  DropdownMenuItem(value: 'synced', child: Text('متزامن')),
                ],
                onChanged: (v) => app.setLedgerKindFilter(v ?? ''),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: app.downloadLedgerExcel,
                    child: const Text('تنزيل Excel'),
                  ),
                  OutlinedButton(
                    onPressed: app.ledgerSyncing ? null : app.syncWakeedJournals,
                    child: Text(app.ledgerSyncing ? 'جارٍ المزامنة...' : 'مزامنة'),
                  ),
                  TextButton(onPressed: app.clearLedgerFilters, child: const Text('مسح')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StatChip(label: 'سندات', value: '${vouchers.length}'),
                  const SizedBox(width: 6),
                  StatChip(label: 'أسماء', value: '${rows.length}'),
                  const SizedBox(width: 6),
                  StatChip(label: 'مجموع', value: '$sum'),
                ],
              ),
              const SizedBox(height: 8),
              PreviewTable(
                emptyText: app.ownerLedger().isEmpty
                    ? (app.ledgerSyncing
                        ? 'جارٍ مزامنة سندات حسابك من وكيد...'
                        : 'لا يوجد سندات في السجل بعد. أنشئ سنداً أو اضغط مزامنة.')
                    : 'لا نتائج لهذه الفلترة.',
                columns: const ['رقم', 'تاريخ', 'وقت', 'الاسم', 'مبلغ', 'مدين', 'دائن', 'بيان', 'نوع'],
                rows: [
                  for (final row in pageRows)
                    [
                      row.journalNumber.isEmpty ? '—' : row.journalNumber,
                      row.entryDate,
                      app.formatLedgerWhen(row.createdAt),
                      row.name,
                      '${row.amount}',
                      row.debitAccountName.isNotEmpty ? '${row.debitAccount} — ${row.debitAccountName}' : row.debitAccount,
                      row.creditAccountName.isNotEmpty
                          ? '${row.creditAccount} — ${row.creditAccountName}'
                          : row.creditAccount,
                      row.statement.isNotEmpty ? row.statement : row.notes,
                      app.ledgerKindLabel(row.kind),
                    ],
                ],
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                _LedgerPager(
                  page: window.page,
                  pageCount: window.pageCount,
                  start: window.start,
                  end: window.end,
                  total: rows.length,
                  pageSize: pageSize,
                  onPage: app.setLedgerPage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LedgerPager extends StatelessWidget {
  const _LedgerPager({
    required this.page,
    required this.pageCount,
    required this.start,
    required this.end,
    required this.total,
    required this.pageSize,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final int start;
  final int end;
  final int total;
  final int pageSize;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        Text(
          'عرض ${start + 1}–$end من $total · $pageSize في الصفحة',
          style: muted,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: page > 0 ? () => onPage(page - 1) : null,
                child: const Text('السابق'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${page + 1} / $pageCount',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: FilledButton(
                onPressed: page < pageCount - 1 ? () => onPage(page + 1) : null,
                child: const Text('التالي'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.onPick});

  final String label;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) {
          final m = picked.month.toString().padLeft(2, '0');
          final d = picked.day.toString().padLeft(2, '0');
          onPick('${picked.year}-$m-$d');
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.isEmpty ? '—' : value),
      ),
    );
  }
}
