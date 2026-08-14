import 'dart:typed_data';

import 'package:excel/excel.dart';

Uint8List buildExcelSheet({
  required String sheetName,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetName];
  excel.setDefaultSheet(sheetName);
  for (final name in excel.sheets.keys.where((n) => n != sheetName).toList()) {
    excel.delete(name);
  }
  for (var c = 0; c < headers.length; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
        TextCellValue(headers[c]);
  }
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
      if (v is num) {
        cell.value = DoubleCellValue(v.toDouble());
      } else {
        cell.value = TextCellValue(v?.toString() ?? '');
      }
    }
  }
  final bytes = excel.encode();
  if (bytes == null || bytes.isEmpty) {
    throw Exception('تعذر إنشاء ملف إكسل.');
  }
  return Uint8List.fromList(bytes);
}

String ledgerExcelFileName(List<String> dates) {
  final sorted = dates.where((d) => d.isNotEmpty).toList()..sort();
  final from = sorted.isNotEmpty ? sorted.first : _today();
  final to = sorted.isNotEmpty ? sorted.last : _today();
  return 'سجل-سندات-وكيد-$from-إلى-$to.xlsx';
}

String _today() {
  final d = DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
