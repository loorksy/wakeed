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

List<Map<String, dynamic>> journalDetailMaps(dynamic journal) {
  if (journal is! Map) return const [];
  final raw = journal['journalEntryDetails'] ?? journal['JournalEntryDetails'];
  return [
    for (final item in asList(raw))
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

void setJournalDetails(Map<String, dynamic> journal, List<Map<String, dynamic>> details) {
  journal['journalEntryDetails'] = details;
  journal['JournalEntryDetails'] = details;
}

num _detailAmount(Map detail) {
  final credit = numOf(detail['credit'] ?? detail['Credit']);
  if (credit > 0) return credit;
  return numOf(detail['debit'] ?? detail['Debit']);
}

String _detailNotes(Map detail) {
  return (detail['notes'] ?? detail['Notes'] ?? '').toString().trim();
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
  final amount = _detailAmount(detail);
  if (amount > 0 && (numOf(entry.amount) - amount).abs() > 0.001) return false;
  return _notesMatchName(_detailNotes(detail), entry.name);
}

bool selectedCoversWholeJournal(List<LedgerEntry> inJournal, List<LedgerEntry> selected) {
  if (inJournal.isEmpty) return selected.isNotEmpty;
  final keys = selected.map(ledgerRowIdentity).toSet();
  return inJournal.every((row) => keys.contains(ledgerRowIdentity(row)));
}

void applyAccountFields(
  Map<String, dynamic> detail, {
  required String id,
  String name = '',
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
}

void applyThirdPartyFields(Map<String, dynamic> detail, AccountThirdParty party) {
  if (party.id.isEmpty && party.code.isEmpty) return;
  if (party.id.isNotEmpty) {
    detail['correspondingAccountID'] = party.id;
    detail['CorrespondingAccountID'] = party.id;
    detail['oppositeAccountID'] = party.id;
    detail['OppositeAccountID'] = party.id;
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

Map<String, dynamic> removeSelectedFromJournal(
  Map<String, dynamic> journal,
  List<LedgerEntry> selected,
) {
  final details = journalDetailMaps(journal);
  final kept = [
    for (final detail in details)
      if (!selected.any((row) => detailMatchesLedger(detail, row))) detail,
  ];
  setJournalDetails(journal, kept);
  return unlockJournalPayload(journal);
}

Map<String, dynamic> applyAccountPatchToJournal(
  Map<String, dynamic> journal,
  List<LedgerEntry> selected,
  LedgerAccountPatch patch,
) {
  final details = journalDetailMaps(journal);
  final party = AccountThirdParty(
    id: patch.thirdPartyId,
    code: patch.thirdPartyCode,
    name: patch.thirdPartyName,
  );
  for (final detail in details) {
    if (!selected.any((row) => detailMatchesLedger(detail, row))) continue;
    final debit = numOf(detail['debit'] ?? detail['Debit']);
    final credit = numOf(detail['credit'] ?? detail['Credit']);
    if (debit > 0 && patch.hasDebit) {
      applyAccountFields(detail, id: patch.debitId, name: patch.debitName);
    }
    if (credit > 0 && patch.hasCredit) {
      applyAccountFields(detail, id: patch.creditId, name: patch.creditName);
    }
    if (patch.hasThirdParty) {
      applyThirdPartyFields(detail, party);
    }
  }
  setJournalDetails(journal, details);
  return unlockJournalPayload(journal);
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
