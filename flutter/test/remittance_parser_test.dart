import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/remittance_parser.dart';

void main() {
  group('cleanAmount', () {
    test('strips commas and arabic separators', () {
      expect(cleanAmount('1,500'), '1500');
      expect(cleanAmount('1٫500'), '1500');
      expect(cleanAmount(' 2000.5 '), '2000.5');
    });
    test('rejects invalid', () {
      expect(cleanAmount('abc'), '');
      expect(cleanAmount(''), '');
      expect(cleanAmount(null), '');
    });
  });

  group('isAccount', () {
    test('codes', () {
      expect(isAccount('9830'), true);
      expect(isAccount('12'), true);
      expect(isAccount('555-1'), true);
      expect(isAccount('احمد'), false);
      expect(isAccount('1'), false);
    });
  });

  group('parseRowsFromTable template الاسم|المبلغ|الدائن', () {
    test('parses three customers with default debit', () {
      const text = 'احمد الاحمد\t1500\t9830\nمحمد الاحمد\t2000\t9830\nخالد الخالد\t3500\t9830';
      final rows = parseRowsFromTable(text, '555', '9830');
      expect(rows.length, 6);
      expect(rows[0].description, 'احمد الاحمد');
      expect(rows[0].account, '555');
      expect(rows[0].debit, '1500');
      expect(rows[1].account, '9830');
      expect(rows[1].credit, '1500');
      expect(rows[2].description, 'محمد الاحمد');
      expect(rows[4].debit, '3500');
    });

    test('uses UI default debit', () {
      const text = 'علي\t100\t1200';
      final rows = parseRowsFromTable(text, '777', '9830');
      expect(rows[0].account, '777');
      expect(rows[1].account, '1200');
    });

    test('two columns uses default credit 9830', () {
      const text = 'سامي\t400';
      final rows = parseRowsFromTable(text, '555', '9830');
      expect(rows.length, 2);
      expect(rows[1].account, '9830');
      expect(rows[1].credit, '400');
    });

    test('skips header row', () {
      const text = 'الاسم\tالمبلغ\tالدائن\nاحمد\t10\t9830';
      final rows = parseRowsFromTable(text, '555', '9830');
      expect(rows.length, 2);
      expect(rows[0].description, 'احمد');
    });
  });

  group('groupCustomerRows', () {
    test('pairs debit/credit', () {
      final rows = parseRowsFromTable('ا\t1\t9830\nب\t2\t9830', '555', '9830');
      final groups = groupCustomerRows(rows);
      expect(groups.length, 2);
      expect(groups[0].name, 'ا');
      expect(groups[1].name, 'ب');
    });
  });

  test('sheetTemplate is tab-separated arabic header', () {
    expect(sheetTemplate.split('\n').first, 'الاسم\tالمبلغ\tالدائن');
  });

  group('parseProfitTable', () {
    test('parses four columns credit amount debit amount', () {
      const text = '9830\t1500\t555\t1200\n1200\t2000\t555\t1800';
      final rows = parseProfitTable(text);
      expect(rows.length, 2);
      expect(rows[0].credit, '9830');
      expect(rows[0].creditAmount, '1500');
      expect(rows[0].debit, '555');
      expect(rows[0].debitAmount, '1200');
    });

    test('parses five columns with name', () {
      const text = 'احمد\t9830\t1500\t555\t1200';
      final rows = parseProfitTable(text);
      expect(rows.length, 1);
      expect(rows[0].name, 'احمد');
      expect(rows[0].credit, '9830');
      expect(rows[0].debit, '555');
    });

    test('skips header row', () {
      final rows = parseProfitTable(profitSheetTemplate);
      expect(rows.length, 2);
      expect(rows[0].credit, '9830');
    });
  });

  group('buildProfitJournalRows', () {
    test('sends exactly two written lines to Wakeed', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
        ],
      );
      expect(rows.length, 2);
      expect(rows[0].account, '555');
      expect(rows[0].debit, '500');
      expect(rows[1].account, '9830');
      expect(rows[1].credit, '400');
      expect(rows.any((r) => r.balancing), false);
      expect(profitPasteTotals([
        ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
      ])['diff'], 100);
      expect(profitForLabel(100, 'احمد'), 'لصالح احمد');
    });

    test('كسر keeps two written lines and labels على المدين', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '500', debit: '555', debitAmount: '400'),
        ],
      );
      expect(rows.length, 2);
      expect(rows[0].debit, '400');
      expect(rows[1].credit, '500');
      expect(formatProfitSigned(-100), '100-');
      expect(profitForLabel(-100, 'احمد'), 'على احمد');
    });

    test('equal amounts stay two lines', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'ا', credit: '9830', creditAmount: '100', debit: '555', debitAmount: '100'),
        ],
      );
      expect(rows.length, 2);
      expect(rows.any((r) => r.balancing), false);
    });
  });
}
