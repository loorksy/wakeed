import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/json_util.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import 'account_picker.dart';
import 'common.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  static const _dense = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final showDebit = app.createTab != 'charge' && app.createTab != 'profit';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        children: [
          Row(
            children: [
              if (showDebit) ...[
                Expanded(
                  flex: 2,
                  child: _Box(
                    label: 'المدين',
                    child: InkWell(
                      onTap: () => showAccountPicker(context, target: AccountPickTarget.debit()),
                      child: InputDecorator(
                        decoration: _dense.copyWith(
                          suffixIcon: const Icon(Icons.account_tree_outlined, size: 16),
                          suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        child: Text(
                          app.debitAccountLabel(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _Box(
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
                      decoration: _dense,
                      child: Text(app.entryDate, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Box(
                  label: 'نوع السند',
                  child: DropdownButtonFormField<String>(
                    value: app.journalTypes.any((t) => pickId(t) == app.journalTypeId)
                        ? app.journalTypeId
                        : null,
                    items: [
                      for (final t in app.journalTypes)
                        DropdownMenuItem(
                          value: pickId(t),
                          child: Text(
                            pickName(t).isEmpty ? pickId(t) : pickName(t),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) app.setJournalType(v);
                    },
                    isExpanded: true,
                    isDense: true,
                    decoration: _dense,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Box(
                  label: 'مركز الكلفة',
                  child: DropdownButtonFormField<String>(
                    value: app.costCenters.any((c) => c['Id'].toString() == app.costCenterId)
                        ? app.costCenterId
                        : '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('بدون', style: TextStyle(fontSize: 12)),
                      ),
                      for (final c in app.costCenters)
                        DropdownMenuItem(
                          value: c['Id'].toString(),
                          child: Text(
                            (c['label'] ?? '').toString(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (v) => app.setCostCenter(v ?? ''),
                    isExpanded: true,
                    isDense: true,
                    decoration: _dense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (showDebit)
                TextButton(
                  onPressed: app.saveDebitDefault,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('حفظ افتراضي', style: TextStyle(fontSize: 12)),
                ),
              const Spacer(),
              _MiniSwitch(
                label: 'مقابل',
                value: app.useOpposite,
                onChanged: app.setUseOpposite,
              ),
              const SizedBox(width: 8),
              _MiniSwitch(
                label: 'كلفة',
                value: app.includeCostCenter,
                onChanged: app.setIncludeCostCenter,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Transform.scale(
          scale: 0.78,
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
