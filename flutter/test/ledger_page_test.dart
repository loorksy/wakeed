import 'package:flutter_test/flutter_test.dart';
import 'package:wakeed_app/core/constants.dart';

void main() {
  test('mobile and narrow web use 10 rows per page', () {
    expect(ledgerPageSizeFor(isWeb: false, width: 1200), 10);
    expect(ledgerPageSizeFor(isWeb: true, width: 400), 10);
  });

  test('desktop web uses 20 rows per page', () {
    expect(ledgerPageSizeFor(isWeb: true, width: 1280), 20);
  });

  test('ledger page window slices 10 then 5 of 25', () {
    final first = ledgerPageWindow(total: 25, pageSize: 10, page: 0);
    expect(first.start, 0);
    expect(first.end, 10);
    expect(first.pageCount, 3);
    final last = ledgerPageWindow(total: 25, pageSize: 10, page: 2);
    expect(last.start, 20);
    expect(last.end, 25);
    expect(last.page, 2);
  });

  test('out of range page is clamped', () {
    final w = ledgerPageWindow(total: 20, pageSize: 20, page: 9);
    expect(w.page, 0);
    expect(w.pageCount, 1);
    expect(w.end, 20);
  });
}
