import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/json_util.dart';

void main() {
  group('asList', () {
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

    test('uses Rate when it is the live quote', () {
      expect(pickCurrencyRate({'Rate': 47.77}), 47.77);
      expect(pickCurrencyRate({'rate': 0.020933}), closeTo(0.020933, 0.000001));
    });
  });
}
