import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/json_util.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'account_picker.dart';
import 'common.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  static const dense = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
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
                      decoration: dense,
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
                    decoration: dense,
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
                    decoration: dense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _AccountPick(
                  label: 'مدين',
                  value: app.debitAccountLabel(),
                  color: WakeedColors.err,
                  onTap: () => showAccountPicker(context, target: AccountPickTarget.debit()),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AccountPick(
                  label: 'دائن',
                  value: app.creditAccountLabel(),
                  color: WakeedColors.green,
                  onTap: () => showAccountPicker(context, target: AccountPickTarget.defaultCredit()),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _AccountPick(
                  label: 'طرف ثالث',
                  value: app.thirdPartyAccountLabel(),
                  color: WakeedColors.accent,
                  onTap: () => showAccountPicker(context, target: AccountPickTarget.thirdParty()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
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

class _AccountPick extends StatelessWidget {
  const _AccountPick({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: SettingsCard.dense.copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.55)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              suffixIcon: Icon(Icons.account_tree_outlined, size: 16, color: color),
              suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
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
