import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/journal_mutate.dart';
import 'package:wakeed_app/models/models.dart';

LedgerEntry _row({
  required String id,
  required String name,
  required num amount,
  String journalId = '11111111-1111-1111-1111-111111111111',
  String date = '2026-09-21',
  String debit = '555',
  String credit = '9830',
}) {
  return LedgerEntry(
    id: id,
    journalId: journalId,
    name: name,
    amount: amount,
    entryDate: date,
    debitAccount: debit,
    creditAccount: credit,
  );
}

void main() {
  test('skipped names are copied one per line and ignore blanks', () {
    expect(skippedNamesText(['أحمد', ' ', 'سارة']), 'أحمد\nسارة');
  });

  test('wakeed journal ids are UUIDs only', () {
    expect(isWakeedJournalId('11111111-1111-1111-1111-111111111111'), isTrue);
    expect(isWakeedJournalId('j1:name:10'), isFalse);
    expect(isWakeedJournalId(''), isFalse);
  });

  test('groups selected rows by journal id', () {
    final a = _row(id: 'a', name: 'علي', amount: 10);
    final b = _row(id: 'b', name: 'سارة', amount: 20, journalId: '22222222-2222-2222-2222-222222222222');
    final c = _row(id: 'c', name: 'علي2', amount: 5);
    final grouped = groupLedgerByJournal([a, b, c]);
    expect(grouped[a.journalId]!.map((e) => e.name), ['علي', 'علي2']);
    expect(grouped[b.journalId]!.single.name, 'سارة');
  });

  test('covers whole journal when every local name is selected', () {
    final inJournal = [
      _row(id: '1', name: 'علي', amount: 10),
      _row(id: '2', name: 'سارة', amount: 20),
    ];
    expect(selectedCoversWholeJournal(inJournal, inJournal), isTrue);
    expect(selectedCoversWholeJournal(inJournal, [inJournal.first]), isFalse);
  });

  test('matches journal details by name and amount', () {
    final entry = _row(id: '1', name: 'حنين يوسف', amount: 253);
    expect(
      detailMatchesLedger(
        {'notes': 'حنين يوسف', 'debit': 253, 'credit': 0},
        entry,
      ),
      isTrue,
    );
    expect(
      detailMatchesLedger(
        {'notes': 'حنين يوسف — سند حوالة', 'credit': 253, 'debit': 0},
        entry,
      ),
      isTrue,
    );
    expect(
      detailMatchesLedger(
        {'notes': 'شخص آخر', 'credit': 253, 'debit': 0},
        entry,
      ),
      isFalse,
    );
    expect(
      detailMatchesLedger(
        {'notes': 'حنين يوسف', 'credit': 99, 'debit': 0},
        entry,
      ),
      isFalse,
    );
  });

  test('removes only selected names from a batch journal', () {
    final journal = {
      'id': '11111111-1111-1111-1111-111111111111',
      'journalEntryDetails': [
        {'notes': 'علي', 'debit': 10, 'credit': 0, 'normalAccountId': 'd1'},
        {'notes': 'علي', 'debit': 0, 'credit': 10, 'normalAccountId': 'c1'},
        {'notes': 'سارة', 'debit': 20, 'credit': 0, 'normalAccountId': 'd1'},
        {'notes': 'سارة', 'debit': 0, 'credit': 20, 'normalAccountId': 'c1'},
      ],
    };
    final updated = removeSelectedFromJournal(journal, [_row(id: '1', name: 'علي', amount: 10)]);
    final left = journalDetailMaps(updated);
    expect(left.length, 2);
    expect(left.every((d) => (d['notes'] as String).contains('سارة')), isTrue);
    expect(updated['isLocked'], isFalse);
  });

  test('patches debit credit and third party on matching lines only', () {
    final journal = {
      'journalEntryDetails': [
        {
          'notes': 'علي',
          'debit': 10,
          'credit': 0,
          'normalAccountId': 'old-d',
          'accountName': 'قديم مدين',
        },
        {
          'notes': 'علي',
          'debit': 0,
          'credit': 10,
          'normalAccountId': 'old-c',
          'accountName': 'قديم دائن',
        },
        {
          'notes': 'سارة',
          'debit': 20,
          'credit': 0,
          'normalAccountId': 'keep-d',
        },
      ],
    };
    final patched = applyAccountPatchToJournal(
      journal,
      [_row(id: '1', name: 'علي', amount: 10)],
      const LedgerAccountPatch(
        debitId: 'new-d',
        debitName: 'مدين جديد',
        creditId: 'new-c',
        creditName: 'دائن جديد',
        thirdPartyId: 'tp-1',
        thirdPartyName: 'عمولة',
      ),
    );
    final details = journalDetailMaps(patched);
    expect(details[0]['normalAccountId'], 'new-d');
    expect(details[0]['accountName'], 'مدين جديد');
    expect(details[0]['thirdPartyID'], 'tp-1');
    expect(details[1]['normalAccountId'], 'new-c');
    expect(details[1]['accountName'], 'دائن جديد');
    expect(details[2]['normalAccountId'], 'keep-d');
  });

  test('patches the actual third-party journal line not only corresponding fields', () {
    final journal = {
      'journalEntryDetails': [
        {'notes': 'علي', 'debit': 100, 'credit': 0, 'normalAccountId': 'd1', 'accountName': 'مدين'},
        {'notes': 'علي', 'debit': 0, 'credit': 100, 'normalAccountId': 'c1', 'accountName': 'دائن'},
        {'notes': 'سند حوالة', 'debit': 0, 'credit': 4, 'normalAccountId': 'old-tp', 'accountName': 'قديم'},
      ],
    };
    final patched = applyAccountPatchToJournal(
      journal,
      [_row(id: '1', name: 'علي', amount: 100)],
      const LedgerAccountPatch(thirdPartyId: 'new-tp', thirdPartyName: 'عمولة جديدة', thirdPartyCode: '422'),
    );
    final details = journalDetailMaps(patched);
    expect(details.length, 3);
    expect(details[0]['normalAccountId'], 'd1');
    expect(details[1]['normalAccountId'], 'c1');
    expect(details[2]['normalAccountId'], 'new-tp');
    expect(details[2]['accountName'], 'عمولة جديدة');
    expect(details[0]['correspondingAccountID'], 'new-tp');
  });

  test('deletes the third-party leftover line with the voucher', () {
    final journal = {
      'journalEntryDetails': [
        {'notes': 'علي', 'debit': 100, 'credit': 0, 'normalAccountId': 'd1'},
        {'notes': 'علي', 'debit': 0, 'credit': 100, 'normalAccountId': 'c1'},
        {'notes': 'سند حوالة', 'debit': 0, 'credit': 4, 'normalAccountId': 'tp1'},
      ],
    };
    final updated = removeSelectedFromJournal(journal, [_row(id: '1', name: 'علي', amount: 100)]);
    expect(journalDetailMaps(updated), isEmpty);
  });

  test('applyPatchToLedgerRow updates only filled sides', () {
    final row = _row(id: '1', name: 'علي', amount: 10);
    final next = applyPatchToLedgerRow(
      row,
      const LedgerAccountPatch(debitCode: '600', debitName: 'صندوق', thirdPartyCode: '422', thirdPartyName: 'عمولة'),
    );
    expect(next.debitAccount, '600');
    expect(next.debitAccountName, 'صندوق');
    expect(next.creditAccount, '9830');
    expect(next.thirdPartyAccount, '422');
    expect(next.id, row.id);
  });
}
