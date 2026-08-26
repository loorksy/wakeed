import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/json_util.dart';
import 'package:wakeed_app/core/remittance_parser.dart';

void main() {
  group('asList', () {
    test('unwraps Newtonsoft \$values lists', () {
      expect(
        asList({
          r'$values': [
            {'Id': 'try', 'Code': 'TRY', 'Rate': 0.020933},
          ],
        }),
        hasLength(1),
      );
    });

    test('unwraps Currencies wrapper from Wakeed currency APIs', () {
      expect(
        asList({
          'Currencies': [
            {'Id': 'try', 'Code': 'TRY', 'Rate': 47.77},
          ],
        }),
        hasLength(1),
      );
    });
  });

  group('pickCurrencyRate', () {
    test('prefers Equality hawala quote over a dummy Rate of 1', () {
      expect(pickCurrencyRate({'Rate': 1, 'Equality': 47.77}), 47.77);
    });

    test('uses precise Rate factor over a rounded Equality of 47.5', () {
      expect(pickCurrencyRate({'Equality': 47.5, 'Rate': 0.020933}), closeTo(0.020933, 0.000001));
      expect(hawalaRateFromApi(pickCurrencyRate({'Equality': 47.5, 'Rate': 0.020933})), closeTo(47.77, 0.02));
    });

    test('prefers 47.77 over a rounded 47.5 hawala quote', () {
      expect(pickCurrencyRate({'CurrencyRate': 47.5, 'Equality': 47.77}), 47.77);
    });

    test('uses lastRate from hawala exchange prices over card equivalent 47.5', () {
      final tryCurrency = {
        'code': 'T',
        'rate': 0.0210526315789473,
        'lastRate': 0.0209336403600586,
        'equivalent': 47.5,
      };
      expect(pickCurrencyRate(tryCurrency), closeTo(0.0209336403600586, 0.0000000001));
      expect(amountToBaseFromQuote(
        3384,
        CurrencyQuote(
          code: 'T',
          symbol: 'T',
          hawalaRate: hawalaRateFromApi(pickCurrencyRate(tryCurrency)),
          apiRate: pickCurrencyRate(tryCurrency),
          isBase: false,
        ),
      ), 70.84);
      expect(roundMoney(72 - 70.84), 1.16);
    });

    test('falls back to rate when lastRate is 0', () {
      expect(pickCurrencyRate({'rate': 0.001724, 'lastRate': 0, 'equivalent': 580}), closeTo(0.001724, 0.0000001));
    });
  });

  group('pickAccountThirdParty', () {
    test('reads nested ThirdParty assigned on the account owner', () {
      final party = pickAccountThirdParty({
        'Id': 'acc-555',
        'AccountCode': '555',
        'AccountName': 'صندوق',
        'ThirdParty': {
          'Id': 'tp-1',
          'AccountCode': '4001',
          'AccountName': 'أرباح الحوالات',
        },
      });
      expect(party.id, 'tp-1');
      expect(party.code, '4001');
      expect(party.name, 'أرباح الحوالات');
      expect(party.label, contains('4001'));
    });

    test('reads thirdPartyId on the Wakeed account card', () {
      final party = pickAccountThirdParty({
        'id': 'acc-555',
        'accountCode': '555',
        'thirdPartyId': 'tp-9',
        'thirdPartyCode': '4110',
        'thirdPartyName': 'عمولة',
      });
      expect(party.id, 'tp-9');
      expect(party.code, '4110');
      expect(party.name, 'عمولة');
    });

    test('does not treat Party/owner as the third party (that is the creditor)', () {
      final party = pickAccountThirdParty({
        'Id': 'acc-9830',
        'AccountCode': '9830',
        'AccountName': 'أحمد',
        'PartyId': 'party-ahmad',
        'Party': {'Id': 'party-ahmad', 'AccountCode': '9830', 'AccountName': 'أحمد'},
      });
      expect(party.isEmpty, true);
    });

    test('reads ThirdParty nested on the account owner Party', () {
      final party = pickAccountThirdParty({
        'Id': 'acc-9830',
        'AccountCode': '9830',
        'AccountName': 'أحمد',
        'Party': {
          'Id': 'party-ahmad',
          'AccountCode': '9830',
          'AccountName': 'أحمد',
          'ThirdParty': {
            'Id': 'tp-22',
            'AccountCode': '4001',
            'AccountName': 'عمولة الحوالة',
          },
        },
      });
      expect(party.id, 'tp-22');
      expect(party.code, '4001');
      expect(party.name, 'عمولة الحوالة');
    });

    test('reads correspondingAccountID on the Wakeed account card', () {
      final party = pickAccountThirdParty({
        'Id': 'acc-9830',
        'AccountCode': '9830',
        'AccountName': 'أحمد',
        'correspondingAccountID': 'tp-9',
        'CorrespondingAccountCode': '4110',
        'CorrespondingAccountName': 'عمولة',
      });
      expect(party.id, 'tp-9');
      expect(party.code, '4110');
      expect(party.name, 'عمولة');
    });

    test('ignores a third party that is the account itself', () {
      final party = pickAccountThirdParty({
        'Id': 'acc-555',
        'AccountCode': '555',
        'ThirdPartyId': 'acc-555',
        'ThirdPartyCode': '555',
      });
      expect(party.isEmpty, true);
    });
  });

  group('unwrapEntity', () {
    test('unwraps Wakeed data wrapper around an account', () {
      final acc = unwrapEntity({
        'data': {
          'Id': 'acc-1',
          'AccountCode': '4001',
          'ThirdParty': {'Id': 'tp-1', 'AccountCode': '4110'},
        },
      });
      expect(pickId(acc), 'acc-1');
      expect(pickAccountCode(acc), '4001');
    });
  });
}
