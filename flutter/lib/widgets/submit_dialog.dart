import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final loading = data.phase == SubmitPhase.loading;
    final success = data.phase == SubmitPhase.success;
    final confirm = data.phase == SubmitPhase.confirm;
    final color = loading || confirm
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
                            Icon(
                              confirm
                                  ? Icons.balance
                                  : success
                                      ? Icons.check_circle
                                      : Icons.error,
                              color: color,
                            ),
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
                        if (confirm)
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
                                  child: const Text('تأكيد الإنشاء'),
                                ),
                              ),
                            ],
                          )
                        else
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
