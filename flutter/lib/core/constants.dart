const String platformBaseUrl = 'https://wakeed.lork.cloud';
const int heartbeatMs = 45000;
const int journalParallel = 2;
const String defaultCreditAccount = '9830';
const String defaultDebitFallback = '555';
const String defaultServer = 'server1.wakeed.app';
const String defaultBuildNumber = '3996';
const Duration httpTimeout = Duration(seconds: 45);

const String prefsSessionToken = 'wakeed.sessionToken';
const String prefsDeviceId = 'wakeed.deviceId';
const String prefsLicenseKey = 'wakeed.licenseKey';
const String prefsLastDialog = 'wakeed.lastDialog';
const String prefsLedgerCache = 'wakeed.ledgerCache';
const String excelMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const int ledgerPageSizeMobile = 10;
const int ledgerPageSizeDesktop = 20;
const double ledgerDesktopMinWidth = 768;

int ledgerPageSizeFor({required bool isWeb, required double width}) {
  if (isWeb && width >= ledgerDesktopMinWidth) return ledgerPageSizeDesktop;
  return ledgerPageSizeMobile;
}

({int page, int pageCount, int start, int end}) ledgerPageWindow({
  required int total,
  required int pageSize,
  required int page,
}) {
  final size = pageSize < 1 ? 1 : pageSize;
  final pageCount = total <= 0 ? 1 : ((total + size - 1) ~/ size);
  final safePage = page.clamp(0, pageCount - 1);
  if (total <= 0) {
    return (page: 0, pageCount: 1, start: 0, end: 0);
  }
  final start = safePage * size;
  final end = (start + size) > total ? total : start + size;
  return (page: safePage, pageCount: pageCount, start: start, end: end);
}
