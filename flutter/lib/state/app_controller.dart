import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../core/exceptions.dart';
import '../core/journal_sync.dart';
import '../core/json_util.dart';
import '../core/remittance_parser.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/excel_export.dart';
import '../services/file_download.dart';
import '../services/notification_service.dart';
import '../services/platform_service.dart';

class AppController extends ChangeNotifier {
  AppController({required this.platform, required this.api, this.notifications});

  final PlatformService platform;
  final ApiService api;
  final NotificationService? notifications;

  AppPhase phase = AppPhase.boot;
  ThemeMode themeMode = ThemeMode.dark;
  bool busy = false;
  String loginStatus = 'جاهز للدخول';
  bool loginError = false;
  String licenseStatus = 'جهاز واحد لكل ترخيص';

  String username = '';
  String ownerKey = '';
  String debitAccount = '';
  String pendingDebitCode = '';
  String entryDate = todayInputValue();
  String journalTypeId = '';
  String costCenterId = '';
  bool useOpposite = true;
  bool includeCostCenter = true;

  String notesBatch = '';
  String notesEach = '';
  String tableBatch = '';
  String tableEach = '';
  List<ManualEntry> manualEntries = [];
  List<ManualEntry> chargeEntries = [];
  List<ProfitEntry> profitEntries = [];
  String notesProfit = '';
  String tableProfit = '';
  String profitMode = 'batch'; // batch | each
  num pendingConfirmProfit = 0;
  int pendingConfirmCount = 0;
  String pendingConfirmFor = '';
  String wakeedUserId = '';
  bool ledgerSyncing = false;

  bool connected = false;
  String connBadge = 'غير متصل';
  List<dynamic> journalTypes = [];
  List<Map<String, dynamic>> costCenters = [];
  dynamic currency;
  dynamic sampleDetail;
  dynamic sampleEntry;
  List<dynamic> accounts = [];
  Map<String, String> debitDefaults = {};
  String journalPostPath = '';
  final Map<String, dynamic> accountCache = {};
  List<WakeedSubscription> subscriptions = [];
  String selectedOwnerKey = '';

  List<LedgerEntry> serverLedgerCache = [];
  String ledgerSearch = '';
  String ledgerFrom = '';
  String ledgerTo = '';
  String ledgerKind = '';
  int ledgerPage = 0;

  Map<String, dynamic>? resolvedBatch;
  Map<String, dynamic>? resolvedEach;
  Map<String, dynamic>? resolvedManual;
  Map<String, dynamic>? resolvedCharge;
  Map<String, dynamic>? resolvedProfit;

  final SubmitJob submitJob = SubmitJob();
  AccountPickTarget accountPickTarget = AccountPickTarget.debit();

  String createTab = 'batch'; // batch | each | manual | charge | profit | ledger
  PreparedJournal? pendingConfirmPrepared;

  Timer? _saveTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Future<bool>? _connectPromise;

  bool get isDark => themeMode == ThemeMode.dark;

  void _emit() => notifyListeners();

