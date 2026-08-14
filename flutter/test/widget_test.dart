import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/remittance_parser.dart';

void main() {
  testWidgets('parser template groups three customers', (tester) async {
    final rows = parseRowsFromTable(sheetTemplate, '555', '9830');
    expect(groupCustomerRows(rows).length, 3);
  });
}
