import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  String get sessionToken => _prefs.getString(prefsSessionToken) ?? '';
  String get deviceId => _prefs.getString(prefsDeviceId) ?? '';
  String get licenseKey => _prefs.getString(prefsLicenseKey) ?? '';

  Future<void> saveSession({required String sessionToken, required String licenseKey}) async {
    await _prefs.setString(prefsSessionToken, sessionToken);
    await _prefs.setString(prefsLicenseKey, licenseKey);
  }

  Future<void> saveDeviceId(String id) async {
    await _prefs.setString(prefsDeviceId, id);
  }

  Future<void> clearSession() async {
    await _prefs.remove(prefsSessionToken);
    await _prefs.remove(prefsLicenseKey);
  }

  Future<void> saveLastDialog(Map<String, dynamic>? data) async {
    if (data == null) {
      await _prefs.remove(prefsLastDialog);
      return;
    }
    await _prefs.setString(prefsLastDialog, jsonEncode(data));
  }

  Map<String, dynamic>? loadLastDialog() {
    final raw = _prefs.getString(prefsLastDialog);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
