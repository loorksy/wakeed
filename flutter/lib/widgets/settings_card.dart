import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/json_util.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import 'account_picker.dart';
import 'common.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الإعدادات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (app.createTab == 'profit') ...[
          const Text('حساب الربح / تسوية الفرق', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () => showAccountPicker(context, target: AccountPickTarget.profit()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              alignment: Alignment.centerRight,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(app.profitAccountLabel(), overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(onPressed: app.saveProfitDefault, child: const Text('حفظ افتراضي')),
              Text(app.profitDefaultHint(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ] else if (app.createTab != 'charge') ...[
          const Text('حساب المدين', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: () => showAccountPicker(context, target: AccountPickTarget.debit()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              alignment: Alignment.centerRight,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(app.debitAccountLabel(), overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(onPressed: app.saveDebitDefault, child: const Text('حفظ افتراضي')),
              Text(app.debitDefaultHint(), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _Labeled(
                  label: 'التاريخ',
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.tryParse(app.entryDate) ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        final m = picked.month.toString().padLeft(2, '0');
                        final d = picked.day.toString().padLeft(2, '0');
                        app.setEntryDate('${picked.year}-$m-$d');
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Text(app.entryDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Labeled(
                  label: 'نوع السند',
                  child: DropdownButtonFormField<String>(
                    value: app.journalTypes.any((t) => pickId(t) == app.journalTypeId)
                        ? app.journalTypeId
                        : null,
                    items: [
                      for (final t in app.journalTypes)
                        DropdownMenuItem(value: pickId(t), child: Text(pickName(t).isEmpty ? pickId(t) : pickName(t))),
                    ],
                    onChanged: (v) {
                      if (v != null) app.setJournalType(v);
                    },
                    isExpanded: true,
                    decoration: const InputDecoration(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Labeled(
            label: 'مركز الكلفة',
            child: DropdownButtonFormField<String>(
              value: app.costCenters.any((c) => c['Id'].toString() == app.costCenterId) ? app.costCenterId : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('بدون / الافتراضي')),
                for (final c in app.costCenters)
                  DropdownMenuItem(value: c['Id'].toString(), child: Text((c['label'] ?? '').toString())),
              ],
              onChanged: (v) => app.setCostCenter(v ?? ''),
              isExpanded: true,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('حساب مقابل', style: TextStyle(fontSize: 13)),
                  value: app.useOpposite,
                  onChanged: app.setUseOpposite,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('مركز كلفة', style: TextStyle(fontSize: 13)),
                  value: app.includeCostCenter,
                  onChanged: app.setIncludeCostCenter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
