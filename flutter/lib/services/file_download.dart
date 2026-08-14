import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart' as impl;

Future<void> saveBytesAsFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  if (kIsWeb) {
    impl.downloadBytesWeb(bytes, filename, mimeType);
    return Future.value();
  }
  return Share.shareXFiles(
    [XFile.fromData(bytes, name: filename, mimeType: mimeType)],
    fileNameOverrides: [filename],
  );
}
