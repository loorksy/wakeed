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
          _AccountPickRow(app: app),
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

class _AccountPickRow extends StatelessWidget {
  const _AccountPickRow({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final profit = app.createTab == 'profit';
    final showDebit = profit ? app.profitMode == 'each' : true;
    final showCredit = profit && app.profitMode == 'each';
    final debitCode = app.preferredDebitCode().isNotEmpty ? app.preferredDebitCode() : app.debitAccount;
    final creditCode = app.preferredCreditCode().isNotEmpty ? app.preferredCreditCode() : app.creditAccount;
    final thirdCode = app.preferredThirdPartyCode();
    final picks = <Widget>[
      if (showDebit)
        _AccountPick(
          label: 'مدين',
          code: debitCode,
          name: app.chartAccountName(debitCode),
          color: WakeedColors.err,
          onTap: () => showAccountPicker(context, target: AccountPickTarget.debit()),
        ),
      if (showCredit)
        _AccountPick(
          label: 'دائن',
          code: creditCode,
          name: app.chartAccountName(creditCode),
          color: WakeedColors.green,
          onTap: () => showAccountPicker(context, target: AccountPickTarget.defaultCredit()),
        ),
      _AccountPick(
        label: 'طرف ثالث',
        code: thirdCode,
        name: app.chartAccountName(thirdCode),
        color: WakeedColors.accent,
        onTap: () => showAccountPicker(context, target: AccountPickTarget.thirdParty()),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < picks.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: picks[i]),
        ],
      ],
    );
  }
}

class _AccountPick extends StatelessWidget {
  const _AccountPick({
    required this.label,
    required this.code,
    required this.name,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String code;
  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, height: 1.1)),
        const SizedBox(height: 2),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: SettingsCard.dense.copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.55)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              suffixIcon: Icon(Icons.account_tree_outlined, size: 13, color: color),
              suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
            child: code.isEmpty
                ? Text(
                    'اختر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color.withValues(alpha: 0.55), fontSize: 9, height: 1.15),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, height: 1.1),
                      ),
                      if (name.isNotEmpty)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 8, fontWeight: FontWeight.w500, height: 1.15),
                        ),
                    ],
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
