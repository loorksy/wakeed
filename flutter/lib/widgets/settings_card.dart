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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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

class DebitAccountField extends StatelessWidget {
  const DebitAccountField({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        'حساب المدين',
                        if (app.currencyQuoteForAccount(app.debitAccount).badge.isNotEmpty)
                          app.currencyQuoteForAccount(app.debitAccount).badge,
                      ].join(' '),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WakeedColors.err),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => showAccountPicker(context, target: AccountPickTarget.debit()),
                      child: InputDecorator(
                        decoration: partyFieldDecoration(
                          debit: true,
                          base: SettingsCard.dense,
                          suffixIcon: Icon(Icons.account_tree_outlined, size: 18, color: WakeedColors.err),
                          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        child: Text(
                          app.debitAccountLabel(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: WakeedColors.err, fontSize: 12),
                        ),
                      ),
                    ),
                    ThirdPartyCaption(accountCode: app.debitAccount),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: app.saveDebitDefault,
                child: const Text('حفظ افتراضي'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CreditAccountField extends StatelessWidget {
  const CreditAccountField({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              'حساب الدائن',
              if (app.currencyQuoteForAccount(app.creditAccount).badge.isNotEmpty)
                app.currencyQuoteForAccount(app.creditAccount).badge,
            ].join(' '),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WakeedColors.green),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => showAccountPicker(context, target: AccountPickTarget.defaultCredit()),
            child: InputDecorator(
              decoration: partyFieldDecoration(
                debit: false,
                base: SettingsCard.dense,
                suffixIcon: Icon(Icons.account_tree_outlined, size: 18, color: WakeedColors.green),
                suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              child: Text(
                app.creditAccountLabel(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WakeedColors.green, fontSize: 12),
              ),
            ),
          ),
          ThirdPartyCaption(accountCode: app.creditAccount),
        ],
      ),
    );
  }
}

class DefaultAccountsCard extends StatelessWidget {
  const DefaultAccountsCard({super.key, this.title = 'حسابات افتراضية — سند فردي'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              'يُعبَّأ المدين والدائن تلقائياً في السند الجديد، ويظهر الطرف الثالث من وكيد.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const DebitAccountField(),
            const CreditAccountField(),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: app.savePartyDefaults,
                child: const Text('حفظ المدين والدائن كافتراضي'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThirdPartyCaption extends StatelessWidget {
  const ThirdPartyCaption({super.key, required this.accountCode});

  final String accountCode;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final label = app.thirdPartyLabelFor(accountCode);
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'طرف ثالث: $label',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: WakeedColors.accent),
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
