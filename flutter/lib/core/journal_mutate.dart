import '../models/models.dart';
import 'json_util.dart';

class LedgerAccountPatch {
  const LedgerAccountPatch({
    this.debitId = '',
    this.debitCode = '',
    this.debitName = '',
    this.creditId = '',
    this.creditCode = '',
    this.creditName = '',
    this.thirdPartyId = '',
    this.thirdPartyCode = '',
    this.thirdPartyName = '',
  });

  final String debitId;
  final String debitCode;
  final String debitName;
  final String creditId;
  final String creditCode;
  final String creditName;
  final String thirdPartyId;
  final String thirdPartyCode;
  final String thirdPartyName;

  bool get hasDebit => debitId.isNotEmpty || debitCode.isNotEmpty;
  bool get hasCredit => creditId.isNotEmpty || creditCode.isNotEmpty;
  bool get hasThirdParty => thirdPartyId.isNotEmpty || thirdPartyCode.isNotEmpty;
  bool get isEmpty => !hasDebit && !hasCredit && !hasThirdParty;
}

class ClassifiedVoucher {
  ClassifiedVoucher({
    required this.name,
    required this.amount,
    required this.debitLine,
    required this.creditLine,
    this.thirdPartyLine,
  });

  final String name;
  final num amount;
  final Map<String, dynamic> debitLine;
  final Map<String, dynamic> creditLine;
  final Map<String, dynamic>? thirdPartyLine;

  String get debitId => detailAccountId(debitLine);
  String get debitName => detailAccountName(debitLine);
  String get creditId => detailAccountId(creditLine);
  String get creditName => detailAccountName(creditLine);

  String get thirdPartyId {
    if (thirdPartyLine != null) {
      final id = detailAccountId(thirdPartyLine!);
      if (id.isNotEmpty) return id;
    }
    final fromCredit = pickDetailThirdPartyId(creditLine);
    if (fromCredit.isNotEmpty) return fromCredit;
    return pickDetailThirdPartyId(debitLine);
  }

  String get thirdPartyName {
    if (thirdPartyLine != null) {
      final name = detailAccountName(thirdPartyLine!);
      if (name.isNotEmpty) return name;
    }
    final fromCredit = pickDetailThirdPartyName(creditLine);
    if (fromCredit.isNotEmpty) return fromCredit;
    return pickDetailThirdPartyName(debitLine);
  }
}

String ledgerRowIdentity(LedgerEntry row) {
  return '${row.name.trim()}|${numOf(row.amount)}|${row.entryDate}';
}

String journalGroupKey(LedgerEntry row) {
  if (row.journalId.trim().isNotEmpty) return row.journalId.trim();
  return '';
}

Map<String, List<LedgerEntry>> groupLedgerByJournal(List<LedgerEntry> rows) {
  final out = <String, List<LedgerEntry>>{};
  for (final row in rows) {
    out.putIfAbsent(journalGroupKey(row), () => []).add(row);
  }
  return out;
}

bool isWakeedJournalId(String id) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(id.trim());
}

String skippedNamesText(Iterable<String> names) {
  return names.map((n) => n.trim()).where((n) => n.isNotEmpty).join('\n');
}

bool isGenericJournalNote(String notes) {
  final t = notes.trim();
  if (t.isEmpty) return true;
  return RegExp(r'^(سند(\s*(حوالة|ربحي|شحن))?|حوالة|profit)$', caseSensitive: false).hasMatch(t);
}

