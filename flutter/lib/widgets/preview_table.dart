import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PreviewTable extends StatelessWidget {
  const PreviewTable({super.key, required this.columns, required this.rows, this.emptyText = '—'});

  final List<String> columns;
  final List<List<String>> rows;
  final String emptyText;

  Color? _toneFor(String column) {
    if (column == 'مدين') return WakeedColors.err;
    if (column == 'دائن') return WakeedColors.green;
    return null;
  }

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
        columns: [
          for (final c in columns)
            DataColumn(
              label: Text(
                c,
                style: TextStyle(color: _toneFor(c), fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (var i = 0; i < r.length; i++)
                  DataCell(
                    SizedBox(
                      width: 110,
                      child: Text(
                        r[i],
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 12,
                          color: i < columns.length ? _toneFor(columns[i]) : null,
                          fontWeight: i < columns.length && _toneFor(columns[i]) != null ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