  Future<void> boot() async {
    platform.onBlock = (message, code) {
      if (submitJob.active && code == 'offline') return;
      phase = AppPhase.blocked;
      _emit();
    };
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final none = results.every((r) => r == ConnectivityResult.none);
      if (none || platform.paused) return;
      if (platform.blocked) {
        await retryBlock();
      }
    });

    final hasSession = await platform.initPlatform();
    if (platform.blocked) {
      phase = AppPhase.blocked;
      _emit();
      return;
    }
    if (!hasSession) {
      phase = AppPhase.license;
      _emit();
      return;
    }
    await _bootApp();
    _restorePersistedDialog();
  }

  Future<void> handleLifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        platform.paused = true;
        break;
      case AppLifecycleState.resumed:
        platform.paused = false;
        if (platform.blocked) {
          await retryBlock(silent: true);
        } else if (platform.sessionToken.isNotEmpty) {
          await platform.heartbeat(blockOnFailure: false);
        }
        _restorePersistedDialog();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _bootApp() async {
    if (platform.blocked) return;
    createTab = 'batch';
    await loadLocal();
    ensureManualEntries();
    ensureProfitEntries();
    if (platform.wakeedToken.isNotEmpty) {
      loginStatus = 'جارٍ استعادة الجلسة...';
      loginError = false;
      _emit();
      try {
        final ok = await connect();
        if (!ok) {
          phase = AppPhase.login;
          _emit();
        }
      } catch (_) {
        phase = AppPhase.login;
        _emit();
      }
    } else {
      phase = AppPhase.login;
      _emit();
    }
  }

  Future<void> activateLicense(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      licenseStatus = 'أدخل مفتاح الترخيص.';
      _emit();
      return;
    }
    licenseStatus = 'جارٍ التفعيل...';
    busy = true;
    _emit();
    try {
      await platform.activateLicense(trimmed);
      licenseStatus = 'تم التفعيل.';
      busy = false;
      await _bootApp();
    } catch (err) {
      licenseStatus = err.toString();
      busy = false;
      _emit();
    }
  }

  Future<void> retryBlock({bool silent = false}) async {
    if (!silent) {
      busy = true;
      _emit();
    }
    var ok = false;
    for (var i = 0; i < 3; i++) {
      ok = await platform.heartbeat(blockOnFailure: false);
      if (ok) break;
      await Future<void>.delayed(Duration(milliseconds: 600 * (i + 1)));
    }
    if (!ok) {
      ok = await platform.restoreLicenseSession();
    }
    if (!ok) {
      await platform.heartbeat(blockOnFailure: true);
    }
    if (!silent) busy = false;
    if (ok) {
      platform.unblockApp();
      platform.startHeartbeat();
      if (connected) {
        phase = AppPhase.home;
      } else if (platform.sessionToken.isNotEmpty) {
        if (platform.wakeedToken.isNotEmpty) {
          await connect();
        } else {
          phase = AppPhase.login;
        }
      } else {
        phase = AppPhase.license;
      }
    }
    _emit();
  }

  Future<void> enterNewLicense() async {
    await platform.logoutLicense();
    platform.unblockApp();
    phase = AppPhase.license;
    licenseStatus = 'أدخل مفتاح الترخيص الجديد.';
    busy = false;
    _emit();
  }

  Future<void> login(String user, String password) async {
    username = user.trim();
    if (username.isEmpty || password.isEmpty) {
      loginStatus = 'أدخل البريد/اسم المستخدم وكلمة المرور.';
      loginError = true;
      _emit();
      return;
    }
    busy = true;
    loginStatus = 'جارٍ تسجيل الدخول إلى وكيد...';
    loginError = false;
    _emit();
    try {
      final data = await api.wakeedLogin(
        username,
        password,
        server: platform.server,
        buildNumber: platform.buildNumber,
        ownerKey: ownerKey,
        deviceName: platform.deviceName,
      );
      applySessionIdentity({
        'userDisplayName': data['userDisplayName'],
        'subscriptions': data['subscriptions'],
      });
      fillSubscriptions(data['subscriptions'], data['ownerKey']?.toString());
      if (ownerKey.isEmpty && data['ownerKey'] != null) {
        ownerKey = data['ownerKey'].toString();
        selectedOwnerKey = ownerKey;
        platform.ownerKey = ownerKey;
      }
      await saveLocal();
      final name = platform.userDisplayName.isNotEmpty ? platform.userDisplayName : username;
      loginStatus = 'تم الدخول باسم $name. جارٍ تحميل بيانات الشركة...';
      _emit();
      if (credentialsOwnerKey().isEmpty) {
        loginStatus = 'تم الدخول لكن لم يُعثر على شركة مرتبطة بالحساب.';
        loginError = true;
        busy = false;
        _emit();
        return;
      }
      final ok = await connect();
      if (!ok) throw PlatformApiException('تعذر تحميل بيانات الشركة من وكيد.');
    } catch (err) {
      if (!connected) {
        connBadge = 'فشل الدخول';
        loginStatus = err.toString();
        loginError = true;
        phase = AppPhase.login;
      }
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> logout() async {
    try {
      await api.wakeedLogout();
    } catch (_) {}
    ownerKey = '';
    selectedOwnerKey = '';
    connected = false;
    platform.userDisplayName = '';
    platform.subscriptions = [];
    platform.wakeedToken = '';
    accountCache.clear();
    subscriptions = [];
    connBadge = 'غير متصل';
    loginStatus = 'تم تسجيل الخروج. أدخل حساب وكيد للدخول مجدداً.';
    loginError = false;
    phase = AppPhase.login;
    _emit();
  }

  String credentialsOwnerKey() {
    final fromSub = selectedOwnerKey;
    final variants = ownerKeyVariants(fromSub.isNotEmpty ? fromSub : ownerKey);
    return variants.isEmpty ? '' : variants.first;
  }

  String currentOwnerKey() => credentialsOwnerKey().isNotEmpty ? credentialsOwnerKey() : ownerKey;

  void applySessionIdentity(Map<String, dynamic> data) {
    final name = (data['userDisplayName'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      platform.userDisplayName = name;
    } else if (platform.userDisplayName.trim().isEmpty && username.trim().isNotEmpty) {
      platform.userDisplayName = username.trim();
    }
    if (data['subscriptions'] is List && (data['subscriptions'] as List).isNotEmpty) {
      platform.subscriptions = data['subscriptions'] as List;
    }
  }

  List<WakeedSubscription> mapSubscriptions(dynamic list) {
    return asList(list)
        .whereType<Map>()
        .map((item) {
          final owner = extractOwnerKey(
            item['ownerKey'] ?? item['OwnerKey'] ?? item['owner_key'] ?? item['id'] ?? '',
          );
          final rawName = (item['name'] ?? item['Name'] ?? '').toString().trim();
          final picked = rawName.isNotEmpty ? rawName : pickSubscriptionNameClient(item);
          final name = picked.isNotEmpty &&
                  picked != owner &&
                  !RegExp(r'^owner[_-]', caseSensitive: false).hasMatch(picked)
              ? picked
              : '';
          return WakeedSubscription(
            id: (item['id'] ?? item['Id'] ?? '').toString(),
            name: name,
            ownerKey: owner,
          );
        })
        .where((s) => s.ownerKey.isNotEmpty)
        .toList();
  }

  String get displayUserName {
    final n = platform.userDisplayName.trim();
    if (n.isNotEmpty) return n;
    return username.trim();
  }

  String subscriptionLabel(WakeedSubscription sub) {
    final name = sub.name.trim();
    if (name.isNotEmpty &&
        name != sub.ownerKey &&
        !RegExp(r'^owner[_-]', caseSensitive: false).hasMatch(name)) {
      return name;
    }
    if (displayUserName.isNotEmpty) return displayUserName;
    if (sub.ownerKey.isNotEmpty) {
      final key = sub.ownerKey.replaceFirst(RegExp(r'^owner[_-]', caseSensitive: false), '');
      return key.isNotEmpty ? key : sub.ownerKey;
    }
    return 'حساب وكيد';
  }

  void fillSubscriptions(dynamic list, [String? preferred]) {
    final items = mapSubscriptions(list);
    subscriptions = items;
    if (items.isEmpty) {
      _emit();
      return;
    }
    final pref = preferred ?? items.first.ownerKey;
    final found = items.any((s) => s.ownerKey == pref) ? pref : items.first.ownerKey;
    selectedOwnerKey = found;
    ownerKey = found;
    platform.ownerKey = found;
    syncSessionBadge();
    _emit();
  }

  Future<void> selectSubscription(String key) async {
    selectedOwnerKey = key;
    ownerKey = key;
    platform.ownerKey = key;
    if (platform.wakeedToken.isNotEmpty) {
      await connect();
    } else {
      fillDebitAccounts();
    }
    _emit();
  }

  void syncSessionBadge([String currencyName = '']) {
    if (!connected && platform.wakeedToken.isEmpty) return;
    final user = displayUserName;
    final company = currentCompanyName();
    final display = user.isNotEmpty
        ? user
        : (company.isNotEmpty && company != 'حساب وكيد' ? company : '');
    var label = 'متصل';
    if (display.isNotEmpty) {
      label += ' · $display';
    } else if (currencyName.isNotEmpty) {
      label += ' · $currencyName';
    }
    connected = true;
    connBadge = label;
  }

  String currentCompanyName() {
    final key = selectedOwnerKey.isNotEmpty ? selectedOwnerKey : ownerKey;
    final sub = subscriptions.where((s) => s.ownerKey == key).toList();
    if (sub.isNotEmpty) return subscriptionLabel(sub.first);
    return '';
  }

  Future<void> saveLocal() async {
    if (platform.sessionToken.isEmpty) return;
    final settings = {
      'ownerKey': ownerKey,
      'username': username,
      'debitAccount': debitAccount,
      'debitDefaults': debitDefaults,
      'notes': notesBatch,
      'notesEach': notesEach,
      'table': tableBatch,
      'tableEach': tableEach,
      'manualEntries': manualEntries.map((e) => e.toJson()).toList(),
      'chargeEntries': chargeEntries.map((e) => e.toJson()).toList(),
      'profitEntries': profitEntries.map((e) => e.toJson()).toList(),
      'notesProfit': notesProfit,
      'tableProfit': tableProfit,
      'profitMode': profitMode,
      'userDisplayName': platform.userDisplayName,
      'subscriptions': platform.subscriptions,
    };
    try {
      await api.syncSaveSettings(settings, isDark ? 'dark' : 'light');
      await api.syncSaveWakeed({
        'ownerKey': ownerKey,
        'username': username,
        'server': platform.server,
        'buildNumber': platform.buildNumber,
        'userDisplayName': platform.userDisplayName,
        'subscriptions': platform.subscriptions,
      });
    } catch (_) {}
  }

  void scheduleSaveLocal() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      saveLocal();
    });
  }

  Future<void> loadLocal() async {
    if (platform.sessionToken.isEmpty) return;
    try {
      final data = await api.syncLoadAll();
      final settings = data['settings'] is Map ? data['settings'] as Map<String, dynamic> : <String, dynamic>{};
      if (settings['ownerKey'] != null) ownerKey = settings['ownerKey'].toString();
      if (settings['username'] != null) username = settings['username'].toString();
      if (settings['debitDefaults'] is Map) {
        debitDefaults = (settings['debitDefaults'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      if (settings['debitAccount'] != null) pendingDebitCode = settings['debitAccount'].toString();
      if (settings['notes'] != null) notesBatch = settings['notes'].toString();
      if (settings['notesEach'] != null) notesEach = settings['notesEach'].toString();
      if (settings['userDisplayName'] != null) {
        platform.userDisplayName = settings['userDisplayName'].toString();
      }
      if (platform.userDisplayName.trim().isEmpty && username.trim().isNotEmpty) {
        platform.userDisplayName = username.trim();
      }
      if (settings['subscriptions'] is List) platform.subscriptions = settings['subscriptions'] as List;
      if (settings['manualEntries'] is List && (settings['manualEntries'] as List).isNotEmpty) {
        manualEntries = (settings['manualEntries'] as List)
            .whereType<Map>()
            .map((e) => ManualEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (settings['chargeEntries'] is List && (settings['chargeEntries'] as List).isNotEmpty) {
        chargeEntries = (settings['chargeEntries'] as List)
            .whereType<Map>()
            .map((e) => ManualEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (settings['profitEntries'] is List && (settings['profitEntries'] as List).isNotEmpty) {
        profitEntries = (settings['profitEntries'] as List)
            .whereType<Map>()
            .map((e) => ProfitEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (settings['notesProfit'] != null) notesProfit = settings['notesProfit'].toString();
      if (settings['tableProfit'] != null) tableProfit = settings['tableProfit'].toString();
      if (settings['profitMode'] == 'each' || settings['profitMode'] == 'batch') {
        profitMode = settings['profitMode'].toString();
      }
      if (settings['table'] != null) tableBatch = settings['table'].toString();
      if (settings['tableEach'] != null) tableEach = settings['tableEach'].toString();
      if (platform.ownerKey.isNotEmpty && ownerKey.isEmpty) ownerKey = platform.ownerKey;
      if (platform.subscriptions.isNotEmpty) {
        fillSubscriptions(platform.subscriptions, settings['ownerKey']?.toString() ?? platform.ownerKey);
      }
      if (data['theme'] == 'light') themeMode = ThemeMode.light;
      final cached = platform.storage.loadLedgerCache();
      if (cached.isNotEmpty) {
        serverLedgerCache = cached.map(LedgerEntry.fromJson).toList();
      }
    } catch (_) {}
  }

  Future<bool> connect() async {
    if (_connectPromise != null) return _connectPromise!;
    _connectPromise = _connectOnce().whenComplete(() => _connectPromise = null);
    return _connectPromise!;
  }

  Future<dynamic> _api(String method, String path, [dynamic body, Map<String, dynamic>? options]) {
    return api.wakeedProxy(method, path, body, options);
  }

  Future<bool> _connectOnce() async {
    if (platform.wakeedToken.isEmpty || credentialsOwnerKey().isEmpty) {
      loginStatus = 'سجّل الدخول أولاً.';
      loginError = true;
      _emit();
      return false;
    }
    loginStatus = 'جارٍ الاتصال بخادم وكيد...';
    loginError = false;
    _emit();
    try {
      final results = await Future.wait([
        _api('GET', '/api/JournalType'),
        _api('GET', '/api/Currency/GetBaseCurrency'),
        _api('GET', '/api/CostCenter/GetTree').catchError((_) => []),
        _api('GET', '/api/JournalEntry/GetLast').catchError((_) => null),
        _api('GET', '/api/NormalAccount?leafNormalAccounts=true&withBalance=false').catchError((_) => null),
      ]);
      final types = results[0];
      currency = results[1];
      final centers = results[2];
      sampleEntry = results[3];
      final accountsRaw = results[4];

      journalTypes = types is List ? types : [];
      costCenters = flattenCostCenters(centers is List ? centers : []);
      final details = sampleEntry is Map
          ? (sampleEntry['JournalEntryDetails'] ?? sampleEntry['journalEntryDetails'] ?? [])
          : [];
      sampleDetail = (details is List && details.isNotEmpty) ? details.first : null;
      accountCache.clear();
      accounts = flattenAccounts(asList(accountsRaw));
      if (accounts.isEmpty) {
        await loadChartAccounts();
      } else {
        accounts.sort((a, b) => pickAccountCode(a).compareTo(pickAccountCode(b)));
        for (final acc in accounts) {
          final code = pickAccountCode(acc);
          if (code.isNotEmpty) accountCache[code] = acc;
        }
        fillDebitAccounts();
      }

      if (journalTypes.isNotEmpty) {
        final remit = journalTypes.where(isRemittanceType).toList();
        journalTypeId = pickId(remit.isNotEmpty ? remit.first : journalTypes.first);
      }

      final preferredCenter = () {
        final t = currentJournalType();
        if (t is Map && (t['CostCenterId'] ?? t['costCenterId']) != null) {
          return (t['CostCenterId'] ?? t['costCenterId']).toString();
        }
        if (sampleDetail is Map) {
          return (sampleDetail['CostCenterId'] ??
                  sampleDetail['costCenterId'] ??
                  sampleDetail['costCenterID'] ??
                  '')
              .toString();
        }
        return '';
      }();
      if (preferredCenter.isNotEmpty) costCenterId = preferredCenter;

      connected = true;
      await refreshSessionIdentity();
      final curName = currency is Map
          ? (currency['Code'] ?? currency['Name'] ?? 'عملة الأساس').toString()
          : 'عملة الأساس';
      syncSessionBadge(curName);
      await saveLocal();
      final who = platform.userDisplayName.isNotEmpty ? platform.userDisplayName : currentCompanyName();
      loginStatus = '${who.isNotEmpty ? 'مرحباً $who. ' : 'تم الاتصال. '}العملة: $curName';
      loginError = false;
      phase = AppPhase.home;
      _emit();
      unawaited(syncWakeedJournals());
      return true;
    } catch (err) {
      connected = false;
      connBadge = 'فشل الاتصال';
      loginStatus = err.toString();
      loginError = true;
      phase = AppPhase.login;
      _emit();
      return false;
    }
  }

  dynamic currentJournalType() {
    for (final t in journalTypes) {
      if (pickId(t) == journalTypeId) return t;
    }
    return null;
  }

  Future<void> refreshSessionIdentity() async {
    if (platform.wakeedToken.isEmpty || credentialsOwnerKey().isEmpty) return;
    try {
      final results = await Future.wait([
        _api('GET', '/api/Users/profile').catchError((_) => null),
        _api('GET', '/user-api/my-subscriptions').catchError((_) => null),
      ]);
      final profile = results[0];
      final user = profile is Map ? (profile['data'] ?? profile['user'] ?? profile) : null;
      if (user is Map) {
        final id = (user['id'] ?? user['Id'] ?? user['userId'] ?? user['UserId'] ?? '').toString();
        if (id.isNotEmpty) wakeedUserId = id;
        final name = pickUserDisplayName(user);
        final userName = (user['userName'] ?? user['UserName'] ?? user['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          platform.userDisplayName = name;
        } else if (userName.isNotEmpty) {
          platform.userDisplayName = userName;
        }
      }
      final subs = mapSubscriptions(asList(results[1]));
      if (subs.isNotEmpty) {
        subscriptions = subs;
        platform.subscriptions = subs.map((s) => s.toJson()).toList();
        fillSubscriptions(platform.subscriptions, selectedOwnerKey.isNotEmpty ? selectedOwnerKey : ownerKey);
      }
      await saveLocal();
      syncSessionBadge();
    } catch (_) {}
  }

  Future<void> loadChartAccounts() async {
    const attempts = [
      '/api/NormalAccount?leafNormalAccounts=true&withBalance=false',
      '/api/NormalAccount?leafNormalAccounts=true',
      '/api/NormalAccount',
    ];
    var list = <dynamic>[];
    for (final path in attempts) {
      try {
        final data = await _api('GET', path);
        list = flattenAccounts(asList(data));
        if (list.isNotEmpty) break;
      } catch (_) {}
    }
    list.sort((a, b) => pickAccountCode(a).compareTo(pickAccountCode(b)));
    accounts = list;
    for (final acc in list) {
      final code = pickAccountCode(acc);
      if (code.isNotEmpty) accountCache[code] = acc;
    }
    fillDebitAccounts();
  }

  String preferredDebitCode() {
    final owner = currentOwnerKey();
    if (owner.isNotEmpty && debitDefaults[owner] != null && debitDefaults[owner]!.isNotEmpty) {
      return debitDefaults[owner]!;
    }
    return pendingDebitCode;
  }

  void fillDebitAccounts() {
    final preferred = preferredDebitCode();
    if (preferred.isNotEmpty && accounts.any((a) => pickAccountCode(a) == preferred)) {
      debitAccount = preferred;
    } else if (debitAccount.isEmpty && accounts.isNotEmpty) {
      final fallback = accounts.firstWhere(
        (a) => pickAccountCode(a) == defaultDebitFallback,
        orElse: () => accounts.first,
      );
      debitAccount = pickAccountCode(fallback);
    }
    _emit();
  }

  String debitAccountLabel() {
    final selected = accounts.where((a) => pickAccountCode(a) == debitAccount).toList();
    if (selected.isNotEmpty) return accountLabel(selected.first);
    if (debitAccount.isNotEmpty) return debitAccount;
    if (accounts.isNotEmpty) return 'اختر من دليل الحسابات';
    return 'يُحمَّل الدليل بعد الدخول';
  }

  bool _accountCodeMatches(String left, String right) {
    final a = normalizeAccountKey(left);
    final b = normalizeAccountKey(right);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final an = int.tryParse(a);
    final bn = int.tryParse(b);
    return an != null && bn != null && an == bn;
  }

  dynamic _accountByCode(String key) {
    if (key.isEmpty) return null;
    final cached = accountCache[key];
    if (cached != null) return cached;
    for (final entry in accountCache.entries) {
      if (_accountCodeMatches(entry.key, key)) return entry.value;
    }
    for (final a in accounts) {
      if (_accountCodeMatches(pickAccountCode(a), key)) return a;
    }
    for (final map in [resolvedProfit, resolvedCharge, resolvedManual, resolvedEach, resolvedBatch]) {
      if (map == null) continue;
      final direct = map[key];
      if (direct != null) return direct;
      for (final entry in map.entries) {
        if (_accountCodeMatches(entry.key, key)) return entry.value;
      }
    }
    return null;
  }

  void _rememberResolved(Map<String, dynamic> resolved) {
    for (final entry in resolved.entries) {
      if (entry.key.isEmpty || entry.value == null) continue;
      accountCache[entry.key] = entry.value;
      final code = pickAccountCode(entry.value);
      if (code.isNotEmpty) accountCache[code] = entry.value;
    }
  }

  String chartAccountName(String code) {
    final key = normalizeAccountKey(code);
    if (key.isEmpty) return '';
    final acc = _accountByCode(key);
    if (acc != null) {
      final name = accountNameOf(acc);
      if (name.isNotEmpty && name != key) return name;
    }
    for (final map in [resolvedProfit, resolvedCharge, resolvedManual, resolvedEach, resolvedBatch]) {
      final label = resolvedLabel(map, key);
      if (label.isEmpty || label == 'لم يُحل بعد') continue;
      final sep = label.indexOf(' — ');
      if (sep >= 0) {
        final name = label.substring(sep + 3).trim();
        if (name.isNotEmpty) return name;
      }
      if (label != key) return label;
    }
    return '';
  }

  String debitDefaultHint() {
    final owner = currentOwnerKey();
    final code = owner.isNotEmpty ? debitDefaults[owner] : null;
    if (code == null || code.isEmpty) return 'لم يُحفظ افتراضي بعد.';
    final acc = accounts.where((a) => pickAccountCode(a) == code).toList();
    return 'الافتراضي: ${acc.isNotEmpty ? accountLabel(acc.first) : code}';
  }

  void selectDebitAccount(String code) {
    final value = code.trim();
    if (value.isEmpty) return;
    debitAccount = value;
    pendingDebitCode = value;
    saveLocal();
    _emit();
  }

  void saveDebitDefault() {
    final code = debitAccount.trim();
    final owner = currentOwnerKey();
    if (code.isEmpty) {
      showSubmitError('حساب افتراضي', 'اختر حساباً من الدليل ثم احفظه كافتراضي.');
      return;
    }
    if (owner.isEmpty) {
      showSubmitError('غير متصل', 'سجّل الدخول أولاً.');
      return;
    }
    debitDefaults[owner] = code;
    saveLocal();
    showSubmitSuccess('تم الحفظ', 'تم حفظ الحساب الافتراضي.', debitAccountLabel());
  }

  List<dynamic> filteredAccounts(String filter) {
    final q = filter.trim().toLowerCase();
    if (q.isEmpty) return accounts;
    return accounts.where((a) {
      return accountLabel(a).toLowerCase().contains(q) || pickAccountCode(a).toLowerCase().contains(q);
    }).toList();
  }

  void setUseOpposite(bool v) {
    useOpposite = v;
    _emit();
  }

  void setIncludeCostCenter(bool v) {
    includeCostCenter = v;
    _emit();
  }

  void setLedgerSearch(String v) {
    ledgerSearch = v;
    ledgerPage = 0;
    _emit();
  }

  void setLedgerFrom(String v) {
    ledgerFrom = v;
    ledgerPage = 0;
    _emit();
  }

  void setLedgerTo(String v) {
    ledgerTo = v;
    ledgerPage = 0;
    _emit();
  }

  void setLedgerKindFilter(String v) {
    ledgerKind = v;
    ledgerPage = 0;
    _emit();
  }

  void setLedgerPage(int page) {
    if (page < 0) page = 0;
    ledgerPage = page;
    _emit();
  }

  void toggleTheme() {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    saveLocal();
    _emit();
  }

  void setTab(String tab) {
    createTab = tab;
    if (tab == 'profit') ensureProfitEntries();
    _emit();
  }

  void setProfitMode(String mode) {
    profitMode = mode == 'each' ? 'each' : 'batch';
    if (profitMode == 'each') ensureProfitEntries();
    scheduleSaveLocal();
    _emit();
  }

  void setTableBatch(String v) {
    tableBatch = v;
    resolvedBatch = null;
    _emit();
  }

  void setTableEach(String v) {
    tableEach = v;
    resolvedEach = null;
    _emit();
  }

  void setNotesBatch(String v) {
    notesBatch = v;
    scheduleSaveLocal();
    _emit();
  }

  void setNotesEach(String v) {
    notesEach = v;
    scheduleSaveLocal();
    _emit();
  }

  void setNotesProfit(String v) {
    notesProfit = v;
    scheduleSaveLocal();
    _emit();
  }

  void setTableProfit(String v) {
    tableProfit = v;
    resolvedProfit = null;
    _emit();
  }

  void setEntryDate(String v) {
    entryDate = v;
    _emit();
  }

  void setJournalType(String id) {
    journalTypeId = id;
    final type = currentJournalType();
    if (type is Map) {
      final centerId = (type['CostCenterId'] ?? type['costCenterId'])?.toString();
      if (centerId != null &&
          centerId.isNotEmpty &&
          costCenters.any((c) => c['Id'].toString() == centerId)) {
        costCenterId = centerId;
      }
    }
    _emit();
  }

  void setCostCenter(String id) {
    costCenterId = id;
    _emit();
  }

  List<JournalRow> currentRows(String source) {
    final debitAcc = debitAccount.trim();
    final text = source == 'each' ? tableEach : tableBatch;
    return parseRowsFromTable(text, debitAcc, defaultCreditAccount);
  }

  Map<String, num> totals(List<JournalRow> rows) {
    num debit = 0;
    num credit = 0;
    for (final row in rows) {
      debit += numOf(row.debit);
      credit += numOf(row.credit);
    }
    return {'debit': debit, 'credit': credit};
  }

  String sectionNote(String section) {
    if (section == 'each') return notesEach.trim();
    if (section == 'batch') return notesBatch.trim();
    if (section == 'profit') return notesProfit.trim();
    return '';
  }

  String composeNote(String name, [String extra = '']) {
    final note = extra.trim();
    final who = name.trim();
    if (who.isNotEmpty && note.isNotEmpty) return '$who — $note';
    return who.isNotEmpty ? who : note;
  }

  String groupClientNote(CustomerGroup group) {
    return (group.rows[0].clientNote.isNotEmpty ? group.rows[0].clientNote : group.rows[1].clientNote)
        .trim();
  }

  String groupStatement(CustomerGroup group, String section) {
    final extra = (section == 'manual' || section == 'charge' || section == 'profit')
        ? groupClientNote(group)
        : sectionNote(section);
    return composeNote(group.name, extra);
  }

  String notesPreviewText(String section) {
    final extra = sectionNote(section);
    return extra.isNotEmpty
        ? 'ستظهر في البيان: اسم العميل — $extra'
        : 'بدون ملاحظة إضافية — سيظهر اسم العميل كبيان.';
  }

  void ensureChargeEntries() {
    if (chargeEntries.isEmpty) {
      chargeEntries = [ManualEntry(id: manualEntryId())];
    }
  }

  void addChargeEntry() {
    ensureChargeEntries();
    chargeEntries.add(ManualEntry(id: manualEntryId()));
    saveLocal();
    _emit();
  }

  void removeChargeEntry(String id) {
    if (chargeEntries.length <= 1) return;
    chargeEntries = chargeEntries.where((e) => e.id != id).toList();
    saveLocal();
    _emit();
  }

  void updateChargeEntry(ManualEntry entry) {
    final i = chargeEntries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) chargeEntries[i] = entry;
    resolvedManual = null;
    scheduleSaveLocal();
    _emit();
  }

  List<JournalRow> chargeRows() {
    final rows = <JournalRow>[];
    for (final entry in chargeEntries) {
      final name = entry.name.trim();
      final debit = entry.debit.trim();
      final credit = entry.credit.trim();
      final amt = cleanAmount(entry.amount);
      if (name.isEmpty || amt.isEmpty || debit.isEmpty || credit.isEmpty) continue;
      final clientNote = entry.note.trim();
      rows.add(JournalRow(
        account: debit,
        description: name,
        debit: amt,
        credit: '',
        clientNote: clientNote,
      ));
      rows.add(JournalRow(
        account: credit,
        description: name,
        debit: '',
        credit: amt,
        clientNote: clientNote,
      ));
    }
    return rows;
  }

  void clearChargeForm() {
    chargeEntries = [ManualEntry(id: manualEntryId())];
    saveLocal();
    _emit();
  }

  void ensureProfitEntries() {
    if (profitEntries.isEmpty) {
      profitEntries = [ProfitEntry(id: manualEntryId())];
    }
  }

  void addProfitEntry() {
    ensureProfitEntries();
    profitEntries.add(ProfitEntry(id: manualEntryId()));
    saveLocal();
    _emit();
  }

  void removeProfitEntry(String id) {
    if (profitEntries.length <= 1) return;
    profitEntries = profitEntries.where((e) => e.id != id).toList();
    saveLocal();
    _emit();
  }

  void updateProfitEntry(ProfitEntry entry) {
    final i = profitEntries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) profitEntries[i] = entry;
    resolvedProfit = null;
    scheduleSaveLocal();
    _emit();
  }

  void clearProfitForm() {
    if (profitMode == 'each') {
      profitEntries = [ProfitEntry(id: manualEntryId())];
    } else {
      notesProfit = '';
      tableProfit = '';
    }
    resolvedProfit = null;
    saveLocal();
    _emit();
  }

  List<ProfitPasteRow> currentProfitPaste() {
    if (profitMode == 'each') {
      return [
        for (final entry in profitEntries)
          ProfitPasteRow(
            name: entry.name.trim().isNotEmpty
                ? entry.name.trim()
                : (entry.credit.trim().isNotEmpty && entry.debit.trim().isNotEmpty
                    ? '${entry.credit} / ${entry.debit}'
                    : ''),
            credit: entry.credit,
            creditAmount: entry.creditAmount,
            debit: entry.debit,
            debitAmount: entry.debitAmount,
            note: entry.note,
          ),
      ].where((e) => e.isComplete).toList();
    }
    return parseProfitTable(tableProfit);
  }

  List<JournalRow> profitRows() {
    return buildProfitJournalRows(currentProfitPaste());
  }

  void ensureManualEntries() {
    if (manualEntries.isEmpty) {
      manualEntries = [ManualEntry(id: manualEntryId())];
    }
  }

  void addManualEntry() {
    ensureManualEntries();
    manualEntries.add(ManualEntry(id: manualEntryId()));
    saveLocal();
    _emit();
  }

  void removeManualEntry(String id) {
    if (manualEntries.length <= 1) return;
    manualEntries = manualEntries.where((e) => e.id != id).toList();
    saveLocal();
    _emit();
  }

  void updateManualEntry(ManualEntry entry) {
    final i = manualEntries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) manualEntries[i] = entry;
    resolvedManual = null;
    scheduleSaveLocal();
    _emit();
  }

  List<JournalRow> manualRows() {
    final debitAcc = debitAccount.trim();
    final rows = <JournalRow>[];
    for (final entry in manualEntries) {
      final name = entry.name.trim();
      final credit = entry.credit.trim();
      final amt = cleanAmount(entry.amount);
      if (name.isEmpty || amt.isEmpty || credit.isEmpty) continue;
      final clientNote = entry.note.trim();
      rows.add(JournalRow(
        account: debitAcc,
        description: name,
        debit: amt,
        credit: '',
        clientNote: clientNote,
      ));
      rows.add(JournalRow(
        account: credit,
        description: name,
        debit: '',
        credit: amt,
        clientNote: clientNote,
      ));
    }
    return rows;
  }

  Future<dynamic> resolveAccount(String query) async {
    final key = normalizeAccountKey(query);
    if (key.isEmpty) throw PlatformApiException('حساب فارغ');
    if (accountCache.containsKey(key)) return accountCache[key];
    final fromChart = accounts.where((a) => pickAccountCode(a) == key).toList();
    if (fromChart.isNotEmpty && pickId(fromChart.first).isNotEmpty) {
      accountCache[key] = fromChart.first;
      return fromChart.first;
    }
    dynamic found;
    if (RegExp(r'^\d').hasMatch(key)) {
      try {
        found = await _api('GET', '/api/NormalAccount/GetByCode?code=${Uri.encodeComponent(key)}');
      } catch (_) {
        found = null;
      }
    }
    if (found == null || pickId(found).isEmpty) {
      try {
        final list = asList(await _api(
          'GET',
          '/api/NormalAccount?accountName=${Uri.encodeComponent(key)}&nameOrCode=${Uri.encodeComponent(key)}&limit=20',
        ));
        found = list.firstWhere(
          (a) => (a is Map) && (a['AccountCode'] ?? a['Code'] ?? a['accountCode'] ?? '').toString() == key,
          orElse: () => list.firstWhere(
            (a) => (a is Map) && (a['AccountName'] ?? a['Name'] ?? a['accountName'] ?? '').toString() == key,
            orElse: () => list.isNotEmpty ? list.first : null,
          ),
        );
      } catch (_) {
        found = null;
      }
    }
    if (found == null || pickId(found).isEmpty) {
      throw PlatformApiException('تعذر إيجاد الحساب: $key');
    }
    accountCache[key] = found;
    return found;
  }

  Future<Map<String, dynamic>> resolveRows(List<JournalRow> rows) async {
    final unique = rows.map((r) => normalizeAccountKey(r.account)).where((k) => k.isNotEmpty).toSet();
    final map = <String, dynamic>{};
    await Future.wait(unique.map((acc) async {
      map[acc] = await resolveAccount(acc);
    }));
    return map;
  }

  String resolvedLabel(Map<String, dynamic>? resolved, String account) {
    final acc = resolved?[normalizeAccountKey(account)];
    if (acc == null) return 'لم يُحل بعد';
    final code = (acc['AccountCode'] ?? acc['Code'] ?? acc['accountCode'] ?? account).toString();
    final name = (acc['AccountName'] ?? acc['Name'] ?? acc['accountName'] ?? '').toString();
    return name.isEmpty ? code : '$code — $name';
  }

  void clearBatchForm() {
    notesBatch = '';
    tableBatch = '';
    resolvedBatch = null;
    saveLocal();
    _emit();
  }

  void clearEachForm() {
    notesEach = '';
    tableEach = '';
    resolvedEach = null;
    saveLocal();
    _emit();
  }

  void clearManualForm() {
    manualEntries = [ManualEntry(id: manualEntryId())];
    resolvedManual = null;
    saveLocal();
    _emit();
  }

  String selectedCostCenterId() {
    if (!includeCostCenter) return '';
    if (costCenterId.isNotEmpty) return costCenterId;
    final t = currentJournalType();
    if (t is Map) {
      final v = t['CostCenterId'] ?? t['costCenterId'];
      if (v != null) return v.toString();
    }
    if (sampleDetail is Map) {
      return (sampleDetail['CostCenterId'] ??
              sampleDetail['costCenterId'] ??
              sampleDetail['costCenterID'] ??
              '')
          .toString();
    }
    return '';
  }

  Map<String, dynamic> buildDetail(
    JournalRow row,
    dynamic account,
    int index,
    String dateIso,
    Map<String, dynamic> extras,
  ) {
    final amount = numOf(row.debit.isNotEmpty ? row.debit : row.credit);
    final isDebit = row.debit.isNotEmpty;
    final currencyId = pickId(currency);
    final rate = numOf(currency is Map ? (currency['Rate'] ?? currency['rate'] ?? 1) : 1);
    final accountId = pickId(account);
    final note = extras['lineNote'] ??
        composeNote(
          row.description,
          extras['section'] == 'manual' || extras['section'] == 'charge' || extras['section'] == 'profit'
              ? row.clientNote
              : sectionNote((extras['section'] ?? 'batch').toString()),
        );
    final detail = <String, dynamic>{
      'normalAccountId': accountId,
      'AccountID': accountId,
      'debit': isDebit ? amount : 0,
      'credit': isDebit ? 0 : amount,
      'isDebit': isDebit,
      'notes': note,
      if (currencyId.isNotEmpty) 'currencyID': currencyId,
      'rate': rate == 0 ? 1 : rate,
      'date': dateIso,
      'orderInJournal': index,
      'discountGiving': 0,
      'discountTaking': 0,
      'amountAfterDiscount': amount,
    };
    if (extras['costCenterId'] != null && extras['costCenterId'].toString().isNotEmpty) {
      detail['costCenterID'] = extras['costCenterId'];
    }
    if (extras['correspondingId'] != null && extras['correspondingId'].toString().isNotEmpty) {
      detail['correspondingAccountID'] = extras['correspondingId'];
      detail['oppositeAccountID'] = extras['correspondingId'];
    }
    return detail;
  }

  JournalRow? _profitOpposite(JournalRow row, List<JournalRow> rows) {
    if (row.balancing) return null;
    final others = rows.where((r) => r.groupKey == row.groupKey && !r.balancing && r != row);
    if (row.debit.isNotEmpty) {
      final found = others.where((r) => r.credit.isNotEmpty);
      return found.isEmpty ? null : found.first;
    }
    final found = others.where((r) => r.debit.isNotEmpty);
    return found.isEmpty ? null : found.first;
  }

  Map<String, dynamic> buildJournal(
    List<JournalRow> rows,
    Map<String, dynamic> resolved, {
    String section = 'batch',
    String? notes,
    String? lineNote,
  }) {
    final dateIso = toIsoDate(entryDate);
    final ccId = selectedCostCenterId();
    final typeId = journalTypeId;
    if (typeId.isEmpty) throw PlatformApiException('اختر نوع السند (سند حوالة).');

    final details = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final opposite = section == 'profit' ? _profitOpposite(row, rows) : (i % 2 == 0
          ? (i + 1 < rows.length ? rows[i + 1] : null)
          : rows[i - 1]);
      final correspondingId = useOpposite && opposite != null
          ? pickId(resolved[normalizeAccountKey(opposite.account)])
          : '';
      final lineExtra = lineNote ??
          ((section == 'manual' || section == 'charge' || section == 'profit')
              ? row.clientNote
              : sectionNote(section));
      details.add(buildDetail(row, resolved[normalizeAccountKey(row.account)], i, dateIso, {
        'costCenterId': ccId,
        'correspondingId': correspondingId,
        'section': section,
        'lineNote': composeNote(row.description, lineExtra),
      }));
    }

    final t = totals(rows);
    if (section != 'profit' && ((t['debit']! - t['credit']!).abs()) > 0.001) {
      throw PlatformApiException('القيد غير متوازن: مدين ${t['debit']} ≠ دائن ${t['credit']}');
    }

    final journalNotes = notes ?? ((section == 'manual' || section == 'charge' || section == 'profit') ? '' : sectionNote(section));
    final notesFinal = (journalNotes.isNotEmpty ? journalNotes : 'سند حوالة');
    final tType = currentJournalType();
    dynamic scopeId;
    if (tType is Map) scopeId = tType['scopeId'] ?? tType['ScopeId'];
    if (scopeId == null && sampleEntry is Map) {
      scopeId = sampleEntry['scopeId'] ?? sampleEntry['ScopeId'];
    }

    return {
      'date': dateIso,
      'dateEntry1': dateIso,
      'defaultPosting': dateIso,
      'notes': notesFinal,
      'journalEntryNumber': 0,
      'journalEntryDetails': details,
      'jornalTypeId': typeId,
      'isChecked': false,
      'isLocked': false,
      'isJournalRemittance': true,
      'offLineNumber': '',
      'fromCache': false,
      if (ccId.isNotEmpty) 'costCenterId': ccId,
      'scopeId': ?scopeId,
    };
  }

  Future<dynamic> postJournal(Map<String, dynamic> body) async {
    const query = 'reconciliationCheck=false&ignoreBudget=false';
    if (journalPostPath.isNotEmpty) {
      return _api('POST', '$journalPostPath?$query', body, {'asForm': true});
    }
    try {
      final created = await _api('POST', '/api/JournalEntry/AddJournalEntry?$query', body, {'asForm': true});
      journalPostPath = '/api/JournalEntry/AddJournalEntry';
      return created;
    } catch (_) {
      final created = await _api('POST', '/api/JournalEntry?$query', body, {'asForm': true});
      journalPostPath = '/api/JournalEntry';
      return created;
    }
  }

  bool isTransientError(Object err) {
    final msg = err.toString().toLowerCase();
    return msg.contains('econnreset') ||
        msg.contains('enotfound') ||
        msg.contains('pending stream') ||
        msg.contains('etimedout') ||
        msg.contains('socket hang') ||
        msg.contains('تعذر الاتصال') ||
        msg.contains('مهلة');
  }

  String friendlyError(Object err) {
    final msg = err.toString();
    if (RegExp(r'econnreset|pending stream|enotfound|etimedout|socket hang|تعذر الاتصال', caseSensitive: false)
        .hasMatch(msg)) {
      return 'انقطع الاتصال بخادم وكيد — أُعيدت المحاولة تلقائياً';
    }
    return msg;
  }

  Future<dynamic> postJournalWithRetry(Map<String, dynamic> body, [int attempts = 4]) async {
    Object? lastErr;
    for (var i = 0; i < attempts; i++) {
      try {
        return await postJournal(body);
      } catch (err) {
        lastErr = err;
        if (!isTransientError(err) || i == attempts - 1) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 450 * (i + 1)));
      }
    }
    throw lastErr ?? PlatformApiException('فشل التسجيل');
  }

  Future<List<T>> mapPool<T, I>(
    List<I> items,
    int limit,
    Future<T> Function(I item, int index) worker,
  ) async {
    final out = List<T?>.filled(items.length, null);
    var cursor = 0;
    Future<void> run() async {
      while (true) {
        final index = cursor++;
        if (index >= items.length) break;
        out[index] = await worker(items[index], index);
      }
    }

    final n = math.max(1, math.min(limit, items.length));
    await Future.wait(List.generate(n, (_) => run()));
    return out.cast<T>();
  }

  Future<dynamic> enrichCreated(dynamic created) async {
    created = unwrapCreated(created);
    final number = pickJournalNumber(created);
    final id = pickId(created);
    if (number.isNotEmpty) return created;
    if (id.isEmpty) return created;
    final attempts = ['/api/JournalEntry/$id', '/api/JournalEntry/GetById?id=${Uri.encodeComponent(id)}'];
    for (final path in attempts) {
      try {
        final full = unwrapCreated(await _api('GET', path));
        if (pickJournalNumber(full).isNotEmpty) return full;
      } catch (_) {}
    }
    return created;
  }

  Map<String, String> resolvedAccountInfo(Map<String, dynamic> resolved, String? code) {
    final acc = resolved[normalizeAccountKey(code)];
    return {
      'code': (code ?? '').trim(),
      'name': acc is Map
          ? (acc['AccountName'] ?? acc['accountName'] ?? acc['Name'] ?? acc['name'] ?? '').toString().trim()
          : '',
    };
  }

  List<LedgerEntry> appendLedgerEntries({
    required String kind,
    required List<CustomerGroup> groups,
    required Map<String, dynamic> resolved,
    required dynamic created,
    String extra = '',
    String? date,
    String section = 'batch',
  }) {
    final journalNumber = pickJournalNumber(created);
    final journalId = pickId(created);
    final now = DateTime.now().toUtc().toIso8601String();
    final dateVal = (date ?? entryDate).toString();
    final rows = groups.map((group) {
      final debitRow = group.rows.firstWhere(
        (r) => r.debit.isNotEmpty && !r.balancing,
        orElse: () => group.rows.firstWhere((r) => r.debit.isNotEmpty, orElse: () => group.rows.first),
      );
      final creditRow = group.rows.firstWhere(
        (r) => r.credit.isNotEmpty && !r.balancing,
        orElse: () => group.rows.firstWhere((r) => r.credit.isNotEmpty, orElse: () => group.rows.last),
      );
      final debit = resolvedAccountInfo(resolved, debitRow.account);
      final credit = resolvedAccountInfo(resolved, creditRow.account);
      final amount = numOf(debitRow.debit.isNotEmpty ? debitRow.debit : creditRow.credit);
      return LedgerEntry(
        id: makeId(),
        ownerKey: currentOwnerKey(),
        createdAt: now,
        entryDate: dateVal,
        journalNumber: journalNumber,
        journalId: journalId,
        kind: kind,
        name: group.name,
        amount: amount,
        debitAccount: debit['code'] ?? '',
        debitAccountName: debit['name'] ?? '',
        creditAccount: credit['code'] ?? '',
        creditAccountName: credit['name'] ?? '',
        notes: extra,
        statement: groupStatement(group, section),
      );
    }).toList();
    if (rows.isEmpty) return [];
    final all = List<LedgerEntry>.from(serverLedgerCache);
    final seenIds = all.map((r) => r.journalId).where((id) => id.isNotEmpty).toSet();
    final seenKeys = all
        .where((r) => r.journalNumber.isNotEmpty)
        .map((r) => '${r.journalNumber}|${r.name}|${r.entryDate}')
        .toSet();
    final fresh = rows.where((row) {
      if (row.journalId.isNotEmpty && seenIds.contains(row.journalId)) return false;
      if (row.journalNumber.isNotEmpty &&
          seenKeys.contains('${row.journalNumber}|${row.name}|${row.entryDate}')) {
        return false;
      }
      return true;
    }).toList();
    if (fresh.isEmpty) return [];
    serverLedgerCache = [...fresh, ...all];
    _persistLedger();
    _emit();
    return fresh;
  }

  void _persistLedger() {
    platform.storage.saveLedgerCache(serverLedgerCache.map((e) => e.toJson()).toList());
  }

  List<LedgerEntry> ownerLedger() {
    final owner = currentOwnerKey();
    return serverLedgerCache.where((row) => owner.isEmpty || row.ownerKey.isEmpty || row.ownerKey == owner).toList();
  }

  bool isGroupAlreadyLogged(CustomerGroup group, String date) {
    final name = group.name.trim();
    final debitRow = group.rows.firstWhere((r) => r.debit.isNotEmpty, orElse: () => group.rows.first);
    final creditRow = group.rows.firstWhere((r) => r.credit.isNotEmpty, orElse: () => group.rows.last);
    final amount = numOf(debitRow.debit.isNotEmpty ? debitRow.debit : creditRow.credit);
    final creditAccount = creditRow.account.trim();
    return ownerLedger().any((row) =>
        row.name == name &&
        row.entryDate == date &&
        numOf(row.amount) == amount &&
        row.creditAccount == creditAccount &&
        (row.journalNumber.isNotEmpty || row.journalId.isNotEmpty));
  }

  Map<String, List<CustomerGroup>> pendingCustomerGroups(List<CustomerGroup> groups, String date) {
    final skipped = <CustomerGroup>[];
    final pending = <CustomerGroup>[];
    for (final group in groups) {
      if (isGroupAlreadyLogged(group, date)) {
        skipped.add(group);
      } else {
        pending.add(group);
      }
    }
    return {'pending': pending, 'skipped': skipped};
  }

  String ledgerKindLabel(String kind) {
    switch (kind) {
      case 'each':
        return 'لكل عميل';
      case 'manual':
        return 'فردي';
      case 'charge':
        return 'شحن';
      case 'profit':
        return 'ربحي';
      case 'synced':
        return 'متزامن';
      default:
        return 'جماعي';
    }
  }

  String formatLedgerWhen(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final y = d.year.toString();
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final h = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$y-$m-$day $h:$min';
    } catch (_) {
      return iso.replaceFirst('T', ' ').substring(0, iso.length.clamp(0, 16));
    }
  }

  List<LedgerEntry> filteredLedger() {
    final q = ledgerSearch.trim().toLowerCase();
    final from = ledgerFrom.trim();
    final to = ledgerTo.trim();
    final kind = ledgerKind.trim();
    final rows = ownerLedger().where((row) {
      final date = row.entryDate.length >= 10 ? row.entryDate.substring(0, 10) : row.entryDate;
      if (from.isNotEmpty && date.isNotEmpty && date.compareTo(from) < 0) return false;
      if (to.isNotEmpty && date.isNotEmpty && date.compareTo(to) > 0) return false;
      if (kind.isNotEmpty && row.kind != kind) return false;
      if (q.isEmpty) return true;
      final hay = [
        row.journalNumber,
        row.name,
        row.amount,
        row.debitAccount,
        row.debitAccountName,
        row.creditAccount,
        row.creditAccountName,
        row.notes,
        row.statement,
        ledgerKindLabel(row.kind),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
    rows.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    return rows;
  }

  String ledgerTsv(List<LedgerEntry> rows) {
    const header = [
      'رقم السند',
      'تاريخ السند',
      'وقت الإنشاء',
      'الاسم',
      'المبلغ',
      'المدين',
      'اسم المدين',
      'الدائن',
      'اسم الدائن',
      'البيان',
      'الملاحظة',
      'النوع',
    ];
    final lines = <String>[header.join('\t')];
    for (final row in rows) {
      lines.add([
        row.journalNumber,
        row.entryDate,
        formatLedgerWhen(row.createdAt),
        row.name,
        row.amount,
        row.debitAccount,
        row.debitAccountName,
        row.creditAccount,
        row.creditAccountName,
        row.statement,
        row.notes,
        ledgerKindLabel(row.kind),
      ].join('\t'));
    }
    return lines.join('\n');
  }

  void clearLedgerFilters() {
    ledgerSearch = '';
    ledgerFrom = '';
    ledgerTo = '';
    ledgerKind = '';
    ledgerPage = 0;
    _emit();
  }

  bool guardSubmitJob() {
    if (!submitJob.active) return true;
    return false;
  }

  void beginSubmitJob() {
    submitJob.active = true;
    _emit();
  }

  void finishSubmitJob() {
    submitJob.active = false;
    _emit();
  }

  void openSubmitModal({
    required SubmitPhase phase,
    required String title,
    String message = '',
    String details = '',
    bool job = false,
  }) {
    if (submitJob.active && !job) return;
    if (job) {
      submitJob.phase = phase;
      submitJob.title = title;
      submitJob.message = message;
      submitJob.details = details;
    }
    _emit();
  }

  void closeSubmitModal() {
    if (submitJob.active) return;
    submitJob.phase = SubmitPhase.loading;
    submitJob.title = '';
    submitJob.message = '';
    submitJob.details = '';
    _emit();
  }

  void showSubmitError(String title, String message, [String details = '', bool job = false]) {
    if (job) {
      submitJob.phase = SubmitPhase.error;
      submitJob.title = title;
      submitJob.message = message;
      submitJob.details = details;
    }
    lastDialog = DialogData(phase: SubmitPhase.error, title: title, message: message, details: details);
    _persistDialog(lastDialog);
    notifications?.showDone(title, message, success: false);
    _emit();
  }

  void showSubmitSuccess(String title, String message, [String details = '', bool job = false]) {
    if (job) {
      submitJob.phase = SubmitPhase.success;
      submitJob.title = title;
      submitJob.message = message;
      submitJob.details = details;
    }
    lastDialog = DialogData(phase: SubmitPhase.success, title: title, message: message, details: details);
    _persistDialog(lastDialog);
    notifications?.showDone(title, message, success: true);
    _emit();
  }

  DialogData? lastDialog;

  void _persistDialog(DialogData? data) {
    if (data == null || data.phase == SubmitPhase.loading || data.phase == SubmitPhase.confirm) {
      platform.storage.saveLastDialog(null);
      return;
    }
    platform.storage.saveLastDialog(data.toJson());
  }

  void _restorePersistedDialog() {
    if (lastDialog != null) return;
    final raw = platform.storage.loadLastDialog();
    if (raw == null) return;
    final data = DialogData.fromJson(raw);
    if (data.phase == SubmitPhase.loading || data.phase == SubmitPhase.confirm || data.title.isEmpty) return;
    lastDialog = data;
    _emit();
  }

  void clearDialog() {
    lastDialog = null;
    pendingConfirmPrepared = null;
    pendingConfirmProfit = 0;
    pendingConfirmCount = 0;
    pendingConfirmFor = '';
    _persistDialog(null);
    notifications?.cancelAll();
    if (!submitJob.active) {
      submitJob.title = '';
      submitJob.message = '';
      submitJob.details = '';
    }
    _emit();
  }

  Future<PreparedJournal?> previewAndResolve(String kind, {bool forSubmit = false, String? source}) async {
    final isEach = kind == 'each';
    final isManual = source == 'manual';
    final isCharge = source == 'charge';
    final isProfit = source == 'profit';
    final rows = isProfit
        ? profitRows()
        : isCharge
            ? chargeRows()
            : isManual
                ? manualRows()
                : currentRows(isEach ? 'each' : 'batch');
    final emptyMessage = isProfit
        ? (profitMode == 'each'
            ? 'أكمل حساب ومبلغ الدائن والمدين لسند واحد على الأقل.'
            : 'الصق بيانات صالحة: الدائن | مبلغ الدائن | المدين | مبلغ المدين.')
        : isCharge
            ? 'أكمل الاسم والمبلغ والمدين والدائن لسند واحد على الأقل.'
            : isManual
                ? 'أكمل الاسم والمبلغ والدائن لسند واحد على الأقل.'
                : 'الصق بيانات صالحة: الاسم | المبلغ | الدائن.';
    if (rows.isEmpty) {
      showSubmitError('بيانات ناقصة', emptyMessage, '', forSubmit);
      return null;
    }
    if (!isProfit && !isCharge && debitAccount.trim().isEmpty) {
      showSubmitError('حساب المدين', 'اختر حساب المدين من دليل الحسابات.', '', forSubmit);
      return null;
    }
    if (!connected) {
      showSubmitError('غير متصل', 'سجّل الدخول أولاً.', '', forSubmit);
      return null;
    }
    busy = true;
    _emit();
    try {
      final resolved = await resolveRows(rows);
      _rememberResolved(resolved);
      if (isProfit) {
        resolvedProfit = resolved;
      } else if (isCharge) {
        resolvedCharge = resolved;
      } else if (isManual) {
        resolvedManual = resolved;
      } else if (isEach) {
        resolvedEach = resolved;
      } else {
        resolvedBatch = resolved;
      }
      final section = isProfit
          ? 'profit'
          : isCharge
              ? 'charge'
              : (isManual ? 'manual' : (isEach ? 'each' : 'batch'));
      _emit();
      return PreparedJournal(rows: rows, resolved: resolved, section: section, source: source ?? section);
    } catch (err) {
      showSubmitError('تعذر التحقق', err.toString(), '', forSubmit);
      return null;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> previewBatch() => previewAndResolve('batch');
  Future<void> previewEach() => previewAndResolve('each');
  Future<void> previewManual() => previewAndResolve('each', source: 'manual');
  Future<void> previewCharge() => previewAndResolve('each', source: 'charge');
  Future<void> previewProfit() => previewAndResolve('each', source: 'profit');

  Future<void> runJournalSubmit(
    String mode,
    Future<PreparedJournal?> Function() getPrepared,
    String loadingMessage,
  ) async {
    if (!guardSubmitJob()) return;
    beginSubmitJob();
    lastDialog = DialogData(
      phase: SubmitPhase.loading,
      title: 'جارٍ الإنشاء...',
      message: loadingMessage,
    );
    _emit();
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await notifications?.showProgress('وكيد — جارٍ التسجيل', loadingMessage);
    try {
      final prepared = await getPrepared();
      if (prepared == null) return;
      if (mode == 'batch') {
        await executeBatchJournalSubmit(prepared);
      } else {
        await executeEachJournalSubmit(prepared);
      }
    } catch (err) {
      showSubmitError('فشل الإنشاء', err.toString(), '', true);
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      finishSubmitJob();
    }
  }

  Future<void> submitBatch() {
    return runJournalSubmit(
      'batch',
      () => previewAndResolve('batch', forSubmit: true),
      'يتم الآن تسجيل السند الجماعي في وكيد. يرجى الانتظار.',
    );
  }

  Future<void> submitEach() {
    return runJournalSubmit(
      'each',
      () => previewAndResolve('each', forSubmit: true),
      'يتم الآن تسجيل السندات في وكيد. يرجى الانتظار.',
    );
  }

  Future<void> submitManual() {
    return runJournalSubmit(
      'each',
      () => previewAndResolve('each', forSubmit: true, source: 'manual'),
      'يتم الآن تسجيل سند منفصل لكل عميل. يرجى الانتظار.',
    );
  }

  Future<void> submitCharge() {
    return runJournalSubmit(
      'each',
      () => previewAndResolve('each', forSubmit: true, source: 'charge'),
      'يتم الآن تسجيل سندات الشحن في وكيد. يرجى الانتظار.',
    );
  }

  String profitPartyLabel(ProfitPasteRow row) {
    return chartAccountName(row.debit);
  }

  String profitPartiesLabel(List<ProfitPasteRow> paste) {
    final labels = <String>[];
    for (final row in paste) {
      final label = profitPartyLabel(row);
      if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
    }
    return labels.join('، ');
  }

  Future<void> submitProfit() async {
    if (!guardSubmitJob()) return;
    final prepared = await previewAndResolve('each', forSubmit: false, source: 'profit');
    if (prepared == null) return;
    final paste = currentProfitPaste();
    final totalsMap = profitPasteTotals(paste);
    pendingConfirmPrepared = prepared;
    pendingConfirmProfit = totalsMap['diff'] ?? 0;
    pendingConfirmCount = (totalsMap['count'] ?? 0).toInt();
    pendingConfirmFor = profitPartiesLabel(paste);
    lastDialog = DialogData(phase: SubmitPhase.confirm, title: 'تأكيد');
    _emit();
  }

  Future<void> confirmPendingSubmit() async {
    final prepared = pendingConfirmPrepared;
    if (prepared == null || lastDialog?.phase != SubmitPhase.confirm) {
      clearDialog();
      return;
    }
    pendingConfirmPrepared = null;
    lastDialog = null;
    _persistDialog(null);
    if (!guardSubmitJob()) return;
    beginSubmitJob();
    lastDialog = DialogData(
      phase: SubmitPhase.loading,
      title: 'جارٍ الإنشاء...',
      message: profitMode == 'each'
          ? 'يتم الآن تسجيل سند ربحي منفصل لكل بطاقة. يرجى الانتظار.'
          : 'يتم الآن تسجيل السند الربحي الجماعي في وكيد. يرجى الانتظار.',
    );
    _emit();
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await notifications?.showProgress('وكيد — جارٍ التسجيل', lastDialog?.message ?? '');
    try {
      await executeProfitSubmit(prepared);
    } catch (err) {
      showSubmitError('فشل الإنشاء', err.toString(), '', true);
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      finishSubmitJob();
    }
  }

  void cancelPendingSubmit() {
    pendingConfirmPrepared = null;
    pendingConfirmProfit = 0;
    pendingConfirmCount = 0;
    pendingConfirmFor = '';
    lastDialog = null;
    _persistDialog(null);
    _emit();
  }

  Future<void> executeProfitSubmit(PreparedJournal prepared) async {
    final date = entryDate;
    final remittanceGroups = profitLedgerGroups(List<JournalRow>.from(prepared.rows));
    if (remittanceGroups.isEmpty) {
      showSubmitError('بيانات ناقصة', 'لا توجد أسطر مدين/دائن صالحة.', '', true);
      return;
    }
    final split = pendingCustomerGroups(remittanceGroups, date);
    final pending = split['pending']!;
    final skipped = split['skipped']!;
    if (pending.isEmpty) {
      showSubmitSuccess(
        'موجود في السجل',
        'كل السندات (${remittanceGroups.length}) مسجّلة مسبقاً في السجل لهذا التاريخ.',
        skipped.map((g) => g.name).join('\n'),
        true,
      );
      clearProfitForm();
      return;
    }
    final skipNote = skipped.isNotEmpty ? '\n(${skipped.length} سنداً موجود مسبقاً في السجل — تم تخطيهم)' : '';
    final paste = [
      for (final group in pending)
        ProfitPasteRow(
          name: group.name,
          credit: group.rows.firstWhere((r) => r.credit.isNotEmpty && !r.balancing, orElse: () => group.rows.last).account,
          creditAmount: group.rows.firstWhere((r) => r.credit.isNotEmpty && !r.balancing, orElse: () => group.rows.last).credit,
          debit: group.rows.firstWhere((r) => r.debit.isNotEmpty && !r.balancing, orElse: () => group.rows.first).account,
          debitAmount: group.rows.firstWhere((r) => r.debit.isNotEmpty && !r.balancing, orElse: () => group.rows.first).debit,
          note: groupClientNote(group),
        ),
    ];
    final rebuilt = buildProfitJournalRows(paste);
    var resolved = Map<String, dynamic>.from(prepared.resolved);
    final missing = rebuilt
        .map((r) => normalizeAccountKey(r.account))
        .where((k) => k.isNotEmpty && !resolved.containsKey(k))
        .toSet();
    if (missing.isNotEmpty) {
      resolved = {...resolved, ...await resolveRows(rebuilt.where((r) => missing.contains(normalizeAccountKey(r.account))).toList())};
    }

    if (profitMode != 'each') {
      final body = buildJournal(
        rebuilt,
        resolved,
        section: 'profit',
        notes: notesProfit.trim().isNotEmpty ? notesProfit.trim() : 'سند ربحي',
      );
      var created = await enrichCreated(await postJournalWithRetry(body));
      if (pickJournalNumber(created).isEmpty) {
        try {
          created = await enrichCreated(await _api('GET', '/api/JournalEntry/GetLast'));
        } catch (_) {}
      }
      final number = pickJournalNumber(created);
      final id = pickId(created);
      appendLedgerEntries(
        kind: 'profit',
        groups: pending,
        resolved: resolved,
        created: created,
        extra: sectionNote('profit'),
        date: date,
        section: 'profit',
      );
      final details = [
        if (number.isNotEmpty) 'رقم السند في وكيد: $number',
        if (pending.isNotEmpty) 'عدد الأسماء في السند: ${pending.length}',
        if (id.isNotEmpty) 'المعرف: $id',
        skipNote.trim(),
        'تمت إضافة السجل — راجع تبويب «السجل».',
      ].where((s) => s.toString().isNotEmpty).join('\n');
      showSubmitSuccess('تم التسجيل بنجاح', 'تم حفظ السند الربحي الجماعي في وكيد.$skipNote', details, true);
      clearProfitForm();
      return;
    }

    final groups = groupRowsByKey(rebuilt).where((g) => g.rows.any((r) => !r.balancing) || g.rows.isNotEmpty).toList();
    final ok = <Map<String, String>>[];
    final failed = <Map<String, String>>[];
    var done = 0;
    final total = groups.length;
    await mapPool(groups, journalParallel, (group, _) async {
      final notes = groupStatement(group, 'profit').isNotEmpty ? groupStatement(group, 'profit') : 'سند ربحي';
      try {
        final body = buildJournal(group.rows, resolved, notes: notes, section: 'profit');
        final created = await enrichCreated(await postJournalWithRetry(body));
        final number = pickJournalNumber(created);
        appendLedgerEntries(
          kind: 'profit',
          groups: [
            CustomerGroup(name: group.name, rows: group.rows.where((r) => !r.balancing).toList()),
          ],
          resolved: resolved,
          created: created,
          extra: groupClientNote(group),
          date: date,
          section: 'profit',
        );
        ok.add({'name': group.name, 'number': number});
      } catch (err) {
        failed.add({'name': group.name, 'msg': friendlyError(err)});
      } finally {
        done += 1;
        lastDialog = DialogData(
          phase: SubmitPhase.loading,
          title: 'جارٍ الإنشاء...',
          message: 'تم $done من $total سنداً.\nمسجّل في السجل: ${ok.length}$skipNote',
        );
        _emit();
      }
    });
    if (failed.isEmpty) {
      final lines = ok.map((item) => item['number']!.isNotEmpty ? '${item['name']} — رقم ${item['number']}' : item['name']!);
      showSubmitSuccess(
        'تم التسجيل بنجاح',
        'تم حفظ ${ok.length} سنداً ربحياً في وكيد.$skipNote',
        '${lines.join('\n')}\nكل سند حُفظ في السجل فور نجاحه — راجع تبويب «السجل».',
        true,
      );
      clearProfitForm();
    } else {
      final lines = [
        ...ok.map((item) => '✓ ${item['name']}${item['number']!.isNotEmpty ? ' — رقم ${item['number']}' : ''} (في السجل)'),
        ...failed.map((f) => '✗ ${f['name']}: ${f['msg']}'),
      ];
      showSubmitSuccess(
        'اكتمل جزئياً',
        'نجح ${ok.length} سنداً (محفوظ في السجل) وفشل ${failed.length}.$skipNote\nأعد الإنشاء لإكمال المتبقي — المنجز موجود في السجل.',
        lines.join('\n'),
        true,
      );
    }
  }

  Future<void> executeBatchJournalSubmit(PreparedJournal prepared) async {
    final date = entryDate;
    final allGroups = groupCustomerRows(List<JournalRow>.from(prepared.rows));
    final split = pendingCustomerGroups(allGroups, date);
    final pending = split['pending']!;
    final skipped = split['skipped']!;
    if (pending.isEmpty) {
      showSubmitSuccess(
        'موجود في السجل',
        'كل العملاء (${allGroups.length}) مسجّلون مسبقاً في السجل لهذا التاريخ.',
        skipped.map((g) => g.name).join('\n'),
        true,
      );
      return;
    }
    final pendingRows = pending.expand((g) => g.rows).toList();
    final body = buildJournal(pendingRows, prepared.resolved, section: 'batch');
    var created = await enrichCreated(await postJournalWithRetry(body));
    if (pickJournalNumber(created).isEmpty) {
      try {
        created = await enrichCreated(await _api('GET', '/api/JournalEntry/GetLast'));
      } catch (_) {}
    }
    final number = pickJournalNumber(created);
    final id = pickId(created);
    final skipNote = skipped.isNotEmpty ? '\n(${skipped.length} عميلاً موجود مسبقاً في السجل — تم تخطيهم)' : '';
    appendLedgerEntries(
      kind: 'batch',
      groups: pending,
      resolved: prepared.resolved,
      created: created,
      extra: sectionNote('batch'),
      date: date,
      section: 'batch',
    );
    final details = [
      if (number.isNotEmpty) 'رقم السند في وكيد: $number',
      if (pending.isNotEmpty) 'عدد العملاء في السند: ${pending.length}',
      if (id.isNotEmpty) 'المعرف: $id',
      skipNote.trim(),
      'تمت إضافة السجل — راجع تبويب «السجل».',
    ].where((s) => s.toString().isNotEmpty).join('\n');
    showSubmitSuccess('تم التسجيل بنجاح', 'تم حفظ السند الجماعي في وكيد.$skipNote', details, true);
    clearBatchForm();
  }

  Future<void> executeEachJournalSubmit(PreparedJournal prepared) async {
    final section = prepared.section;
    final groups = groupCustomerRows(List<JournalRow>.from(prepared.rows));
    if (groups.isEmpty) {
      showSubmitError('بيانات ناقصة', 'لا توجد أزواج مدين/دائن صالحة.', '', true);
      return;
    }
    final date = entryDate;
    final split = pendingCustomerGroups(groups, date);
    final pending = split['pending']!;
    final skipped = split['skipped']!;
    if (pending.isEmpty) {
      showSubmitSuccess(
        'موجود في السجل',
        'كل العملاء (${groups.length}) مسجّلون مسبقاً في السجل لهذا التاريخ.',
        skipped.map((g) => g.name).join('\n'),
        true,
      );
      if (section == 'manual') {
        clearManualForm();
      } else if (section == 'charge') {
        clearChargeForm();
      } else {
        clearEachForm();
      }
      return;
    }
    final ok = <Map<String, String>>[];
    final failed = <Map<String, String>>[];
    var done = 0;
    final total = pending.length;
    final skipNote = skipped.isNotEmpty ? '\n(${skipped.length} عميلاً موجود مسبقاً في السجل — تم تخطيهم)' : '';
    await mapPool(pending, journalParallel, (group, _) async {
      final notes = groupStatement(group, section).isNotEmpty
          ? groupStatement(group, section)
          : (sectionNote(section).isNotEmpty ? sectionNote(section) : 'سند حوالة');
      try {
        final body = buildJournal(group.rows, prepared.resolved, notes: notes, section: section);
        final created = await enrichCreated(await postJournalWithRetry(body));
        final number = pickJournalNumber(created);
        appendLedgerEntries(
          kind: section == 'charge' ? 'charge' : 'each',
          groups: [group],
          resolved: prepared.resolved,
          created: created,
          extra: (section == 'manual' || section == 'charge') ? groupClientNote(group) : sectionNote(section),
          date: date,
          section: section,
        );
        ok.add({'name': group.name, 'number': number});
      } catch (err) {
        failed.add({'name': group.name, 'msg': friendlyError(err)});
      } finally {
        done += 1;
        lastDialog = DialogData(
          phase: SubmitPhase.loading,
          title: 'جارٍ الإنشاء...',
          message: 'تم $done من $total سنداً.\nمسجّل في السجل: ${ok.length}$skipNote',
        );
        _emit();
      }
    });
    if (failed.isEmpty) {
      final lines = ok.map((item) => item['number']!.isNotEmpty ? '${item['name']} — رقم ${item['number']}' : item['name']!);
      showSubmitSuccess(
        'تم التسجيل بنجاح',
        'تم حفظ ${ok.length} سنداً في وكيد.$skipNote',
        '${lines.join('\n')}\nكل سند حُفظ في السجل فور نجاحه — راجع تبويب «السجل».',
        true,
      );
      if (section == 'manual') {
        clearManualForm();
      } else if (section == 'charge') {
        clearChargeForm();
      } else {
        clearEachForm();
      }
    } else {
      final lines = [
        ...ok.map((item) => '✓ ${item['name']}${item['number']!.isNotEmpty ? ' — رقم ${item['number']}' : ''} (في السجل)'),
        ...failed.map((f) => '✗ ${f['name']}: ${f['msg']}'),
      ];
      showSubmitSuccess(
        'اكتمل جزئياً',
        'نجح ${ok.length} سنداً (محفوظ في السجل) وفشل ${failed.length}.$skipNote\nأعد الإنشاء لإكمال المتبقي — المنجز موجود في السجل.',
        lines.join('\n'),
        true,
      );
    }
  }

  Future<void> syncWakeedJournals() async {
    if (!connected || platform.wakeedToken.isEmpty) return;
    ledgerSyncing = true;
    _emit();
    try {
      if (wakeedUserId.isEmpty) {
        await refreshSessionIdentity();
      }
      final codes = accountCodesById(accounts);
      final remote = <LedgerEntry>[];
      const limit = 50;
      var offset = 0;
      final now = DateTime.now();
      final from = DateTime(now.year - 2, 1, 1);
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';
      final fromS = iso(from);
      final toS = iso(DateTime(now.year, 12, 31));
      for (var page = 0; page < 40; page++) {
        final params = <String, String>{
          'fromDate': fromS,
          'toDate': toS,
          'offset': '$offset',
          'limit': '$limit',
          if (wakeedUserId.isNotEmpty) 'userId': wakeedUserId,
        };
        final qs = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
        final data = await _api('GET', '/api/JournalEntry?$qs');
        final pageItems = asList(data);
        if (pageItems.isEmpty) break;
        remote.addAll(
          ledgerFromWakeedJournals(
            data,
            ownerKey: currentOwnerKey(),
            userId: wakeedUserId,
            userName: displayUserName,
            accountCodesById: codes,
          ),
        );
        if (pageItems.length < limit) break;
        offset += limit;
      }
      final remoteKeys = remote
          .map((r) => '${r.journalId}|${r.name}|${r.entryDate}')
          .where((k) => !k.startsWith('|'))
          .toSet();
      final localOnly = serverLedgerCache.where((row) {
        if (row.kind == 'synced') return false;
        final key = '${row.journalId}|${row.name}|${row.entryDate}';
        return !remoteKeys.contains(key);
      }).toList();
      serverLedgerCache = [...localOnly, ...remote];
      _persistLedger();
    } catch (_) {
      // Keep the on-device cache if Wakeed listing fails.
    } finally {
      ledgerSyncing = false;
      _emit();
    }
  }

  Future<void> downloadLedgerExcel() async {
    final list = filteredLedger();
    if (list.isEmpty) {
      showSubmitError('لا توجد بيانات', 'لا توجد صفوف في الفلترة الحالية للتنزيل.');
      return;
    }
    try {
      final bytes = buildExcelSheet(
        sheetName: 'السجل',
        headers: const [
          'رقم السند',
          'تاريخ السند',
          'وقت الإنشاء',
          'الاسم',
          'المبلغ',
          'المدين',
          'اسم المدين',
          'الدائن',
          'اسم الدائن',
          'البيان',
          'الملاحظة',
          'النوع',
        ],
        rows: [
          for (final row in list)
            [
              row.journalNumber,
              row.entryDate,
              formatLedgerWhen(row.createdAt),
              row.name,
              row.amount,
              row.debitAccount,
              row.debitAccountName,
              row.creditAccount,
              row.creditAccountName,
              row.statement,
              row.notes,
              ledgerKindLabel(row.kind),
            ],
        ],
      );
      final name = ledgerExcelFileName(list.map((r) => r.entryDate).toList());
      await saveBytesAsFile(bytes: bytes, filename: name, mimeType: excelMime);
      showSubmitSuccess('تم التنزيل', 'تم تنزيل ملف إكسل ($name) — ${list.length} صفاً.');
    } catch (err) {
      showSubmitError('تعذر التنزيل', err.toString());
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _connSub?.cancel();
    platform.dispose();
    super.dispose();
  }
}

class DialogData {
  DialogData({
    required this.phase,
    required this.title,
    this.message = '',
    this.details = '',
  });

  final SubmitPhase phase;
  final String title;
  final String message;
  final String details;

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'title': title,
        'message': message,
        'details': details,
      };

  factory DialogData.fromJson(Map<String, dynamic> json) {
    final name = (json['phase'] ?? 'success').toString();
    final phase = SubmitPhase.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SubmitPhase.success,
    );
    return DialogData(
      phase: phase,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
    );
  }
}
