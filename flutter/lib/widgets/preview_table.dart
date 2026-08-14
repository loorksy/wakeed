import 'package:flutter/material.dart';

class PreviewTable extends StatelessWidget {
  const PreviewTable({super.key, required this.columns, required this.rows, this.emptyText = '—'});

  final List<String> columns;
  final List<List<String>> rows;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 56,
        columnSpacing: 14,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(fontSize: 12),
        columns: [for (final c in columns) DataColumn(label: Text(c))],
        rows: [
          for (final r in rows)
            DataRow(cells: [for (final c in r) DataCell(SizedBox(width: 110, child: Text(c, maxLines: 3)))]),
        ],
      ),
    );
  }
}
