import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/json_util.dart';
import '../models/models.dart';
import '../state/app_controller.dart';

Future<void> showAccountPicker(BuildContext context, {required AccountPickTarget target}) async {
  final app = context.read<AppController>();
  app.accountPickTarget = target;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _AccountPickerSheet(),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet();

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final title = app.accountPickTarget.type == 'debit' ? 'دليل الحسابات — المدين' : 'دليل الحسابات — الدائن';
    final list = app.filteredAccounts(query);
    final shown = list.take(120).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'رمز أو اسم', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => query = v),
                  onSubmitted: (v) {
                    final first = app.filteredAccounts(v);
                    if (first.isNotEmpty) _pick(app, pickAccountCode(first.first));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    list.isEmpty ? 'لا توجد نتائج' : 'عرض ${shown.length} من ${list.length} حساب',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('لا توجد حسابات مطابقة.'))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final acc = shown[i];
                          final code = pickAccountCode(acc);
                          final name = accountNameOf(acc);
                          final active = code == app.debitAccount && app.accountPickTarget.type == 'debit';
                          return ListTile(
                            selected: active,
                            title: Text(code, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(name),
                            onTap: () => _pick(app, code),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pick(AppController app, String code) {
    final target = app.accountPickTarget;
    if (target.type == 'credit' && target.entryId != null) {
      final entry = app.manualEntries.firstWhere((e) => e.id == target.entryId);
      entry.credit = code;
      app.updateManualEntry(entry);
    } else {
      app.selectDebitAccount(code);
    }
    Navigator.pop(context);
  }
}
