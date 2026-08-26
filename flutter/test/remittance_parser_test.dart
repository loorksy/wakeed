import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/json_util.dart';
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
    test('balances profit on the debit account so Wakeed accepts the voucher', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
        ],
      );
      expect(rows.length, 3);
      expect(rows[0].account, '555');
      expect(rows[0].debit, '500');
      expect(rows[1].account, '9830');
      expect(rows[1].credit, '400');
      expect(rows[2].balancing, true);
      expect(rows[2].account, '555');
      expect(rows[2].credit, '100');
      expect(profitPasteTotals([
        ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
      ])['diff'], 100);
      expect(profitKindLabel(100), 'ربح');
      expect(profitForLabel(100, 'احمد'), 'لصالح احمد');
    });

    test('كسر balances extra on the debit account', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '500', debit: '555', debitAmount: '400'),
        ],
      );
      expect(rows.length, 3);
      expect(rows[0].debit, '400');
      expect(rows[1].credit, '500');
      expect(rows[2].balancing, true);
      expect(rows[2].account, '555');
      expect(rows[2].debit, '100');
      expect(formatProfitSigned(-100), '100-');
      expect(profitKindLabel(-100), 'كسر');
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

    test('each pasted row is its own voucher group', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'ا', credit: '9830', creditAmount: '100', debit: '555', debitAmount: '120'),
          ProfitPasteRow(name: 'ب', credit: '9830', creditAmount: '200', debit: '555', debitAmount: '250'),
        ],
      );
      final groups = groupRowsByKey(rows);
      expect(groups.length, 2);
      expect(groups[0].name, 'ا');
      expect(groups[1].name, 'ب');
    });

    test('does not post profit to the creditor; third party of the account owner is used', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
        ],
      );
      final applied = applyProfitThirdParty(
        rows,
        thirdPartyOf: (code) {
          if (code == '555') {
            return const AccountThirdParty(id: 'tp-1', code: '4001', name: 'أرباح الحوالات');
          }
          return const AccountThirdParty();
        },
        ownerIdOf: (code) => code == '555' ? 'owner-555' : '',
      );
      expect(applied.length, 3);
      expect(applied[1].account, '9830');
      expect(applied[1].balancing, false);
      final profitLine = applied[2];
      expect(profitLine.balancing, true);
      expect(profitLine.account, isNot('9830'));
      expect(profitLine.account, '4001');
      expect(profitLine.accountIdOverride, 'tp-1');
      expect(profitLine.correspondingIdOverride, 'owner-555');
      expect(profitLine.credit, '100');
      expect(profitLine.thirdPartyName, contains('أرباح'));
    });

    test('keeps profit on the debit account when Wakeed has no third party', () {
      final rows = buildProfitJournalRows(
        [
          ProfitPasteRow(name: 'احمد', credit: '9830', creditAmount: '400', debit: '555', debitAmount: '500'),
        ],
      );
      final applied = applyProfitThirdParty(
        rows,
        thirdPartyOf: (_) => const AccountThirdParty(),
        ownerIdOf: (_) => 'owner-555',
      );
      expect(applied[2].account, '555');
      expect(applied[2].accountIdOverride, '');
      expect(applied[2].correspondingIdOverride, '');
    });
  });

  group('profit FX conversion', () {
    test('hawalaRateFromApi inverts rates below 1', () {
      expect(hawalaRateFromApi(1, isBase: true), 1);
      expect(hawalaRateFromApi(0.020933, isBase: false), closeTo(47.77, 0.02));
      expect(hawalaRateFromApi(47.77, isBase: false), 47.77);
    });

    test('3384 TRY at 47.77 equals 70.84 USD', () {
      expect(amountToBase(3384, 47.77), 70.84);
      expect(roundMoney(72 - 70.84), 1.16);
    });

    test('3384 TRY at API factor 0.020933 equals native 70.84 not 71.24', () {
      const quote = CurrencyQuote(
        id: 'try',
        code: 'TRY',
        symbol: 'T',
        hawalaRate: 47.77,
        apiRate: 0.020933,
        isBase: false,
      );
      expect(amountToBaseFromQuote(3384, quote), 70.84);
      expect(roundMoney(72 - 70.84), 1.16);
      expect(hawalaLooksRounded(47.5), isTrue);
      expect(hawalaLooksRounded(47.77), isFalse);
    });

    test('catalog rate overwrites a saved 47.5 so profit is 1.16', () {
      final row = JournalRow(
        account: '1731',
        description: 'راتب',
        debit: '',
        credit: '3384',
        rate: '47.5',
      );
      attachRowCurrency(
        row,
        const CurrencyQuote(id: 'try', code: 'TRY', symbol: 'T', hawalaRate: 47.77, isBase: false),
      );
      expect(row.rate, '47.77');
      expect(amountToBase(3384, parseHawalaRate(row.rate)), 70.84);
      expect(roundMoney(72 - 70.84), 1.16);
    });

    test('keeps hawala quote precision so 47.77 is not flattened to 47.5', () {
      expect(formatHawalaRate(47.77), '47.77');
      expect(formatHawalaRate(47.76962), '47.76962');
      expect(hawalaPostRate(47.77), closeTo(0.020933, 0.00001));
    });

    test('profit is in USD not TRY', () {
      final totals = profitPasteTotals([
        ProfitPasteRow(
          name: 'راتب',
          credit: '1731',
          creditAmount: '3384',
          debit: '9830',
          debitAmount: '72',
          debitRate: '1',
          creditRate: '47.77',
          debitCurrencyCode: 'USD',
          creditCurrencyCode: 'TRY',
          debitCurrencySymbol: '\$',
          creditCurrencySymbol: 'T',
          baseCurrencyCode: 'USD',
          baseCurrencySymbol: '\$',
        ),
      ]);
      expect(totals['creditBase'], 70.84);
      expect(totals['debitBase'], 72);
      expect(totals['diff'], 1.16);
      expect(totals['fx'], 1);
    });

    test('balancing line is the USD difference on the debit account', () {
      final rows = buildProfitJournalRows([
        ProfitPasteRow(
          name: 'راتب',
          credit: '1731',
          creditAmount: '3,384',
          debit: '9830',
          debitAmount: '72',
          debitRate: '',
          creditRate: '47.77',
          debitCurrencyId: 'usd',
          creditCurrencyId: 'try',
          debitCurrencyCode: 'USD',
          creditCurrencyCode: 'TRY',
          debitCurrencySymbol: '\$',
          creditCurrencySymbol: 'T',
          baseCurrencyId: 'usd',
          baseCurrencyCode: 'USD',
          baseCurrencySymbol: '\$',
        ),
      ]);
      expect(rows.length, 3);
      expect(rows[0].account, '9830');
      expect(rows[0].debit, '72');
      expect(rows[0].currencySymbol, '\$');
      expect(rows[1].account, '1731');
      expect(rows[1].credit, '3384');
      expect(rows[1].currencySymbol, 'T');
      expect(rows[1].rate, '47.77');
      expect(rows[2].balancing, true);
      expect(rows[2].account, '9830');
      expect(rows[2].credit, '1.16');
      expect(rows[2].rate, '1');
      expect(rows[2].currencyCode, 'USD');
    });
  });

  group('applyRemittanceFx', () {
    CurrencyQuote quoteOf(String code) {
      if (code == '1731') {
        return const CurrencyQuote(id: 'try', code: 'TRY', symbol: 'T', hawalaRate: 47.77, isBase: false);
      }
      return const CurrencyQuote(id: 'usd', code: 'USD', symbol: '\$', hawalaRate: 1, isBase: true);
    }

    test('same currency keeps equal amounts', () {
      final rows = applyRemittanceFx(
        parseRowsFromTable('احمد\t1500\t9830', '555', '9830'),
        quoteOf,
      );
      expect(rows[0].debit, '1500');
      expect(rows[1].credit, '1500');
      expect(fxTotals(rows)['diff'], 0);
      expect(fxTotals(rows)['fx'], 0);
    });

    test('converts equal TRY amount into USD on the debit line', () {
      final rows = applyRemittanceFx(
        [
          JournalRow(account: '9830', description: 'ا', debit: '3384', credit: ''),
          JournalRow(account: '1731', description: 'ا', debit: '', credit: '3384'),
        ],
        quoteOf,
      );
      expect(rows[1].credit, '3384');
      expect(rows[1].currencySymbol, 'T');
      expect(rows[0].debit, '70.84');
      expect(rows[0].currencySymbol, '\$');
      expect(fxTotals(rows)['diff'], 0);
      expect(fxTotals(rows)['debitBase'], 70.84);
    });

    test('different native amounts are not overwritten', () {
      final rows = applyRemittanceFx(
        [
          JournalRow(account: '555', description: 'ا', debit: '1500', credit: ''),
          JournalRow(account: '9830', description: 'ا', debit: '', credit: '1200'),
        ],
        quoteOf,
      );
      expect(rows[0].debit, '1500');
      expect(rows[1].credit, '1200');
    });
  });
}
