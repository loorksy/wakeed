// Literal Dart port of `parser.js` (wakeed / wakeed2).
// Template: الاسم | المبلغ | الدائن
// defaultDebit from UI, defaultCredit = 9830.

String cleanAmount(dynamic v) {
  final t = (v ?? '')
      .toString()
      .replaceAll(',', '')
      .replaceAll('٫', '')
      .trim();
  if (t.isEmpty) return '';
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return '';
  return t;
}

bool isAccount(dynamic v) {
  final t = (v ?? '').toString().trim();
  return RegExp(r'^\d{2,}([-/]\S*)?$').hasMatch(t);
}

String parseSide(dynamic v) {
  final t = (v ?? '').toString().trim();
  if (RegExp(r'^دائن|credit$', caseSensitive: false).hasMatch(t)) return 'credit';
  if (RegExp(r'^مدين|debit$', caseSensitive: false).hasMatch(t)) return 'debit';
  return '';
}

class JournalRow {
  JournalRow({
    required this.account,
    required this.description,
    required this.debit,
    required this.credit,
    this.clientNote = '',
  });

  String account;
  String description;
  String debit;
  String credit;
  String clientNote;

  JournalRow copy() => JournalRow(
        account: account,
        description: description,
        debit: debit,
        credit: credit,
        clientNote: clientNote,
      );

  Map<String, dynamic> toMap() => {
        'account': account,
        'description': description,
        'debit': debit,
        'credit': credit,
        'clientNote': clientNote,
      };
}

class CustomerGroup {
  CustomerGroup({required this.name, required this.rows});

  final String name;
  final List<JournalRow> rows;
}

void pushLine(
  List<JournalRow> rows,
  dynamic name,
  dynamic acc,
  dynamic amount,
  String side,
) {
  final amt = cleanAmount(amount);
  if (amt.isEmpty || name == null || name.toString().isEmpty) return;
  if (side == 'credit') {
    rows.add(JournalRow(
      account: acc?.toString() ?? '',
      description: name.toString(),
      debit: '',
      credit: amt,
    ));
  } else {
    rows.add(JournalRow(
      account: acc?.toString() ?? '',
      description: name.toString(),
      debit: amt,
      credit: '',
    ));
  }
}

