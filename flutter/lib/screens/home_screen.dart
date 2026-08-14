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
import '../widgets/common.dart';
import '../widgets/preview_table.dart';
import '../widgets/settings_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final index = switch (app.createTab) {
      'each' => 1,
      'manual' => 2,
      'charge' => 3,
      'ledger' => 4,
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
      body: index == 4
          ? const LedgerTab()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                const SettingsCard(),
                const SizedBox(height: 12),
                if (index == 0) const BatchTab(),
                if (index == 1) const EachTab(),
                if (index == 2) const ManualTab(),
                if (index == 3) const ChargeTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          app.setTab(['batch', 'each', 'manual', 'charge', 'ledger'][i]);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'جماعي'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'لكل عميل'),
          const NavigationDestination(icon: Icon(Icons.edit_note), label: 'فردي'),
          const NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'شحن'),
          NavigationDestination(
            icon: Badge(
              label: Text('${app.ownerLedger().length}'),
              isLabelVisible: app.ownerLedger().isNotEmpty,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            label: 'السجل',
          ),
        ],
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
    final t = app.totals(rows);
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
          Row(
            children: [
              StatChip(label: 'عملاء', value: '${(rows.length / 2).ceil()}'),
              const SizedBox(width: 6),
              StatChip(label: 'أسطر', value: '${rows.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'مدين', value: '${t['debit']}', color: WakeedColors.pink),
              const SizedBox(width: 6),
              StatChip(label: 'دائن', value: '${t['credit']}', color: WakeedColors.green),
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
                  rows[i].debit,
                  rows[i].credit,
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
    final t = app.totals(rows);
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
          row.debit,
          row.credit,
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
          Row(
            children: [
              StatChip(label: 'سندات', value: '${groups.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'عملاء', value: '${groups.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'مدين', value: '${t['debit']}', color: WakeedColors.pink),
              const SizedBox(width: 6),
              StatChip(label: 'دائن', value: '${t['credit']}', color: WakeedColors.green),
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
    final t = app.totals(rows);
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
          row.debit,
          row.credit,
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
          Row(
            children: [
              StatChip(label: 'سندات', value: '${groups.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'مدين', value: '${t['debit']}', color: WakeedColors.pink),
              const SizedBox(width: 6),
              StatChip(label: 'دائن', value: '${t['credit']}', color: WakeedColors.green),
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
    final app = context.read<AppController>();
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..credit = creditCtrl.text
      ..note = noteCtrl.text;
    app.updateManualEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
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
                child: TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ', hintText: '1500'),
                  onChanged: (_) => _sync(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: creditCtrl,
                  decoration: const InputDecoration(labelText: 'الدائن', hintText: '9830'),
                  onChanged: (_) => _sync(),
                ),
              ),
              IconButton(
                tooltip: 'اختر',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.credit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined),
              ),
            ],
          ),
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
    final t = app.totals(rows);
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
          row.debit,
          row.credit,
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
          Row(
            children: [
              StatChip(label: 'سندات', value: '${groups.length}'),
              const SizedBox(width: 6),
              StatChip(label: 'مدين', value: '${t['debit']}', color: WakeedColors.pink),
              const SizedBox(width: 6),
              StatChip(label: 'دائن', value: '${t['credit']}', color: WakeedColors.green),
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
    final app = context.read<AppController>();
    widget.entry
      ..name = nameCtrl.text
      ..amount = amountCtrl.text
      ..debit = debitCtrl.text
      ..credit = creditCtrl.text
      ..note = noteCtrl.text;
    app.updateChargeEntry(widget.entry);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
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
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ', hintText: '1500'),
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: debitCtrl,
                  decoration: const InputDecoration(labelText: 'المدين', hintText: 'رمز الحساب'),
                  onChanged: (_) => _sync(),
                ),
              ),
              IconButton(
                tooltip: 'اختر المدين',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeDebit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: creditCtrl,
                  decoration: const InputDecoration(labelText: 'الدائن', hintText: 'رمز الحساب'),
                  onChanged: (_) => _sync(),
                ),
              ),
              IconButton(
                tooltip: 'اختر الدائن',
                onPressed: () => showAccountPicker(context, target: AccountPickTarget.chargeCredit(widget.entry.id)),
                icon: const Icon(Icons.account_tree_outlined),
              ),
            ],
          ),
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
