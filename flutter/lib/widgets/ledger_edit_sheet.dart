import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'account_picker.dart';

Future<void> showLedgerEditSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _LedgerEditSheet(),
  );
}

class _LedgerEditSheet extends StatefulWidget {
  const _LedgerEditSheet();

  @override
  State<_LedgerEditSheet> createState() => _LedgerEditSheetState();
}

class _LedgerEditSheetState extends State<_LedgerEditSheet> {
  String debitCode = '';
  String creditCode = '';
  String thirdPartyCode = '';

  Future<void> _pick(String side) async {
    final title = switch (side) {
      'debit' => 'دليل الحسابات — المدين',
      'credit' => 'دليل الحسابات — الدائن',
      _ => 'دليل الحسابات — الطرف الثالث',
    };
    final tone = switch (side) {
      'debit' => WakeedColors.err,
      'credit' => WakeedColors.green,
      _ => WakeedColors.accent,
    };
    final code = await chooseAccount(context, title: title, tone: tone);
    if (code == null || code.isEmpty || !mounted) return;
    setState(() {
      if (side == 'debit') debitCode = code;
      if (side == 'credit') creditCode = code;
      if (side == 'third') thirdPartyCode = code;
    });
  }

  String _label(AppController app, String code, String empty) {
    if (code.isEmpty) return empty;
    final name = app.chartAccountName(code);
    return name.isEmpty ? code : '$code — $name';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final count = app.selectedLedgerEntries().length;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              count <= 1 ? 'تعديل حسابات سند واحد' : 'تعديل حسابات $count سندات',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'اترك الحقل فارغاً إن لم ترد تغييره. لا يُحفظ أي حساب كافتراضي. التعديل يُطبَّق في وكيد وعلى السجل.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _AccountRow(
              label: 'المدين',
              value: _label(app, debitCode, 'بدون تغيير'),
              color: WakeedColors.err,
              onPick: () => _pick('debit'),
              onClear: debitCode.isEmpty ? null : () => setState(() => debitCode = ''),
            ),
            const SizedBox(height: 8),
            _AccountRow(
              label: 'الدائن',
              value: _label(app, creditCode, 'بدون تغيير'),
              color: WakeedColors.green,
              onPick: () => _pick('credit'),
              onClear: creditCode.isEmpty ? null : () => setState(() => creditCode = ''),
            ),
            const SizedBox(height: 8),
            _AccountRow(
              label: 'طرف ثالث',
              value: _label(app, thirdPartyCode, 'بدون تغيير'),
              color: WakeedColors.accent,
              onPick: () => _pick('third'),
              onClear: thirdPartyCode.isEmpty ? null : () => setState(() => thirdPartyCode = ''),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: app.ledgerBusy
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await app.updateSelectedLedgerAccounts(
                              debitCode: debitCode,
                              creditCode: creditCode,
                              thirdPartyCode: thirdPartyCode,
                            );
                          },
                    child: const Text('تطبيق في وكيد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'مسح',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
          const Icon(Icons.account_tree_outlined),
        ],
      ),
    );
  }
}
