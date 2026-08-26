import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

/// Account code field that shows the chart name instead of دائن/مدين.
class AccountNameField extends StatefulWidget {
  const AccountNameField({
    super.key,
    required this.controller,
    required this.fallbackLabel,
    required this.onChanged,
    this.dense = false,
    this.debit = false,
  });

  final TextEditingController controller;
  final String fallbackLabel;
  final VoidCallback onChanged;
  final bool dense;
  final bool debit;

  @override
  State<AccountNameField> createState() => _AccountNameFieldState();
}

class _AccountNameFieldState extends State<AccountNameField> {
  final _focus = FocusNode();
  final _display = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_syncDisplay);
    widget.controller.addListener(_syncDisplay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDisplay();
    });
  }

  @override
  void didUpdateWidget(covariant AccountNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncDisplay);
      widget.controller.addListener(_syncDisplay);
    }
    _syncDisplay();
  }

  @override
  void dispose() {
    _focus.removeListener(_syncDisplay);
    widget.controller.removeListener(_syncDisplay);
    _focus.dispose();
    _display.dispose();
    super.dispose();
  }

  void _syncDisplay() {
    if (!mounted) return;
    final name = context.read<AppController>().chartAccountName(widget.controller.text);
    final next = _focus.hasFocus
        ? widget.controller.text
        : (name.isNotEmpty ? name : widget.controller.text);
    if (_display.text != next) {
      _display.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppController>().chartAccountName(widget.controller.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDisplay();
    });
    final dense = widget.dense
        ? const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6))
        : const InputDecoration();
    final color = widget.debit ? WakeedColors.err : WakeedColors.green;
    return TextField(
      controller: _display,
      focusNode: _focus,
      style: TextStyle(fontSize: 10, height: 1.15, color: color),
      decoration: partyFieldDecoration(
        debit: widget.debit,
        base: dense,
        labelText: name.isNotEmpty && _focus.hasFocus ? name : null,
        hintText: name.isEmpty ? widget.fallbackLabel : null,
      ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.auto),
      onChanged: (value) {
        if (!_focus.hasFocus) return;
        widget.controller.text = value;
        widget.onChanged();
      },
    );
  }
}
