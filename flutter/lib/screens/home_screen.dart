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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                const SettingsCard(),
                const SizedBox(height: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('سند جماعي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
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
          const DebitAccountField(),
          const Text('البيان'),
          const SizedBox(height: 4),
          TextField(
            controller: notes,
            decoration: const InputDecoration(hintText: 'ملاحظة السند'),
            onChanged: app.setNotesBatch,
          ),
          const SizedBox(height: 4),
          Text(app.notesPreviewText('batch'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          const Text('البيانات'),
          const SizedBox(height: 4),
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
            columns: const ['#', 'البيان', 'حساب', 'مدين', 'دائن', 'محلول'],
            rows: [
              for (var i = 0; i < rows.length; i++)
                [
                  '${i + 1}',
                  app.composeNote(rows[i].description, app.sectionNote('batch')),
                  rows[i].account,
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
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedEach, row.account),
        ]);
      }
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('سند لكل عميل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
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
          const DebitAccountField(),
          const Text('البيان'),
          const SizedBox(height: 4),
          TextField(
            controller: notes,
            decoration: const InputDecoration(hintText: 'ملاحظة السند'),
            onChanged: app.setNotesEach,
          ),
          const SizedBox(height: 4),
          Text(app.notesPreviewText('each'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          const Text('البيانات'),
          const SizedBox(height: 4),
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
            columns: const ['سند', '#', 'البيان', 'حساب', 'مدين', 'دائن', 'محلول'],
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
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedManual, row.account),
        ]);
      }
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('فردي — سند لكل عميل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('${app.manualEntries.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const DebitAccountField(),
          const SizedBox(height: 8),
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
            columns: const ['سند', '#', 'البيان', 'حساب', 'مدين', 'دائن', 'محلول'],
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
  late final TextEditingController creditRateCtrl;
  late final TextEditingController noteCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.entry.name);
    amountCtrl = TextEditingController(text: widget.entry.amount);
    creditCtrl = TextEditingController(text: widget.entry.credit);
    creditRateCtrl = TextEditingController(text: widget.entry.creditRate);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ManualEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (creditRateCtrl.text != widget.entry.creditRate) creditRateCtrl.text = widget.entry.creditRate;
    if (nameCtrl.text != widget.entry.name && widget.entry.name.isEmpty) nameCtrl.clear();
    if (amountCtrl.text != widget.entry.amount && widget.entry.amount.isEmpty) amountCtrl.clear();
    if (noteCtrl.text != widget.entry.note && widget.entry.note.isEmpty) noteCtrl.clear();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    creditCtrl.dispose();
    creditRateCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync({bool accountChanged = false}) {
    final app = context.read<AppController>();
    if (accountChanged) {
      final quote = app.currencyQuoteForAccount(creditCtrl.text);
      creditRateCtrl.text = quote.isBase ? '' : formatProfitAmount(quote.hawalaRate);
    }
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..credit = creditCtrl.text
      ..creditRate = creditRateCtrl.text
      ..note = noteCtrl.text;
    app.updateManualEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
    final debitQ = app.currencyQuoteForAccount(app.debitAccount);
    final amt = num.tryParse(cleanAmount(amountCtrl.text)) ?? 0;
    final cRate = parseHawalaRate(
      creditRateCtrl.text.isNotEmpty ? creditRateCtrl.text : app.defaultHawalaRateFor(creditCtrl.text),
    );
    final dRate = parseHawalaRate(
      app.debitHawalaRate.isNotEmpty ? app.debitHawalaRate : app.defaultHawalaRateFor(app.debitAccount),
    );
    final creditBase = amountToBase(amt, cRate);
    final debitBase = amountToBase(amountFromBase(creditBase, dRate), dRate);
    final mixed = !creditQ.isBase || !debitQ.isBase;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('سند ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: app.manualEntries.length > 1 ? () => app.removeManualEntry(widget.entry.id) : null,
                child: const Text('حذف'),
              ),
            ],
          ),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم', hintText: 'اسم العميل'),
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
                  onChanged: () => _sync(accountChanged: true),
                ),
              ),
              IconButton(
                tooltip: 'اختر',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.credit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.green),
              ),
            ],
          ),
          if (!creditQ.isBase && creditCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            FxRateField(
              controller: creditRateCtrl,
              code: creditQ.code,
              onChanged: (_) => _sync(),
            ),
          ],
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
            decoration: const InputDecoration(labelText: 'البيان', hintText: 'ملاحظة هذا العميل'),
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
          formatJournalAmount(row, debit: true),
          formatJournalAmount(row, debit: false),
          app.resolvedLabel(app.resolvedCharge, row.account),
        ]);
      }
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('شحن — سند لكل عملية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('${app.chargeEntries.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اختر المدين والدائن لكل سند. لا يستخدم الحساب الافتراضي.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
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
            columns: const ['سند', '#', 'البيان', 'حساب', 'مدين', 'دائن', 'محلول'],
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
  late final TextEditingController debitRateCtrl;
  late final TextEditingController creditCtrl;
  late final TextEditingController creditRateCtrl;
  late final TextEditingController noteCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.entry.name);
    amountCtrl = TextEditingController(text: widget.entry.amount);
    debitCtrl = TextEditingController(text: widget.entry.debit);
    debitRateCtrl = TextEditingController(text: widget.entry.debitRate);
    creditCtrl = TextEditingController(text: widget.entry.credit);
    creditRateCtrl = TextEditingController(text: widget.entry.creditRate);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ChargeEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (debitCtrl.text != widget.entry.debit) debitCtrl.text = widget.entry.debit;
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (debitRateCtrl.text != widget.entry.debitRate) debitRateCtrl.text = widget.entry.debitRate;
    if (creditRateCtrl.text != widget.entry.creditRate) creditRateCtrl.text = widget.entry.creditRate;
    if (nameCtrl.text != widget.entry.name && widget.entry.name.isEmpty) nameCtrl.clear();
    if (amountCtrl.text != widget.entry.amount && widget.entry.amount.isEmpty) amountCtrl.clear();
    if (noteCtrl.text != widget.entry.note && widget.entry.note.isEmpty) noteCtrl.clear();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    debitCtrl.dispose();
    debitRateCtrl.dispose();
    creditCtrl.dispose();
    creditRateCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync({bool debitChanged = false, bool creditChanged = false}) {
    final app = context.read<AppController>();
    if (debitChanged) {
      final quote = app.currencyQuoteForAccount(debitCtrl.text);
      debitRateCtrl.text = quote.isBase ? '' : formatProfitAmount(quote.hawalaRate);
    }
    if (creditChanged) {
      final quote = app.currencyQuoteForAccount(creditCtrl.text);
      creditRateCtrl.text = quote.isBase ? '' : formatProfitAmount(quote.hawalaRate);
    }
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..debit = debitCtrl.text
      ..debitRate = debitRateCtrl.text
      ..credit = creditCtrl.text
      ..creditRate = creditRateCtrl.text
      ..note = noteCtrl.text;
    app.updateChargeEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final debitQ = app.currencyQuoteForAccount(debitCtrl.text);
    final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
    final amt = num.tryParse(cleanAmount(amountCtrl.text)) ?? 0;
    final cRate = parseHawalaRate(
      creditRateCtrl.text.isNotEmpty ? creditRateCtrl.text : app.defaultHawalaRateFor(creditCtrl.text),
    );
    final dRate = parseHawalaRate(
      debitRateCtrl.text.isNotEmpty ? debitRateCtrl.text : app.defaultHawalaRateFor(debitCtrl.text),
    );
    final creditBase = amountToBase(amt, cRate);
    final debitBase = amountToBase(amountFromBase(creditBase, dRate), dRate);
    final mixed = !creditQ.isBase || !debitQ.isBase;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('سند ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: app.chargeEntries.length > 1 ? () => app.removeChargeEntry(widget.entry.id) : null,
                child: const Text('حذف'),
              ),
            ],
          ),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'الاسم', hintText: 'اسم العميل'),
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
                  onChanged: () => _sync(debitChanged: true),
                  debit: true,
                ),
              ),
              IconButton(
                tooltip: 'اختر المدين',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeDebit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.err),
              ),
            ],
          ),
          if (!debitQ.isBase && debitCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            FxRateField(
              controller: debitRateCtrl,
              debit: true,
              code: debitQ.code,
              onChanged: (_) => _sync(),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AccountNameField(
                  controller: creditCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: () => _sync(creditChanged: true),
                ),
              ),
              IconButton(
                tooltip: 'اختر الدائن',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeCredit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined, color: WakeedColors.green),
              ),
            ],
          ),
          if (!creditQ.isBase && creditCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            FxRateField(
              controller: creditRateCtrl,
              code: creditQ.code,
              onChanged: (_) => _sync(),
            ),
          ],
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
            decoration: const InputDecoration(labelText: 'البيان', hintText: 'ملاحظة هذا السند'),
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
    final groups = profitLedgerGroups(rows);
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
            return name.isNotEmpty ? name : rows[i].account;
          }(),
          _profitAmountCell(rows[i].debit, rows[i]),
          _profitAmountCell(rows[i].credit, rows[i]),
          app.resolvedLabel(app.resolvedProfit, rows[i].account),
        ],
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سند ربحي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
          const SizedBox(height: 10),
          if (app.profitMode != 'each') ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    app.profitMode == 'split' ? 'لصق جماعي — سند منفصل لكل سطر' : 'لصق الدائن والمدين',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
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
            if (app.profitMode == 'split') ...[
              const SizedBox(height: 4),
              Text(
                'الصق كل السندات دفعة واحدة. عند الإنشاء يُسجَّل كل سطر سنداً منفصلاً في وكيد.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            const Text('البيان'),
            const SizedBox(height: 4),
            TextField(
              controller: notes,
              decoration: InputDecoration(
                hintText: app.profitMode == 'split' ? 'ملاحظة تُضاف لكل سند' : 'ملاحظة السند',
              ),
              onChanged: app.setNotesProfit,
            ),
            const SizedBox(height: 8),
            const Text('البيانات'),
            const SizedBox(height: 4),
            TextField(
              controller: data,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(hintText: 'الدائن\tمبلغ الدائن\tالمدين\tمبلغ المدين'),
              onChanged: app.setTableProfit,
            ),
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text('فردي — سند لكل بطاقة', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${app.profitEntries.length}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'أدخل الدائن ومبلغه والمدين ومبلغه في كل بطاقة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
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
          Text(
            'سندات ${groups.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ProfitFxBar(
            diff: profit,
            creditBase: pt['creditBase'] ?? pt['credit'] ?? 0,
            debitBase: pt['debitBase'] ?? pt['debit'] ?? 0,
            symbol: app.baseCurrencyQuote().symbol,
          ),
          if ((pt['fx'] ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Text(
              'الفرق بالدولار حسب تسعيرة الحساب',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          PreviewTable(
            columns: const ['سند', '#', 'البيان', 'حساب', 'مدين', 'دائن', 'محلول'],
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
  late final TextEditingController creditRateCtrl;
  late final TextEditingController debitCtrl;
  late final TextEditingController debitAmtCtrl;
  late final TextEditingController debitRateCtrl;
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
    creditRateCtrl = TextEditingController(text: widget.entry.creditRate);
    debitCtrl = TextEditingController(text: widget.entry.debit);
    debitAmtCtrl = TextEditingController(text: widget.entry.debitAmount);
    debitRateCtrl = TextEditingController(text: widget.entry.debitRate);
    noteCtrl = TextEditingController(text: widget.entry.note);
  }

  @override
  void didUpdateWidget(covariant _ProfitEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (creditCtrl.text != widget.entry.credit) creditCtrl.text = widget.entry.credit;
    if (debitCtrl.text != widget.entry.debit) debitCtrl.text = widget.entry.debit;
    if (creditRateCtrl.text != widget.entry.creditRate) creditRateCtrl.text = widget.entry.creditRate;
    if (debitRateCtrl.text != widget.entry.debitRate) debitRateCtrl.text = widget.entry.debitRate;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fillMissingRates();
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    creditCtrl.dispose();
    creditAmtCtrl.dispose();
    creditRateCtrl.dispose();
    debitCtrl.dispose();
    debitAmtCtrl.dispose();
    debitRateCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  void _sync({bool creditAccountChanged = false, bool debitAccountChanged = false}) {
    final app = context.read<AppController>();
    if (creditAccountChanged) {
      final creditQ = app.currencyQuoteForAccount(creditCtrl.text);
      creditRateCtrl.text = creditQ.isBase ? '' : formatProfitAmount(creditQ.hawalaRate);
    }
    if (debitAccountChanged) {
      final debitQ = app.currencyQuoteForAccount(debitCtrl.text);
      debitRateCtrl.text = debitQ.isBase ? '' : formatProfitAmount(debitQ.hawalaRate);
    }
    widget.entry
      ..name = nameCtrl.text
      ..credit = creditCtrl.text
      ..creditAmount = creditAmtCtrl.text
      ..creditRate = creditRateCtrl.text
      ..debit = debitCtrl.text
      ..debitAmount = debitAmtCtrl.text
      ..debitRate = debitRateCtrl.text
      ..note = noteCtrl.text;
    app.updateProfitEntry(widget.entry);
  }

  void _fillMissingRates() {
    final app = context.read<AppController>();
    var changed = false;
    if (creditCtrl.text.trim().isNotEmpty && creditRateCtrl.text.isEmpty) {
      final quote = app.currencyQuoteForAccount(creditCtrl.text);
      if (!quote.isBase) {
        creditRateCtrl.text = formatProfitAmount(quote.hawalaRate);
        widget.entry.creditRate = creditRateCtrl.text;
        changed = true;
      }
    }
    if (debitCtrl.text.trim().isNotEmpty && debitRateCtrl.text.isEmpty) {
      final quote = app.currencyQuoteForAccount(debitCtrl.text);
      if (!quote.isBase) {
        debitRateCtrl.text = formatProfitAmount(quote.hawalaRate);
        widget.entry.debitRate = debitRateCtrl.text;
        changed = true;
      }
    }
    if (changed) app.updateProfitEntry(widget.entry);
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

  Widget _rateField({
    required TextEditingController controller,
    required bool debit,
    required String code,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: debit ? WakeedColors.err : WakeedColors.green,
      ),
      decoration: partyFieldDecoration(
        debit: debit,
        base: _dense,
        hintText: 'سعر الصرف',
        labelText: code.isEmpty ? 'سعر الصرف' : 'سعر $code',
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
    final cRate = parseHawalaRate(creditRateCtrl.text);
    final dRate = parseHawalaRate(debitRateCtrl.text);
    final creditBase = amountToBase(c, cRate);
    final debitBase = amountToBase(d, dRate);
    final profit = roundMoney(debitBase - creditBase);
    final debitWho = app.chartAccountName(debitCtrl.text);
    final baseSymbol = app.baseCurrencyQuote().symbol;
    return Container(
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
              Text('سند ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 8),
              if (c > 0 || d > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profitKindLabel(profit)} ${formatProfitSigned(profit)} $baseSymbol',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: profit > 0.001
                            ? WakeedColors.green
                            : profit < -0.001
                                ? WakeedColors.err
                                : WakeedColors.accent,
                      ),
                    ),
                    if (debitWho.isNotEmpty)
                      Text(
                        debitWho,
                        style: TextStyle(
                          fontSize: 11,
                          color: profit > 0.001
                              ? WakeedColors.green
                              : profit < -0.001
                                  ? WakeedColors.err
                                  : WakeedColors.accent,
                        ),
                      ),
                  ],
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
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
                  onChanged: () => _sync(creditAccountChanged: true),
                  dense: true,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
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
          if (!creditQ.isBase && creditCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _rateField(controller: creditRateCtrl, debit: false, code: creditQ.code),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AccountNameField(
                  controller: debitCtrl,
                  fallbackLabel: 'الحساب',
                  onChanged: () => _sync(debitAccountChanged: true),
                  dense: true,
                  debit: true,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
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
          if (!debitQ.isBase && debitCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _rateField(controller: debitRateCtrl, debit: true, code: debitQ.code),
          ],
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
