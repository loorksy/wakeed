import 'package:flutter/material.dart';

import '../core/remittance_parser.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class FxAmountField extends StatelessWidget {
  const FxAmountField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.debit = false,
    this.symbol = '',
    this.hintText = 'المبلغ',
    this.labelText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool debit;
  final String symbol;
  final String hintText;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final color = debit ? WakeedColors.err : WakeedColors.green;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 12, height: 1.2, color: color),
      decoration: partyFieldDecoration(
        debit: debit,
        base: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        hintText: hintText,
        labelText: labelText,
        suffixIcon: symbol.trim().isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 6, right: 4),
                child: Text(
                  symbol,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      onChanged: onChanged,
    );
  }
}

class JournalFxSummary extends StatelessWidget {
  const JournalFxSummary({
    super.key,
    required this.rows,
    required this.symbol,
    this.leading = const [],
  });

  final List<JournalRow> rows;
  final String symbol;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final fx = fxTotals(rows);
    final hasFx = (fx['fx'] ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading.isNotEmpty) ...[
          Row(children: leading),
          const SizedBox(height: 6),
        ],
        if (hasFx) ...[
          ProfitFxBar(
            diff: fx['diff'] ?? 0,
            creditBase: fx['creditBase'] ?? 0,
            debitBase: fx['debitBase'] ?? 0,
            symbol: symbol,
          ),
          const SizedBox(height: 4),
          Text(
            'المبالغ بعملة كل حساب — الفرق حسب تسعيرة وكيد',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else
          Row(
            children: [
              StatChip(label: 'مدين', value: '${fx['debit'] ?? 0}', color: WakeedColors.err),
              const SizedBox(width: 6),
              StatChip(label: 'دائن', value: '${fx['credit'] ?? 0}', color: WakeedColors.green),
            ],
          ),
      ],
    );
  }
}
