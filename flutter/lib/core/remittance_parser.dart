import 'dart:math' as math;

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
    this.groupKey = '',
    this.balancing = false,
    this.currencyId = '',
    this.currencyCode = '',
    this.currencySymbol = '',
    this.rate = '',
  });

  String account;
  String description;
  String debit;
  String credit;
  String clientNote;
  String groupKey;
  bool balancing;
  String currencyId;
  String currencyCode;
  String currencySymbol;
  String rate;

  JournalRow copy() => JournalRow(
        account: account,
        description: description,
        debit: debit,
        credit: credit,
        clientNote: clientNote,
        groupKey: groupKey,
        balancing: balancing,
        currencyId: currencyId,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
        rate: rate,
      );

  Map<String, dynamic> toMap() => {
        'account': account,
        'description': description,
        'debit': debit,
        'credit': credit,
        'clientNote': clientNote,
        'groupKey': groupKey,
        'balancing': balancing,
        'currencyId': currencyId,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'rate': rate,
      };
}

class CurrencyQuote {
  const CurrencyQuote({
    this.id = '',
    this.code = '',
    this.symbol = '',
    this.hawalaRate = 1,
    this.isBase = true,
  });

  final String id;
  final String code;
  final String symbol;
  final num hawalaRate;
  final bool isBase;

  static const usd = CurrencyQuote(code: 'USD', symbol: '\$', hawalaRate: 1, isBase: true);

  String get badge => symbol.trim().isNotEmpty ? symbol : (code.trim().isNotEmpty ? code : '');
}

num roundMoney(num n, [int digits = 2]) {
  final p = math.pow(10, digits);
  return (n * p).round() / p;
}

num hawalaRateFromApi(num apiRate, {bool isBase = false}) {
  if (isBase) return 1;
  final r = apiRate == 0 ? 1 : apiRate;
  if ((r - 1).abs() < 0.0000001) return 1;
  if (r < 1) return 1 / r;
  return r;
}

num parseHawalaRate(String? raw) {
  final t = (raw ?? '').toString().replaceAll(',', '').replaceAll('٫', '').trim();
  if (t.isEmpty) return 1;
  final n = num.tryParse(t) ?? 1;
  return n <= 0 ? 1 : n;
}

num amountToBase(num amount, num hawalaRate, {int decimals = 2}) {
  if (amount == 0) return 0;
  final rate = hawalaRate <= 0 ? 1 : hawalaRate;
  final base = (rate - 1).abs() < 0.0000001 ? amount : amount / rate;
  return roundMoney(base, decimals);
}

num hawalaPostRate(num hawalaRate) {
  if (hawalaRate <= 0 || (hawalaRate - 1).abs() < 0.0000001) return 1;
  return 1 / hawalaRate;
}

