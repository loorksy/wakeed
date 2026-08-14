import 'package:flutter/material.dart';

import '../core/remittance_parser.dart';
import '../theme/app_theme.dart';

class WakeedMark extends StatelessWidget {
  const WakeedMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WakeedColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: WakeedColors.accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        'و',
        style: TextStyle(
          fontSize: size * 0.48,
          fontWeight: FontWeight.w800,
          color: WakeedColors.accent,
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.14) ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color?.withValues(alpha: 0.55) ?? Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color ?? muted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfitFxBar extends StatelessWidget {
  const ProfitFxBar({
    super.key,
    required this.diff,
    required this.creditBase,
    required this.debitBase,
    this.symbol = '\$',
    this.compact = false,
  });

  final num diff;
  final num creditBase;
  final num debitBase;
  final String symbol;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact ? const EdgeInsets.symmetric(horizontal: 6, vertical: 5) : const EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    final valueSize = compact ? 13.0 : 16.0;
    final labelSize = compact ? 9.0 : 11.0;
    Widget box(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: labelSize, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ),
      );
    }

    final unit = symbol.trim().isEmpty ? '' : ' $symbol';
    final diffColor = diff < -0.001 ? WakeedColors.err : diff > 0.001 ? WakeedColors.green : WakeedColors.err;
    return Row(
      children: [
        box('مدين', '${formatProfitAmount(debitBase)}$unit', WakeedColors.pink),
        const SizedBox(width: 6),
        box('دائن', '${formatProfitAmount(creditBase)}$unit', WakeedColors.green),
        const SizedBox(width: 6),
        box('فرق', '${formatProfitSigned(diff)}$unit', diffColor),
      ],
    );
  }
}
