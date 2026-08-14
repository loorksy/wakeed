import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class SubmitDialog extends StatelessWidget {
  const SubmitDialog({super.key, required this.data, required this.onClose});

  final DialogData data;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final loading = data.phase == SubmitPhase.loading;
    final success = data.phase == SubmitPhase.success;
    final color = loading
        ? WakeedColors.accent
        : success
            ? WakeedColors.green
            : WakeedColors.err;
    return AlertDialog(
      title: Row(
        children: [
          if (loading)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(success ? Icons.check_circle : Icons.error, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(data.title, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.message.isNotEmpty) Text(data.message),
            if (data.details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(data.details, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        if (!loading) FilledButton(onPressed: onClose, child: const Text('إغلاق')),
      ],
    );
  }
}

Future<void> showAppDialog(BuildContext context, AppController app) async {
  final data = app.lastDialog;
  if (data == null) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: data.phase != SubmitPhase.loading,
    builder: (ctx) => SubmitDialog(
      data: data,
      onClose: () {
        Navigator.of(ctx).pop();
        app.clearDialog();
      },
    ),
  );
}