String currencySymbolFor(String code, [String apiSymbol = '']) {
  if (apiSymbol.trim().isNotEmpty) return apiSymbol.trim();
  switch (code.toUpperCase()) {
    case 'USD':
    case 'US':
      return '\$';
    case 'TRY':
    case 'TL':
    case 'TRL':
      return 'T';
    case 'EUR':
      return '€';
    case 'SYP':
      return 'ل.س';
    default:
      return code;
  }
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

class ProfitPasteRow {
  ProfitPasteRow({
    required this.name,
    required this.credit,
    required this.creditAmount,
    required this.debit,
    required this.debitAmount,
    this.note = '',
    this.debitRate = '',
    this.creditRate = '',
    this.debitCurrencyId = '',
    this.creditCurrencyId = '',
    this.debitCurrencyCode = '',
    this.creditCurrencyCode = '',
    this.debitCurrencySymbol = '',
    this.creditCurrencySymbol = '',
    this.baseCurrencyId = '',
    this.baseCurrencyCode = '',
    this.baseCurrencySymbol = '',
  });

  final String name;
  final String credit;
  final String creditAmount;
  final String debit;
  final String debitAmount;
  final String note;
  final String debitRate;
  final String creditRate;
  final String debitCurrencyId;
  final String creditCurrencyId;
  final String debitCurrencyCode;
  final String creditCurrencyCode;
  final String debitCurrencySymbol;
  final String creditCurrencySymbol;
  final String baseCurrencyId;
  final String baseCurrencyCode;
  final String baseCurrencySymbol;

  bool get isComplete =>
      credit.trim().isNotEmpty &&
      debit.trim().isNotEmpty &&
      cleanAmount(creditAmount).isNotEmpty &&
      cleanAmount(debitAmount).isNotEmpty;
}

String formatProfitAmount(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  var s = n.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

List<String> _profitSplitLine(String line, String delim) => line
    .split(delim)
    .map((c) => c.trim().replaceAll(RegExp(r'^"|"$'), ''))
    .toList();

List<ProfitPasteRow> parseProfitTable(dynamic text) {
  final raw = (text ?? '').toString().replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  if (raw.isEmpty) return [];
  final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return [];

  final delim = lines[0].contains('\t')
      ? '\t'
      : lines[0].contains(';')
          ? ';'
          : ',';
  final firstRow = _profitSplitLine(lines[0], delim);
  final headerRe = RegExp(
    r'حساب|بيان|اسم|عميل|مدين|دائن|مبلغ|account|customer|name|debit|credit',
    caseSensitive: false,
  );
  final hasHeader = firstRow.any((h) => headerRe.hasMatch(h));
  final startIdx = hasHeader ? 1 : 0;
  final rows = <ProfitPasteRow>[];

  for (var i = startIdx; i < lines.length; i++) {
    final rawCells = _profitSplitLine(lines[i], delim);
    final cells = <String>[];
    for (var idx = 0; idx < rawCells.length; idx++) {
      final c = rawCells[idx];
      if (c.isNotEmpty || idx < rawCells.length - 1) cells.add(c);
    }
    if (!cells.any((c) => c.isNotEmpty)) continue;

    if (cells.length >= 6) {
      final cName = cells[0];
      final cAcc = cells[1];
      final cVal = cleanAmount(cells[2]);
      final dName = cells[3];
      final dAcc = cells[4];
      final dVal = cleanAmount(cells[5]);
      final name = dName.isNotEmpty ? dName : cName;
      if (cAcc.isEmpty || dAcc.isEmpty || cVal.isEmpty || dVal.isEmpty) continue;
      rows.add(ProfitPasteRow(
        name: name,
        credit: cAcc,
        creditAmount: cVal,
        debit: dAcc,
        debitAmount: dVal,
      ));
      continue;
    }

    if (cells.length == 5) {
      final name = cells[0];
      final cAcc = cells[1];
      final cVal = cleanAmount(cells[2]);
      final dAcc = cells[3];
      final dVal = cleanAmount(cells[4]);
      if (cAcc.isEmpty || dAcc.isEmpty || cVal.isEmpty || dVal.isEmpty) continue;
      rows.add(ProfitPasteRow(
        name: name,
        credit: cAcc,
        creditAmount: cVal,
        debit: dAcc,
        debitAmount: dVal,
      ));
      continue;
    }

    if (cells.length >= 4) {
      final cAcc = cells[0];
      final cVal = cleanAmount(cells[1]);
      final dAcc = cells[2];
      final dVal = cleanAmount(cells[3]);
      if (cAcc.isEmpty || dAcc.isEmpty || cVal.isEmpty || dVal.isEmpty) continue;
      rows.add(ProfitPasteRow(
        name: '$cAcc / $dAcc',
        credit: cAcc,
        creditAmount: cVal,
        debit: dAcc,
        debitAmount: dVal,
      ));
    }
  }

  return rows;
}

String formatProfitSigned(num diff) {
  final abs = formatProfitAmount(diff.abs());
  if (diff < -0.001) return '$abs-';
  return abs;
}

String profitKindLabel(num diff) {
  if (diff > 0.001) return 'ربح';
  if (diff < -0.001) return 'كسر';
  return 'فرق';
}

String profitForLabel(num diff, String who) {
  final name = who.trim();
  if (name.isEmpty || diff.abs() <= 0.001) return '';
  return diff < 0 ? 'على $name' : 'لصالح $name';
}

List<JournalRow> buildProfitJournalRows(List<ProfitPasteRow> items) {
  final rows = <JournalRow>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (!item.isComplete) continue;
    final dAmt = cleanAmount(item.debitAmount);
    final cAmt = cleanAmount(item.creditAmount);
    final name = item.name.trim().isNotEmpty ? item.name.trim() : '${item.credit} / ${item.debit}';
    final key = 'p$i';
    final note = item.note.trim();
    final dRate = parseHawalaRate(item.debitRate);
    final cRate = parseHawalaRate(item.creditRate);
    rows.add(JournalRow(
      account: item.debit.trim(),
      description: name,
      debit: dAmt,
      credit: '',
      clientNote: note,
      groupKey: key,
      currencyId: item.debitCurrencyId,
      currencyCode: item.debitCurrencyCode,
      currencySymbol: item.debitCurrencySymbol,
      rate: item.debitRate,
    ));
    rows.add(JournalRow(
      account: item.credit.trim(),
      description: name,
      debit: '',
      credit: cAmt,
      clientNote: note,
      groupKey: key,
      currencyId: item.creditCurrencyId,
      currencyCode: item.creditCurrencyCode,
      currencySymbol: item.creditCurrencySymbol,
      rate: item.creditRate,
    ));
    final debitVal = num.tryParse(dAmt) ?? 0;
    final creditVal = num.tryParse(cAmt) ?? 0;
    final profit = roundMoney(amountToBase(debitVal, dRate) - amountToBase(creditVal, cRate));
    if (profit.abs() <= 0.001) continue;
    final settleSymbol = item.baseCurrencySymbol.trim().isNotEmpty
        ? item.baseCurrencySymbol
        : (item.debitCurrencySymbol.trim().isNotEmpty ? item.debitCurrencySymbol : '\$');
    final settleCode = item.baseCurrencyCode.trim().isNotEmpty
        ? item.baseCurrencyCode
        : item.debitCurrencyCode;
    final settleId = item.baseCurrencyId.trim().isNotEmpty ? item.baseCurrencyId : item.debitCurrencyId;
    if (profit > 0) {
      rows.add(JournalRow(
        account: item.debit.trim(),
        description: name,
        debit: '',
        credit: formatProfitAmount(profit),
        clientNote: note,
        groupKey: key,
        balancing: true,
        currencyId: settleId,
        currencyCode: settleCode,
        currencySymbol: settleSymbol,
        rate: '1',
      ));
    } else {
      rows.add(JournalRow(
        account: item.debit.trim(),
        description: name,
        debit: formatProfitAmount(-profit),
        credit: '',
        clientNote: note,
        groupKey: key,
        balancing: true,
        currencyId: settleId,
        currencyCode: settleCode,
        currencySymbol: settleSymbol,
        rate: '1',
      ));
    }
  }
  return rows;
}

List<CustomerGroup> groupRowsByKey(List<JournalRow>? rows) {
  final list = rows ?? [];
  final map = <String, List<JournalRow>>{};
  final order = <String>[];
  for (var i = 0; i < list.length; i++) {
    final row = list[i];
    final key = row.groupKey.isNotEmpty ? row.groupKey : 'row-$i';
    if (!map.containsKey(key)) {
      order.add(key);
      map[key] = [];
    }
    map[key]!.add(row);
  }
  return [
    for (final k in order)
      CustomerGroup(
        name: map[k]!.first.description,
        rows: map[k]!,
      ),
  ];
}

List<CustomerGroup> profitLedgerGroups(List<JournalRow>? rows) {
  return groupRowsByKey(rows)
      .where((g) => g.rows.any((r) => !r.balancing))
      .map(
        (g) => CustomerGroup(
          name: g.name,
          rows: g.rows.where((r) => !r.balancing).toList(),
        ),
      )
      .toList();
}

Map<String, num> profitPasteTotals(List<ProfitPasteRow> items) {
  num debit = 0;
  num credit = 0;
  num debitBase = 0;
  num creditBase = 0;
  var count = 0;
  var hasFx = false;
  for (final item in items.where((e) => e.isComplete)) {
    final dAmt = num.tryParse(cleanAmount(item.debitAmount)) ?? 0;
    final cAmt = num.tryParse(cleanAmount(item.creditAmount)) ?? 0;
    final dRate = parseHawalaRate(item.debitRate);
    final cRate = parseHawalaRate(item.creditRate);
    if ((dRate - 1).abs() > 0.0001 || (cRate - 1).abs() > 0.0001) hasFx = true;
    debit += dAmt;
    credit += cAmt;
    debitBase += amountToBase(dAmt, dRate);
    creditBase += amountToBase(cAmt, cRate);
    count += 1;
  }
  debitBase = roundMoney(debitBase);
  creditBase = roundMoney(creditBase);
  return {
    'debit': debit,
    'credit': credit,
    'debitBase': debitBase,
    'creditBase': creditBase,
    'diff': roundMoney(debitBase - creditBase),
    'count': count,
    'fx': hasFx ? 1 : 0,
  };
}

final String profitSheetTemplate = [
  ['الدائن', 'مبلغ الدائن', 'المدين', 'مبلغ المدين'],
  ['9830', '1500', '555', '1200'],
  ['1200', '2000', '555', '1800'],
].map((row) => row.join('\t')).join('\n');