List<JournalRow> parseRowsFromTable(
  dynamic text, [
  String defaultDebitAcc = '555',
  String defaultCreditAcc = '9830',
]) {
  final raw = (text ?? '').toString().replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  if (raw.isEmpty) return [];
  final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return [];

  final delim = lines[0].contains('\t')
      ? '\t'
      : lines[0].contains(';')
          ? ';'
          : ',';
  List<String> split(String line) => line
      .split(delim)
      .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), ''))
      .toList();

  final firstRow = split(lines[0]);
  final headerRe = RegExp(
    r'حساب|بيان|عميل|مدين|دائن|مبلغ|نوع|account|customer|name|debit|credit|type',
    caseSensitive: false,
  );
  final hasHeader = firstRow.any((h) => headerRe.hasMatch(h));
  final startIdx = hasHeader ? 1 : 0;
  final rows = <JournalRow>[];
  final pending = <Map<String, dynamic>>[];

  for (var i = startIdx; i < lines.length; i++) {
    final rawCells = split(lines[i]);
    final cells = <String>[];
    for (var idx = 0; idx < rawCells.length; idx++) {
      final c = rawCells[idx];
      if (c.isNotEmpty || idx < rawCells.length - 1) cells.add(c);
    }
    if (!cells.any((c) => c.isNotEmpty)) continue;

    if (cells.length >= 6) {
      final dName = cells[0];
      final dAcc = cells[1].isNotEmpty ? cells[1] : defaultDebitAcc;
      final dVal = cleanAmount(cells[2]);
      final cName = cells[3].isNotEmpty ? cells[3] : dName;
      final cAcc = cells[4].isNotEmpty ? cells[4] : defaultCreditAcc;
      final cVal = cleanAmount(cells[5]).isNotEmpty ? cleanAmount(cells[5]) : dVal;
      if (dVal.isNotEmpty) {
        rows.add(JournalRow(account: dAcc, description: dName, debit: dVal, credit: ''));
      }
      if (cVal.isNotEmpty) {
        rows.add(JournalRow(account: cAcc, description: cName, debit: '', credit: cVal));
      }
      continue;
    }

    if (cells.length == 5) {
      final name = cells[0];
      final dAcc = cells[1].isNotEmpty ? cells[1] : defaultDebitAcc;
      final dVal = cleanAmount(cells[2]);
      final cAcc = cells[3].isNotEmpty ? cells[3] : defaultCreditAcc;
      final cVal = cleanAmount(cells[4]).isNotEmpty ? cleanAmount(cells[4]) : dVal;
      if (dVal.isNotEmpty) {
        rows.add(JournalRow(account: dAcc, description: name, debit: dVal, credit: ''));
      }
      if (cVal.isNotEmpty) {
        rows.add(JournalRow(account: cAcc, description: name, debit: '', credit: cVal));
      }
      continue;
    }

    if (cells.length == 4) {
      final side = parseSide(cells[3]);
      if (side.isNotEmpty && isAccount(cells[1]) && cleanAmount(cells[2]).isNotEmpty) {
        pushLine(rows, cells[0], cells[1], cells[2], side);
        continue;
      }
      if (isAccount(cells[0])) {
        final dVal = cleanAmount(cells[2]);
        final cVal = cleanAmount(cells[3]);
        rows.add(JournalRow(
          account: cells[0],
          description: cells[1],
          debit: dVal,
          credit: cVal,
        ));
        continue;
      }
      final dVal = cleanAmount(cells[2]);
      final cVal = cleanAmount(cells[3]);
      rows.add(JournalRow(
        account: isAccount(cells[1])
            ? cells[1]
            : (dVal.isNotEmpty ? defaultDebitAcc : defaultCreditAcc),
        description: cells[0],
        debit: dVal,
        credit: cVal,
      ));
      continue;
    }

    if (cells.length == 3) {
      final name = cells[0];
      final amt = cleanAmount(cells[1]);
      final creditAcc = cells[2].trim();
      if (amt.isNotEmpty && creditAcc.isNotEmpty) {
        rows.add(JournalRow(
          account: defaultDebitAcc,
          description: name,
          debit: amt,
          credit: '',
        ));
        rows.add(JournalRow(
          account: creditAcc,
          description: name,
          debit: '',
          credit: amt,
        ));
        continue;
      }
      continue;
    }

    if (cells.length == 2) {
      final name = cells[0];
      final amt = cleanAmount(cells[1]);
      if (amt.isNotEmpty) {
        rows.add(JournalRow(
          account: defaultDebitAcc,
          description: name,
          debit: amt,
          credit: '',
        ));
        rows.add(JournalRow(
          account: defaultCreditAcc,
          description: name,
          debit: '',
          credit: amt,
        ));
      }
    }
  }

  for (var i = 0; i < pending.length; i += 2) {
    final a = pending[i];
    final b = i + 1 < pending.length ? pending[i + 1] : null;
    pushLine(rows, a['name'], a['acc'], a['amt'], 'debit');
    if (b != null) pushLine(rows, b['name'], b['acc'], b['amt'], 'credit');
  }

  return rows;
}

List<CustomerGroup> groupCustomerRows(List<JournalRow>? rows) {
  final groups = <CustomerGroup>[];
  final list = rows ?? [];
  for (var i = 0; i < list.length; i += 2) {
    final pair = list.sublist(i, i + 2 > list.length ? list.length : i + 2);
    if (pair.length < 2) continue;
    groups.add(CustomerGroup(
      name: pair[0].description.isNotEmpty ? pair[0].description : pair[1].description,
      rows: pair,
    ));
  }
  return groups;
}

final String sheetTemplate = [
  ['الاسم', 'المبلغ', 'الدائن'],
  ['احمد الاحمد', '1500', '9830'],
  ['محمد الاحمد', '2000', '9830'],
  ['خالد الخالد', '3500', '9830'],
].map((row) => row.join('\t')).join('\n');
