import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/journal_sync.dart';

void main() {
  test('maps Wakeed journal page into ledger rows for current user only', () {
    const payload = {
      'journalEntryData': [
        {
          'id': 'j1',
          'journalEntryNumber': 1081,
          'date': '2026-08-14T00:00:00',
          'userName': 'ahmed isa',
          'journalEntryDetails': [
            {
              'normalAccountId': 'd1',
              'accountName': 'السلطان',
              'debit': 253,
              'credit': 0,
              'notes': 'حنين يوسف خالد',
            },
            {
              'normalAccountId': 'c1',
              'accountName': 'شامنا غولد',
              'debit': 0,
              'credit': 253,
              'notes': 'حنين يوسف خالد',
            },
          ],
        },
        {
          'id': 'j2',
          'journalEntryNumber': 99,
          'date': '2026-08-14T00:00:00',
          'userName': 'موظف آخر',
          'journalEntryDetails': [
            {'normalAccountId': 'd1', 'accountName': 'مدين', 'debit': 10, 'credit': 0, 'notes': 'س'},
            {'normalAccountId': 'c1', 'accountName': 'دائن', 'debit': 0, 'credit': 10, 'notes': 'س'},
          ],
        },
      ],
    };

    final rows = ledgerFromWakeedJournals(
      payload,
      ownerKey: 'owner_x',
      userName: 'ahmed isa',
      accountCodesById: {'d1': '555', 'c1': '9830'},
    );
    expect(rows.length, 1);
    expect(rows.first.journalNumber, '1081');
    expect(rows.first.name, 'حنين يوسف خالد');
    expect(rows.first.amount, 253);
    expect(rows.first.debitAccount, '555');
    expect(rows.first.creditAccount, '9830');
    expect(rows.first.kind, 'synced');
  });
}