List<Map<String, dynamic>> journalDetailMaps(dynamic journal) {
  if (journal is! Map) return const [];
  final raw = journal['journalEntryDetails'] ?? journal['JournalEntryDetails'];
  return [
    for (final item in asList(raw))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

void setJournalDetails(Map journal, List<Map<String, dynamic>> details) {
  final copied = [for (final detail in details) Map<String, dynamic>.from(detail)];
  journal['journalEntryDetails'] = copied;
  journal['JournalEntryDetails'] = copied;
}

num detailDebit(Map detail) => numOf(detail['debit'] ?? detail['Debit']);

num detailCredit(Map detail) => numOf(detail['credit'] ?? detail['Credit']);

num _detailAmount(Map detail) {
  final credit = detailCredit(detail);
  if (credit > 0) return credit;
  return detailDebit(detail);
}

String _detailNotes(Map detail) {
  return (detail['notes'] ?? detail['Notes'] ?? '').toString().trim();
}

Map? _nestedAccount(Map detail) {
  for (final key in ['normalAccount', 'NormalAccount', 'account', 'Account']) {
    final nested = detail[key];
    if (nested is Map) return nested;
  }
  return null;
}

String detailAccountId(Map detail) {
  final v = detail['normalAccountId'] ??
      detail['NormalAccountId'] ??
      detail['AccountID'] ??
      detail['accountID'] ??
      detail['AccountId'];
  if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  final nested = _nestedAccount(detail);
  return nested == null ? '' : pickId(nested);
}

String detailAccountCode(Map detail) {
  final v = detail['accountCode'] ?? detail['AccountCode'] ?? detail['code'] ?? detail['Code'];
  if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  final nested = _nestedAccount(detail);
  return nested == null ? '' : pickAccountCode(nested);
}

String detailAccountName(Map detail) {
  final v = detail['accountName'] ?? detail['AccountName'];
  if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
  final nested = _nestedAccount(detail);
  return nested == null ? '' : accountNameOf(nested);
}

bool _notesMatchName(String notes, String name) {
  final n = notes.trim();
  final nm = name.trim();
  if (nm.isEmpty) return false;
  if (n == nm) return true;
  if (n.startsWith('$nm ') || n.startsWith('$nm-') || n.startsWith('$nm—') || n.startsWith('$nm|')) {
    return true;
  }
  if (n.endsWith(' $nm') || n.endsWith('-$nm') || n.endsWith('—$nm')) return true;
  return false;
}

bool detailMatchesLedger(Map detail, LedgerEntry entry) {
  if (!_notesMatchName(_detailNotes(detail), entry.name) && !isGenericJournalNote(_detailNotes(detail))) {
    return false;
  }
  if (!_notesMatchName(_detailNotes(detail), entry.name)) return false;
  final amount = _detailAmount(detail);
  if (amount > 0 && (numOf(entry.amount) - amount).abs() > 0.001) return false;
  return true;
}

bool voucherMatchesEntry(ClassifiedVoucher voucher, LedgerEntry entry) {
  final sameName = voucher.name.trim() == entry.name.trim() ||
      _notesMatchName(voucher.name, entry.name) ||
      _notesMatchName(entry.name, voucher.name);
  if (!sameName) return false;
  if (entry.amount == 0 || voucher.amount == 0) return true;
  return (numOf(entry.amount) - voucher.amount).abs() < 0.001;
}

bool selectedCoversWholeJournal(List<LedgerEntry> inJournal, List<LedgerEntry> selected) {
  if (inJournal.isEmpty) return selected.isNotEmpty;
  final keys = selected.map(ledgerRowIdentity).toSet();
  return inJournal.every((row) => keys.contains(ledgerRowIdentity(row)));
}

String _voucherName(Map debit, Map credit, String fallbackName) {
  for (final raw in [_detailNotes(credit), _detailNotes(debit), fallbackName]) {
    final name = raw.trim();
    if (name.isNotEmpty && !isGenericJournalNote(name)) return name;
  }
  final fallback = fallbackName.trim();
  return fallback.isEmpty ? 'سند' : fallback;
}

bool _groupHasBothSides(List<Map<String, dynamic>> group) {
  return group.any((l) => detailDebit(l) > 0) && group.any((l) => detailCredit(l) > 0);
}

int detailOrder(Map detail) {
  final v = detail['orderInJournal'] ?? detail['OrderInJournal'] ?? detail['order'] ?? detail['Order'];
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

List<ClassifiedVoucher> classifyJournalVouchers(List<Map> lines) {
  final maps = <Map<String, dynamic>>[
    for (final line in lines) line is Map<String, dynamic> ? line : Map<String, dynamic>.from(line),
  ];
  if (maps.isEmpty) return const [];

  final byNotes = <String, List<Map<String, dynamic>>>{};
  for (final line in maps) {
    byNotes.putIfAbsent(_detailNotes(line), () => []).add(line);
  }

  final remittance = <String, List<Map<String, dynamic>>>{};
  final leftover = <Map<String, dynamic>>[];
  byNotes.forEach((note, group) {
    if (isGenericJournalNote(note) || !_groupHasBothSides(group)) {
      leftover.addAll(group);
    } else {
      remittance[note] = group;
    }
  });

  if (remittance.isEmpty) {
    return _attachLeftoverThirdPartyLines(_vouchersFromLines(leftover, fallbackName: 'سند'), leftover);
  }
  if (remittance.length == 1) {
    final name = remittance.keys.first;
    final genericOnly = [
      for (final line in leftover)
        if (isGenericJournalNote(_detailNotes(line))) line,
    ];
    final namedLeftover = [
      for (final line in leftover)
        if (!isGenericJournalNote(_detailNotes(line))) line,
    ];
    final vouchers = _vouchersFromLines([...remittance[name]!, ...genericOnly], fallbackName: name);
    return _attachLeftoverThirdPartyLines(vouchers, namedLeftover);
  }

  final out = <ClassifiedVoucher>[];
  for (final entry in remittance.entries) {
    out.addAll(_vouchersFromLines(entry.value, fallbackName: entry.key));
  }
  return _attachLeftoverThirdPartyLines(out, leftover);
}

List<ClassifiedVoucher> _attachLeftoverThirdPartyLines(
  List<ClassifiedVoucher> vouchers,
  List<Map<String, dynamic>> leftover,
) {
  if (vouchers.isEmpty || leftover.isEmpty) return vouchers;
  final used = <Map>{
    for (final voucher in vouchers) ...[voucher.debitLine, voucher.creditLine, if (voucher.thirdPartyLine != null) voucher.thirdPartyLine!],
  };
  final extras = [for (final line in leftover) if (!used.contains(line)) line];
  if (extras.isEmpty) return vouchers;

  final missing = [for (final voucher in vouchers) if (voucher.thirdPartyLine == null) voucher];
  if (missing.isEmpty) return vouchers;

  Map<String, dynamic>? takeFor(ClassifiedVoucher voucher, List<Map<String, dynamic>> pool) {
    if (pool.isEmpty) return null;
    final byNotes = [
      for (final line in pool)
        if (_notesMatchName(_detailNotes(line), voucher.name)) line,
    ];
    if (byNotes.length == 1) {
      pool.remove(byNotes.first);
      return byNotes.first;
    }
    final generic = [
      for (final line in pool)
        if (isGenericJournalNote(_detailNotes(line))) line,
    ];
    if (generic.length == 1 && (pool.length == 1 || missing.length == 1)) {
      pool.remove(generic.first);
      return generic.first;
    }
    if (pool.length == 1 && missing.length == 1) {
      return pool.removeAt(0);
    }
    final debitOrder = detailOrder(voucher.debitLine);
    var bestI = 0;
    var best = 1 << 30;
    for (var i = 0; i < pool.length; i++) {
      final diff = (detailOrder(pool[i]) - debitOrder).abs();
      if (diff < best) {
        best = diff;
        bestI = i;
      }
    }
    return pool.removeAt(bestI);
  }

  final pool = [...extras]..sort((a, b) => detailOrder(a).compareTo(detailOrder(b)));
  return [
    for (final voucher in vouchers)
      if (voucher.thirdPartyLine != null)
        voucher
      else
        ClassifiedVoucher(
          name: voucher.name,
          amount: voucher.amount,
          debitLine: voucher.debitLine,
          creditLine: voucher.creditLine,
          thirdPartyLine: takeFor(voucher, pool),
        ),
  ];
}

bool lineMatchesThirdParty(Map line, LedgerEntry entry, {String currentId = ''}) {
  final id = detailAccountId(line);
  final code = detailAccountCode(line);
  final name = detailAccountName(line);
  if (currentId.isNotEmpty && id == currentId) return true;
  if (entry.thirdPartyAccount.isNotEmpty) {
    final key = entry.thirdPartyAccount.trim();
    if (code == key || id == key) return true;
  }
  if (entry.thirdPartyAccountName.isNotEmpty) {
    final wanted = entry.thirdPartyAccountName.trim();
    if (name == wanted || _notesMatchName(name, wanted) || _notesMatchName(_detailNotes(line), wanted)) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic>? findThirdPartyLine(
  List<Map<String, dynamic>> details,
  ClassifiedVoucher voucher,
  LedgerEntry entry, {
  String currentId = '',
}) {
  if (voucher.thirdPartyLine != null) return voucher.thirdPartyLine;
  final used = {voucher.debitLine, voucher.creditLine};
  final byAccount = [
    for (final line in details)
      if (!used.contains(line) && lineMatchesThirdParty(line, entry, currentId: currentId)) line,
  ];
  if (byAccount.length == 1) return byAccount.first;
  if (byAccount.length > 1) {
    final named = [
      for (final line in byAccount)
        if (_notesMatchName(_detailNotes(line), voucher.name) || _notesMatchName(_detailNotes(line), entry.name))
          line,
    ];
    if (named.isNotEmpty) return named.first;
    return byAccount.first;
  }
  if (details.length == 3) {
    for (final line in details) {
      if (!used.contains(line)) return line;
    }
  }
  final unused = [
    for (final line in details)
      if (!used.contains(line)) line,
  ];
  if (unused.length == 1) return unused.first;
  return null;
}

List<ClassifiedVoucher> _vouchersFromLines(
  List<Map<String, dynamic>> lines, {
  required String fallbackName,
}) {
  final debits = lines.where((l) => detailDebit(l) > 0).toList();
  final credits = lines.where((l) => detailCredit(l) > 0).toList();
  if (debits.isEmpty || credits.isEmpty) return const [];

  final unusedD = [...debits];
  final unusedC = [...credits];
  final pairs = <({Map<String, dynamic> d, Map<String, dynamic> c})>[];

  bool takeEqual() {
    for (var i = 0; i < unusedD.length; i++) {
      for (var j = 0; j < unusedC.length; j++) {
        if ((detailDebit(unusedD[i]) - detailCredit(unusedC[j])).abs() < 0.001) {
          pairs.add((d: unusedD.removeAt(i), c: unusedC.removeAt(j)));
          return true;
        }
      }
    }
    return false;
  }

  while (takeEqual()) {}
  while (unusedD.isNotEmpty && unusedC.isNotEmpty) {
    var bestI = 0;
    var bestJ = 0;
    num best = double.infinity;
    for (var i = 0; i < unusedD.length; i++) {
      for (var j = 0; j < unusedC.length; j++) {
        final diff = (detailDebit(unusedD[i]) - detailCredit(unusedC[j])).abs();
        if (diff < best) {
          best = diff;
          bestI = i;
          bestJ = j;
        }
      }
    }
    pairs.add((d: unusedD.removeAt(bestI), c: unusedC.removeAt(bestJ)));
  }

  final paired = <Map>{for (final p in pairs) p.d, for (final p in pairs) p.c};
  final leftover = [for (final line in lines) if (!paired.contains(line)) line];
  final sharedThird = leftover.length == 1 ? leftover.first : null;

  return [
    for (final pair in pairs)
      ClassifiedVoucher(
        name: _voucherName(pair.d, pair.c, fallbackName),
        amount: detailCredit(pair.c) > 0 ? detailCredit(pair.c) : detailDebit(pair.d),
        debitLine: pair.d,
        creditLine: pair.c,
        thirdPartyLine: sharedThird,
      ),
  ];
}

void applyAccountFields(
  Map<String, dynamic> detail, {
  required String id,
  String name = '',
  String code = '',
}) {
  if (id.isNotEmpty) {
    detail['normalAccountId'] = id;
    detail['NormalAccountId'] = id;
    detail['AccountID'] = id;
    detail['accountID'] = id;
    detail['AccountId'] = id;
  }
  if (name.isNotEmpty) {
    detail['accountName'] = name;
    detail['AccountName'] = name;
  }
  if (code.isNotEmpty) {
    detail['accountCode'] = code;
    detail['AccountCode'] = code;
    detail['Code'] = code;
    detail['code'] = code;
  }
  for (final key in ['normalAccount', 'NormalAccount', 'account', 'Account']) {
    final nested = detail[key];
    if (nested is! Map) continue;
    final child = Map<String, dynamic>.from(nested);
    if (id.isNotEmpty) {
      child['id'] = id;
      child['Id'] = id;
    }
    if (name.isNotEmpty) {
      child['accountName'] = name;
      child['AccountName'] = name;
      child['name'] = name;
      child['Name'] = name;
    }
    if (code.isNotEmpty) {
      child['accountCode'] = code;
      child['AccountCode'] = code;
      child['code'] = code;
      child['Code'] = code;
    }
    detail[key] = child;
  }
}

void applyThirdPartyFields(Map<String, dynamic> detail, AccountThirdParty party) {
  if (party.id.isEmpty && party.code.isEmpty) return;
  if (party.id.isNotEmpty) {
    detail['correspondingAccountID'] = party.id;
    detail['CorrespondingAccountID'] = party.id;
    detail['correspondingAccountId'] = party.id;
    detail['CorrespondingAccountId'] = party.id;
    detail['oppositeAccountID'] = party.id;
    detail['OppositeAccountID'] = party.id;
    detail['oppositeAccountId'] = party.id;
  }
  applyAccountThirdPartyFields(detail, party);
  if (party.name.isNotEmpty) {
    detail['correspondingAccountName'] = party.name;
    detail['CorrespondingAccountName'] = party.name;
    detail['thirdPartyName'] = party.name;
    detail['ThirdPartyName'] = party.name;
  }
}

Map<String, dynamic> unlockJournalPayload(Map<String, dynamic> journal) {
  journal['isLocked'] = false;
  journal['IsLocked'] = false;
  journal['isChecked'] = false;
  journal['IsChecked'] = false;
  return journal;
}

Map<String, dynamic> asMutableJournal(Map journal) {
  return Map<String, dynamic>.from(journal);
}

Map<String, dynamic> removeSelectedFromJournal(
  Map journal,
  List<LedgerEntry> selected,
) {
  final out = asMutableJournal(journal);
  final details = journalDetailMaps(out);
  final classified = classifyJournalVouchers(details);
  final drop = <Map>{};
  for (final voucher in classified) {
    if (!selected.any((row) => voucherMatchesEntry(voucher, row))) continue;
    drop.add(voucher.debitLine);
    drop.add(voucher.creditLine);
    if (voucher.thirdPartyLine != null) drop.add(voucher.thirdPartyLine!);
  }
  final kept = [for (final detail in details) if (!drop.contains(detail)) detail];
  setJournalDetails(out, kept);
  return unlockJournalPayload(out);
}

Map<String, dynamic> sanitizeJournalForUpdate(Map journal) {
  final out = asMutableJournal(journal);
  out.remove(r'$id');
  out.remove(r'$ref');
  final details = <Map<String, dynamic>>[];
  for (final detail in journalDetailMaps(out)) {
    final copy = Map<String, dynamic>.from(detail);
    copy.remove(r'$id');
    copy.remove(r'$ref');
    details.add(copy);
  }
  setJournalDetails(out, details);
  return unlockJournalPayload(out);
}

Map<String, dynamic> applyAccountPatchToJournal(
  Map journal,
  List<LedgerEntry> selected,
  LedgerAccountPatch patch, {
  Map<String, String> currentThirdPartyIds = const {},
}) {
  final out = sanitizeJournalForUpdate(journal);
  final details = journalDetailMaps(out);
  final classified = classifyJournalVouchers(details);
  final party = AccountThirdParty(
    id: patch.thirdPartyId,
    code: patch.thirdPartyCode,
    name: patch.thirdPartyName,
  );
  for (final voucher in classified) {
    LedgerEntry? row;
    for (final item in selected) {
      if (voucherMatchesEntry(voucher, item)) {
        row = item;
        break;
      }
    }
    if (row == null) continue;
    if (patch.hasDebit) {
      applyAccountFields(voucher.debitLine, id: patch.debitId, name: patch.debitName, code: patch.debitCode);
    }
    if (patch.hasCredit) {
      applyAccountFields(voucher.creditLine, id: patch.creditId, name: patch.creditName, code: patch.creditCode);
    }
    if (patch.hasThirdParty) {
      final line = findThirdPartyLine(
        details,
        voucher,
        row,
        currentId: currentThirdPartyIds[ledgerRowIdentity(row)] ?? '',
      );
      if (line != null) {
        applyAccountFields(
          line,
          id: patch.thirdPartyId,
          name: patch.thirdPartyName,
          code: patch.thirdPartyCode,
        );
        applyThirdPartyFields(line, party);
      }
      applyThirdPartyFields(voucher.debitLine, party);
      applyThirdPartyFields(voucher.creditLine, party);
    }
  }
  setJournalDetails(out, details);
  return unlockJournalPayload(out);
}

bool thirdPartyLineHasAccount(Map? line, LedgerAccountPatch patch) {
  if (line == null || !patch.hasThirdParty) return false;
  final id = detailAccountId(line);
  final code = detailAccountCode(line);
  if (patch.thirdPartyId.isNotEmpty && id == patch.thirdPartyId) return true;
  if (patch.thirdPartyCode.isNotEmpty && code == patch.thirdPartyCode) return true;
  return false;
}

LedgerEntry applyPatchToLedgerRow(LedgerEntry row, LedgerAccountPatch patch) {
  return row.copyWith(
    debitAccount: patch.hasDebit ? patch.debitCode : row.debitAccount,
    debitAccountName: patch.hasDebit ? patch.debitName : row.debitAccountName,
    creditAccount: patch.hasCredit ? patch.creditCode : row.creditAccount,
    creditAccountName: patch.hasCredit ? patch.creditName : row.creditAccountName,
    thirdPartyAccount: patch.hasThirdParty ? patch.thirdPartyCode : row.thirdPartyAccount,
    thirdPartyAccountName: patch.hasThirdParty ? patch.thirdPartyName : row.thirdPartyAccountName,
  );
}

String pickDetailThirdPartyId(Map detail) {
  final v = detail['correspondingAccountID'] ??
      detail['CorrespondingAccountID'] ??
      detail['correspondingAccountId'] ??
      detail['thirdPartyID'] ??
      detail['ThirdPartyId'] ??
      detail['thirdPartyId'] ??
      detail['relatedAccountID'] ??
      detail['RelatedAccountId'];
  return v == null ? '' : v.toString().trim();
}

String pickDetailThirdPartyName(Map detail) {
  final v = detail['correspondingAccountName'] ??
      detail['CorrespondingAccountName'] ??
      detail['thirdPartyName'] ??
      detail['ThirdPartyName'];
  return v == null ? '' : v.toString().trim();
}
