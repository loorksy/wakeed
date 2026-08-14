import '../models/models.dart';
import 'json_util.dart';

/// Maps Wakeed `GET /api/JournalEntry` rows (docs.wakeed.app Journals)
/// into local ledger entries. Nothing is written to the platform database.
List<LedgerEntry> ledgerFromWakeedJournals(
  dynamic payload, {
  required String ownerKey,
  String userId = '',
  String userName = '',
  Map<String, String> accountCodesById = const {},
}) {
  final list = _journalList(payload);
  final out = <LedgerEntry>[];
  final wantedUser = userName.trim().toLowerCase();
  for (final raw in list) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final itemUser = (item['userName'] ?? item['UserName'] ?? '').toString().trim();
    if (wantedUser.isNotEmpty && itemUser.isNotEmpty && itemUser.toLowerCase() != wantedUser) {
      continue;
    }
    out.addAll(
      _rowsFromJournal(
        item,
        ownerKey: ownerKey,
        accountCodesById: accountCodesById,
      ),
    );
  }
  return out;
}

List<dynamic> _journalList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    final data = payload['journalEntryData'] ??
        payload['JournalEntryData'] ??
        payload['data'] ??
        payload['Data'];
    if (data is List) return data;
    if (data is Map) {
      final nested = data['journalEntryData'] ?? data['JournalEntryData'];
      if (nested is List) return nested;
    }
  }
  return asList(payload);
}

List<LedgerEntry> _rowsFromJournal(
  Map<String, dynamic> journal, {
  required String ownerKey,
  required Map<String, String> accountCodesById,
}) {
  final journalId = pickId(journal);
  final journalNumber = pickJournalNumber(journal);
  final dateRaw = (journal['date'] ?? journal['Date'] ?? journal['dateEntry1'] ?? journal['DateEntry1'] ?? '')
      .toString();
  final entryDate = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
  final createdAt = (journal['defaultPosting'] ?? journal['DefaultPosting'] ?? dateRaw).toString();
  final details = asList(journal['journalEntryDetails'] ?? journal['JournalEntryDetails']);
  final pairs = _detailPairs(details);
  if (pairs.isEmpty) return const [];
  return [
    for (final pair in pairs)
      LedgerEntry(
        id: journalId.isNotEmpty
            ? '$journalId:${pair.name}:${pair.amount}'
            : makeId(),
        ownerKey: ownerKey,
        createdAt: createdAt,
        entryDate: entryDate,
        journalNumber: journalNumber,
        journalId: journalId,
        kind: 'synced',
        name: pair.name,
        amount: pair.amount,
        debitAccount: _accountCode(pair.debit, accountCodesById),
        debitAccountName: pair.debitName,
        creditAccount: _accountCode(pair.credit, accountCodesById),
        creditAccountName: pair.creditName,
        notes: pair.notes,
        statement: pair.name,
      ),
  ];
}

class _Pair {
  _Pair({
    required this.name,
    required this.amount,
    required this.debit,
    required this.debitName,
    required this.credit,
    required this.creditName,
    required this.notes,
  });
  final String name;
  final num amount;
  final String debit;
  final String debitName;
  final String credit;
  final String creditName;
  final String notes;
}

List<_Pair> _detailPairs(List<dynamic> details) {
  final lines = details.whereType<Map>().toList();
  if (lines.isEmpty) return const [];
  final byNotes = <String, List<Map>>{};
  for (final line in lines) {
    final note = (line['notes'] ?? line['Notes'] ?? '').toString().trim();
    byNotes.putIfAbsent(note, () => []).add(line);
  }
  final pairs = <_Pair>[];
  for (final entry in byNotes.entries) {
    pairs.addAll(_pairsFromGroup(entry.value, fallbackName: entry.key));
  }
  return pairs;
}

List<_Pair> _pairsFromGroup(List<Map> lines, {required String fallbackName}) {
  final debits = lines.where((l) => numOf(l['debit'] ?? l['Debit']) > 0).toList();
  final credits = lines.where((l) => numOf(l['credit'] ?? l['Credit']) > 0).toList();
  if (debits.isEmpty || credits.isEmpty) return const [];

  List<Map> left;
  List<Map> right;
  if (debits.length == 1 && credits.length > 1) {
    left = List<Map>.filled(credits.length, debits.first);
    right = credits;
  } else if (credits.length == 1 && debits.length > 1) {
    left = debits;
    right = List<Map>.filled(debits.length, credits.first);
  } else {
    final n = debits.length < credits.length ? debits.length : credits.length;
    left = debits.take(n).toList();
    right = credits.take(n).toList();
  }

  final out = <_Pair>[];
  for (var i = 0; i < left.length && i < right.length; i++) {
    final d = left[i];
    final c = right[i];
    final amount = numOf(c['credit'] ?? c['Credit']);
    final amt = amount > 0 ? amount : numOf(d['debit'] ?? d['Debit']);
    final name = (c['notes'] ?? d['notes'] ?? fallbackName).toString().trim();
    out.add(_Pair(
      name: name.isEmpty ? 'سند' : name,
      amount: amt,
      debit: (d['normalAccountId'] ?? d['NormalAccountId'] ?? '').toString(),
      debitName: (d['accountName'] ?? d['AccountName'] ?? '').toString(),
      credit: (c['normalAccountId'] ?? c['NormalAccountId'] ?? '').toString(),
      creditName: (c['accountName'] ?? c['AccountName'] ?? '').toString(),
      notes: name,
    ));
  }
  return out;
}

String _accountCode(String id, Map<String, String> codesById) {
  if (id.isEmpty) return '';
  return codesById[id] ?? '';
}

Map<String, String> accountCodesById(List<dynamic> accounts) {
  final map = <String, String>{};
  for (final acc in accounts) {
    final id = pickId(acc);
    final code = pickAccountCode(acc);
    if (id.isNotEmpty && code.isNotEmpty) map[id] = code;
  }
  return map;
}
