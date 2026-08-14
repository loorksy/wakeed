import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/remittance_parser.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class SubmitOverlay extends StatelessWidget {
  const SubmitOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final data = app.lastDialog;
    if (data == null) return const SizedBox.shrink();
    if (data.phase == SubmitPhase.confirm) {
      return const _ProfitConfirmSheet();
    }
    final loading = data.phase == SubmitPhase.loading;
    final success = data.phase == SubmitPhase.success;
    final color = loading
        ? WakeedColors.accent
        : success
            ? WakeedColors.green
            : WakeedColors.err;
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (loading)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(success ? Icons.check_circle : Icons.error, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(data.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      if (data.message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(data.message),
                      ],
                      if (data.details.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: Text(data.details, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ),
                      ],
                      if (!loading) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: app.clearDialog,
                            child: const Text('إغلاق'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfitConfirmSheet extends StatelessWidget {
  const _ProfitConfirmSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final diff = app.pendingConfirmProfit;
    final count = app.pendingConfirmCount;
    final isProfit = diff > 0.001;
    final isLoss = diff < -0.001;
    final color = isProfit
        ? WakeedColors.green
        : isLoss
            ? WakeedColors.err
            : Theme.of(context).textTheme.bodyMedium?.color ?? WakeedColors.accent;
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profitKindLabel(diff),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatProfitSigned(diff),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1.05,
                        ),
                      ),
                      if (count > 1) ...[
                        const SizedBox(height: 4),
                        Text('$count سندات', style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (app.pendingConfirmFor.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          app.pendingConfirmFor,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: app.cancelPendingSubmit,
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: app.confirmPendingSubmit,
                              child: const Text('تأكيد'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
