import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/exceptions.dart';
import 'storage_service.dart';

typedef BlockCallback = void Function(String message, String code);

class PlatformService {
  PlatformService(this.storage, {http.Client? client}) : _client = client ?? http.Client();

  final StorageService storage;
  final http.Client _client;

  String sessionToken = '';
  String deviceId = '';
  String deviceName = 'Android';
  String licenseKey = '';
  String server = defaultServer;
  String buildNumber = defaultBuildNumber;
  String wakeedToken = '';
  String ownerKey = '';
  String username = '';
  String userDisplayName = '';
  List<dynamic> subscriptions = [];
  bool blocked = false;
  String blockMessage = '';

  BlockCallback? onBlock;
  Timer? _heartbeatTimer;

  String getDeviceId() {
    if (deviceId.isNotEmpty) return deviceId;
    var id = storage.deviceId;
    if (id.isEmpty) {
      final rand = Random().nextInt(0x7fffffff).toRadixString(16);
      id = 'd-${DateTime.now().millisecondsSinceEpoch}-$rand';
    }
    deviceId = id;
    storage.saveDeviceId(id);
    return id;
  }

  bool paused = false;

  Map<String, String> platformHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $sessionToken',
      'X-Session-Token': sessionToken,
      'X-Device-Id': getDeviceId(),
    };
  }

  Uri _uri(String path) {
    if (path.startsWith('http')) return Uri.parse(path);
    return Uri.parse('$platformBaseUrl$path');
  }

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    try {
      final body = utf8.decode(res.bodyBytes);
      if (body.isEmpty) return {};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return {};
    }
  }

  Never _blockOffline() {
    blockApp('لا يوجد اتصال بالسيرفر. التطبيق متوقف حتى عودة الاتصال.', 'offline');
    throw PlatformApiException(
      'لا يوجد اتصال بالسيرفر. التطبيق متوقف حتى عودة الاتصال.',
      isOffline: true,
      code: 'offline',
    );
  }

  Future<Map<String, dynamic>> platformFetch(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, String>? extraHeaders,
    bool auth = true,
  }) async {
    http.Response res;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (auth) ...platformHeaders(),
        ...?extraHeaders,
      };
      final uri = _uri(path);
      final encoded = body == null
          ? null
          : body is String
              ? body
              : jsonEncode(body);
      if (method == 'GET') {
        res = await _client.get(uri, headers: headers).timeout(httpTimeout);
      } else if (method == 'PUT') {
        res = await _client.put(uri, headers: headers, body: encoded).timeout(httpTimeout);
      } else if (method == 'POST') {
        res = await _client.post(uri, headers: headers, body: encoded).timeout(httpTimeout);
      } else if (method == 'DELETE') {
        res = await _client.delete(uri, headers: headers, body: encoded).timeout(httpTimeout);
      } else {
        throw PlatformApiException('طريقة غير مدعومة: $method');
      }
    } on PlatformApiException {
      rethrow;
    } on TimeoutException {
      if (paused) {
        throw PlatformApiException('لا يوجد اتصال بالسيرفر.', isOffline: true, code: 'offline');
      }
      return _blockOffline();
    } catch (e) {
      if (e is PlatformApiException) rethrow;
      if (paused) {
        throw PlatformApiException('لا يوجد اتصال بالسيرفر.', isOffline: true, code: 'offline');
      }
      return _blockOffline();
    }

    final json = await _decode(res);
    if (res.statusCode == 403 || res.statusCode == 401) {
      final msg = (json['message'] ?? 'الترخيص غير صالح.').toString();
      blockApp(msg, (json['code'] ?? '').toString());
      throw PlatformApiException(msg, status: res.statusCode, code: json['code']?.toString(), isAuth: true);
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || json['ok'] == false) {
      throw PlatformApiException(
        (json['message'] ?? 'HTTP ${res.statusCode}').toString(),
        status: res.statusCode,
        code: json['code']?.toString(),
      );
    }
    return json;
  }

  void blockApp(String message, [String code = '']) {
    blocked = true;
    blockMessage = message;
    stopHeartbeat();
    onBlock?.call(message, code);
  }

  void unblockApp() {
    blocked = false;
    blockMessage = '';
  }

  Future<Map<String, dynamic>> activateLicense(String licenseKeyRaw) async {
    final res = await platformFetch(
      '/api/license/activate',
      method: 'POST',
      auth: false,
      extraHeaders: {'Content-Type': 'application/json'},
      body: {
        'licenseKey': licenseKeyRaw.trim().toUpperCase(),
        'deviceId': getDeviceId(),
        'deviceName': deviceName,
      },
    );
    final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : res;
    sessionToken = (data['sessionToken'] ?? '').toString();
    licenseKey = (data['licenseKey'] ?? licenseKeyRaw).toString();
    await storage.saveSession(sessionToken: sessionToken, licenseKey: licenseKey);
    unblockApp();
    startHeartbeat();
    return data;
  }

  Future<bool> heartbeat({bool blockOnFailure = true}) async {
    if (sessionToken.isEmpty) return false;
    if (paused && !blockOnFailure) return true;
    try {
      final res = await _client
          .post(_uri('/api/license/heartbeat'), headers: platformHeaders())
          .timeout(const Duration(seconds: 15));
      final json = await _decode(res);
      if (res.statusCode < 200 || res.statusCode >= 300 || json['ok'] == false) {
        if (blockOnFailure) {
          blockApp((json['message'] ?? 'الترخيص غير صالح.').toString(), (json['code'] ?? '').toString());
        }
        return false;
      }
      return true;
    } catch (_) {
      if (paused && !blockOnFailure) return false;
      if (blockOnFailure) {
        blockApp('لا يوجد اتصال بالسيرفر. التطبيق متوقف حتى عودة الاتصال.', 'offline');
      }
      return false;
    }
  }

  void startHeartbeat() {
    stopHeartbeat();
    heartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: heartbeatMs), (_) {
      if (paused) return;
      heartbeat();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<bool> initPlatform() async {
    getDeviceId();
    sessionToken = storage.sessionToken;
    licenseKey = storage.licenseKey;
    if (sessionToken.isEmpty) return false;
    final ok = await heartbeat(blockOnFailure: true);
    if (!ok) return false;
    startHeartbeat();
    return true;
  }

  Future<void> logoutLicense() async {
    stopHeartbeat();
    await storage.clearSession();
    sessionToken = '';
    licenseKey = '';
    wakeedToken = '';
  }

  void dispose() {
    stopHeartbeat();
    _client.close();
  }
}
