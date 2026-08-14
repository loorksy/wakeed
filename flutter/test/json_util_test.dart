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

    test('uses Rate when it is the live quote', () {
      expect(pickCurrencyRate({'Rate': 47.77}), 47.77);
      expect(pickCurrencyRate({'rate': 0.020933}), closeTo(0.020933, 0.000001));
    });
  });
}
