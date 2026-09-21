import '../models/models.dart';
import 'journal_mutate.dart';
import 'json_util.dart';

/// Maps Wakeed `GET /api/JournalEntry` rows (docs.wakeed.app Journals)
/// into local ledger entries. Nothing is written to the platform database.
///
/// One remittance voucher becomes one row, even when Wakeed stores
/// مدين + دائن + طرف ثالث as three journal lines.
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
  final details = [
    for (final item in asList(journal['journalEntryDetails'] ?? journal['JournalEntryDetails']))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
  final vouchers = classifyJournalVouchers(details);
  if (vouchers.isEmpty) return const [];
  return [
    for (final voucher in vouchers)
      LedgerEntry(
        id: journalId.isNotEmpty ? '$journalId:${voucher.name}:${voucher.amount}' : makeId(),
        ownerKey: ownerKey,
        createdAt: createdAt,
        entryDate: entryDate,
        journalNumber: journalNumber,
        journalId: journalId,
        kind: 'synced',
        name: voucher.name,
        amount: voucher.amount,
        debitAccount: _accountCode(voucher.debitId, accountCodesById),
        debitAccountName: voucher.debitName,
        creditAccount: _accountCode(voucher.creditId, accountCodesById),
        creditAccountName: voucher.creditName,
        thirdPartyAccount: _accountCode(voucher.thirdPartyId, accountCodesById),
        thirdPartyAccountName: voucher.thirdPartyName,
        notes: voucher.name,
        statement: voucher.name,
      ),
  ];
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
