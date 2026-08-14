import 'dart:convert';

import '../core/exceptions.dart';
import '../core/json_util.dart';
import '../models/models.dart';
import 'platform_service.dart';

class ApiService {
  ApiService(this.platform);

  final PlatformService platform;

  Future<Map<String, dynamic>> syncLoadAll() async {
    final json = await platform.platformFetch('/api/user-data');
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json;
    final settings = data['settings'] is Map ? Map<String, dynamic>.from(data['settings'] as Map) : <String, dynamic>{};
    final theme = (data['theme'] ?? 'dark').toString();
    final wakeed = data['wakeed'];
    if (wakeed is Map) {
      platform.ownerKey = (wakeed['ownerKey'] ?? '').toString();
      platform.username = (wakeed['username'] ?? '').toString();
      platform.server = (wakeed['server'] ?? defaultOr(platform.server)).toString();
      platform.buildNumber = (wakeed['buildNumber'] ?? platform.buildNumber).toString();
      platform.userDisplayName = (wakeed['userDisplayName'] ?? '').toString();
      platform.subscriptions = wakeed['subscriptions'] is List ? wakeed['subscriptions'] as List : [];
      platform.wakeedToken = wakeed['hasToken'] == true ? 'server-held' : '';
    }
    final ledgerJson = await platform.platformFetch('/api/ledger');
    final ledgerData =
        ledgerJson['data'] is Map ? Map<String, dynamic>.from(ledgerJson['data'] as Map) : ledgerJson;
    final rows = (ledgerData['rows'] is List) ? ledgerData['rows'] as List : [];
    final ledger = rows
        .whereType<Map>()
        .map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return {'settings': settings, 'theme': theme, 'ledger': ledger};
  }

  String defaultOr(String v) => v.isEmpty ? 'server1.wakeed.app' : v;

  Future<void> syncSaveSettings(Map<String, dynamic> settings, String theme) async {
    await platform.platformFetch(
      '/api/user-data',
      method: 'PUT',
      body: {'settings': settings, 'theme': theme},
    );
  }

  Future<void> syncSaveWakeed(Map<String, dynamic> partial) async {
    final wakeed = <String, dynamic>{
      'ownerKey': partial['ownerKey'] ?? platform.ownerKey,
      'username': partial['username'] ?? platform.username,
      'server': partial['server'] ?? platform.server,
      'buildNumber': partial['buildNumber'] ?? platform.buildNumber,
      'userDisplayName': partial['userDisplayName'] ?? platform.userDisplayName,
      'subscriptions': partial['subscriptions'] ?? platform.subscriptions,
    };
    if (partial.containsKey('token')) wakeed['token'] = partial['token'];
    await platform.platformFetch('/api/user-data', method: 'PUT', body: {'wakeed': wakeed});
  }

  Future<void> syncAppendLedger(List<LedgerEntry> entries) async {
    await platform.platformFetch(
      '/api/ledger',
      method: 'POST',
      body: {'entries': entries.map((e) => e.toJson()).toList()},
    );
  }

  Future<List<LedgerEntry>> syncGetLedger([String ownerKey = '']) async {
    final q = ownerKey.isNotEmpty ? '?ownerKey=${Uri.encodeComponent(ownerKey)}' : '';
    final json = await platform.platformFetch('/api/ledger$q');
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json;
    final rows = (data['rows'] is List) ? data['rows'] as List : [];
    return rows.whereType<Map>().map((row) => LedgerEntry.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  Future<Map<String, dynamic>> wakeedLogin(
    String username,
    String password, {
    String? server,
    String? buildNumber,
    String? ownerKey,
    String? deviceName,
  }) async {
    final json = await platform.platformFetch(
      '/api/wakeed/login',
      method: 'POST',
      body: {
        'username': username,
        'password': password,
        'server': server ?? platform.server,
        'buildNumber': buildNumber ?? platform.buildNumber,
        'ownerKey': ownerKey ?? platform.ownerKey,
        'deviceName': deviceName ?? 'WakeedMobile',
      },
    );
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json;
    platform.userDisplayName = (data['userDisplayName'] ?? '').toString();
    platform.subscriptions = data['subscriptions'] is List ? data['subscriptions'] as List : [];
    platform.ownerKey = (data['ownerKey'] ?? platform.ownerKey).toString();
    platform.wakeedToken = 'server-held';
    return data;
  }

  Future<void> wakeedLogout() async {
    await platform.platformFetch('/api/wakeed/logout', method: 'POST');
    platform.wakeedToken = '';
  }

  Future<dynamic> wakeedProxy(
    String method,
    String path, [
    dynamic body,
    Map<String, dynamic>? options,
  ]) async {
    final splitIndex = path.indexOf('?');
    final apiPath = splitIndex >= 0 ? path.substring(0, splitIndex) : path;
    final query = <String, dynamic>{};
    if (splitIndex >= 0) {
      final qs = Uri.splitQueryString(path.substring(splitIndex + 1));
      query.addAll(qs);
    }
    final payload = <String, dynamic>{
      'method': method,
      'path': apiPath,
      'query': query,
      'asForm': options?['asForm'] == true,
      'ownerKey': platform.ownerKey,
      'server': platform.server,
      'buildNumber': platform.buildNumber,
    };
    if (body != null) payload['body'] = body;
    final json = await platform.platformFetch('/api/wakeed/proxy', method: 'POST', body: payload);
    final wrapped = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json;
    final okFlag = wrapped['ok'];
    final inner = wrapped.containsKey('data') ? wrapped['data'] : wrapped;
    if (okFlag == false) {
      throw PlatformApiException(formatProxyError(inner));
    }
    // platformFetch already unwraps {ok:true, data:{ok,status,data}}
    // handle both shapes
    if (json['data'] is Map) {
      final d = json['data'] as Map;
      if (d['ok'] == false) {
        throw PlatformApiException(formatProxyError(d['data']));
      }
      return d.containsKey('data') ? d['data'] : d;
    }
    return json['data'] ?? json;
  }
}

Map<String, dynamic> jsonMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String) {
    try {
      final d = jsonDecode(v);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
  }
  return {};
}
