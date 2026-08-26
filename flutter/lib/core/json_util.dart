import 'package:uuid/uuid.dart';

dynamic _read(dynamic obj, List<String> keys) {
  if (obj is! Map) return null;
  for (final key in keys) {
    if (obj.containsKey(key) && obj[key] != null) return obj[key];
  }
  return null;
}

String pickId(dynamic obj) {
  final v = _read(obj, ['Id', 'id', 'Key', 'key']);
  return v == null ? '' : v.toString();
}

String pickName(dynamic obj) {
  final v = _read(obj, [
    'DisplayName',
    'displayName',
    'AccountName',
    'accountName',
    'Name',
    'name',
    'Value',
    'value',
    'CenterName',
    'FullName',
    'Code',
    'AccountCode',
  ]);
  return v == null ? '' : v.toString();
}

String pickAccountCode(dynamic acc) {
  final v = _read(acc, ['AccountCode', 'accountCode', 'Code', 'code']);
  return v == null ? '' : v.toString().trim();
}

String accountNameOf(dynamic acc) {
  final v = _read(acc, [
    'AccountName',
    'accountName',
    'DisplayName',
    'displayName',
    'FullName',
    'fullName',
    'Name',
    'name',
  ]);
  return v == null ? '' : v.toString().trim();
}

String accountLabel(dynamic acc) {
  final code = pickAccountCode(acc);
  final name = accountNameOf(acc);
  return name.isEmpty ? code : '$code — $name';
}

bool isPostableAccount(dynamic acc) {
  if (acc is! Map || pickAccountCode(acc).isEmpty) return false;
  final children = acc['Children'] ?? acc['children'];
  if (children is List && children.isNotEmpty) return false;
  if (acc['IsParent'] == true || acc['isParent'] == true) return false;
  if (acc['HasChildren'] == true || acc['hasChildren'] == true) return false;
  if (acc['IsLeaf'] == false || acc['isLeaf'] == false) return false;
  return true;
}

List<dynamic> flattenAccounts(dynamic nodes, [List<dynamic>? out]) {
  final result = out ?? <dynamic>[];
  for (final node in (nodes is List ? nodes : const [])) {
    if (node is! Map) continue;
    final children = node['Children'] ?? node['children'] ?? [];
    if (isPostableAccount(node)) result.add(node);
    if (children is List && children.isNotEmpty) flattenAccounts(children, result);
  }
  return result;
}

List<Map<String, dynamic>> flattenCostCenters(
  dynamic nodes, [
  List<Map<String, dynamic>>? out,
  String prefix = '',
]) {
  final result = out ?? <Map<String, dynamic>>[];
  for (final node in (nodes is List ? nodes : const [])) {
    if (node is! Map) continue;
    final name = (node['Name'] ?? node['CenterName'] ?? node['name'] ?? node['centerName'] ?? '')
        .toString();
    final code = (node['Code'] ?? node['CenterCode'] ?? node['code'] ?? node['centerCode'] ?? '')
        .toString();
    final label = '$prefix${code.isNotEmpty ? '$code — ' : ''}$name'.trim();
    final id = node['Id'] ?? node['id'];
    if (id != null) {
      result.add({'Id': id, 'label': label, 'raw': node});
    }
    final children = node['Children'] ?? node['children'];
    if (children is List && children.isNotEmpty) {
      flattenCostCenters(children, result, '$prefix— ');
    }
  }
  return result;
}

List<dynamic> asList(dynamic data) {
  if (data == null) return [];
  if (data is List) return data;
  if (data is Map) {
    final newtonsoft = data[r'$values'];
    if (newtonsoft is List) return newtonsoft;
    for (final key in [
      'JournalEntryData',
      'journalEntryData',
      'Currencies',
      'currencies',
      'Items',
      'items',
      'Data',
      'data',
      'Result',
      'result',
      'Value',
      'value',
    ]) {
      final v = data[key];
      if (v is List) return v;
      if (v is Map && v[r'$values'] is List) return v[r'$values'] as List;
    }
    if (data['Id'] != null || data['id'] != null) return [data];
  }
  return [];
}

String normalizeAccountKey(dynamic value) => (value ?? '').toString().trim();

String extractOwnerKey(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return '';
  final hash = text.contains('#') ? text.split('#').last : text;
  final parts = hash.replaceFirst(RegExp(r'^/+'), '').split(RegExp(r'[/?]'));
  final segment = parts.where((p) => p.isNotEmpty).isEmpty
      ? ''
      : parts.where((p) => p.isNotEmpty).first;
  if (RegExp(r'^owner[_-][a-z0-9]+$', caseSensitive: false).hasMatch(segment)) {
    return segment;
  }
  if (RegExp(r'^owner[_-][a-z0-9]+$', caseSensitive: false).hasMatch(text) &&
      !RegExp(r'[/\#]').hasMatch(text)) {
    return text;
  }
  return text.replaceFirst(RegExp(r'^#/?'), '');
}

List<String> ownerKeyVariants(dynamic raw) {
  final key = extractOwnerKey(raw);
  if (key.isEmpty) return [];
  final variants = <String>[key];
  if (RegExp(r'^owner_', caseSensitive: false).hasMatch(key)) {
    variants.add(key.replaceFirst(RegExp(r'^owner_', caseSensitive: false), ''));
  } else {
    variants.add('owner_$key');
  }
  return {...variants.where((v) => v.isNotEmpty)}.toList();
}

String pickUserDisplayName(dynamic user) {
  if (user is! Map) return '';
  final first = (user['first_name'] ?? user['firstName'] ?? '').toString().trim();
  final last = (user['last_name'] ?? user['lastName'] ?? '').toString().trim();
  final combined = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
  for (final value in [
    user['full_name'],
    user['fullName'],
    user['name'],
    user['Name'],
    combined,
    user['displayName'],
    user['DisplayName'],
    user['userName'],
    user['UserName'],
    user['email'],
    user['username'],
  ]) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String pickSubscriptionNameClient(dynamic item) {
  if (item is! Map) return '';
  final nested = item['subscription'] ?? item['Subscription'] ?? item['account'] ?? item['Account'];
  final nestedMap = nested is Map ? nested : const <String, dynamic>{};
  final candidates = [
    item['companyName'],
    item['CompanyName'],
    item['businessName'],
    item['BusinessName'],
    item['accountName'],
    item['AccountName'],
    item['displayName'],
    item['DisplayName'],
    item['name'],
    item['Name'],
    item['full_name'],
    item['fullName'],
    nestedMap['companyName'],
    nestedMap['CompanyName'],
    nestedMap['name'],
    nestedMap['Name'],
    nestedMap['displayName'],
    nestedMap['DisplayName'],
  ];
  for (final value in candidates) {
    final text = (value ?? '').toString().trim();
    if (text.isNotEmpty && !RegExp(r'^owner[_-]', caseSensitive: false).hasMatch(text)) {
      return text;
    }
  }
  return '';
}

bool isRemittanceType(dynamic item) {
  final text = '${pickName(item)} ${item is Map ? (item['Value'] ?? '') : ''} ${item is Map ? (item['DisplayName'] ?? '') : ''}';
  return RegExp(r'حوالة|تحويل|remit|transfer', caseSensitive: false).hasMatch(text);
}

num numOf(dynamic v) {
  final n = num.tryParse((v ?? 0).toString()) ?? 0;
  return n;
}

class AccountThirdParty {
  const AccountThirdParty({this.id = '', this.code = '', this.name = ''});

  final String id;
  final String code;
  final String name;

  bool get isEmpty => id.isEmpty && code.isEmpty;

  String get label {
    if (name.isNotEmpty && code.isNotEmpty) return '$code — $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return '';
  }

  bool matchesAccount(dynamic acc) {
    if (acc is! Map) return false;
    final accId = pickId(acc);
    final accCode = pickAccountCode(acc);
    final accName = accountNameOf(acc);
    if (id.isNotEmpty && accId.isNotEmpty && id == accId) return true;
    if (code.isNotEmpty && accCode.isNotEmpty && normalizeAccountKey(code) == normalizeAccountKey(accCode)) {
      return true;
    }
    if (name.isNotEmpty && accName.isNotEmpty && name == accName) return true;
    return false;
  }

  bool matchesAccountCode(String accountCode) {
    final key = normalizeAccountKey(accountCode);
    return key.isNotEmpty && code.isNotEmpty && normalizeAccountKey(code) == key;
  }
}

String _normFieldKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[_-]'), '');

bool _isExplicitThirdPartyKey(String key) {
  final k = _normFieldKey(key);
  return k.contains('thirdparty') || k.contains('correspondingaccount');
}

bool _isOwnerNestKey(String key) {
  final k = _normFieldKey(key);
  return k == 'party' ||
      k == 'partyaccount' ||
      k == 'agent' ||
      k == 'agentaccount' ||
      k == 'accountowner' ||
      k == 'owneraccount' ||
      k == 'relatedaccount' ||
      k == 'customer' ||
      k == 'owner';
}

dynamic _nestedThirdParty(dynamic acc) {
  if (acc is! Map) return null;
  for (final entry in acc.entries) {
    if (!_isExplicitThirdPartyKey(entry.key.toString())) continue;
    final v = entry.value;
    if (v is Map && (pickId(v).isNotEmpty || pickAccountCode(v).isNotEmpty || accountNameOf(v).isNotEmpty)) {
      return v;
    }
  }
  return null;
}

Iterable<Map<dynamic, dynamic>> _ownerNests(dynamic acc) sync* {
  if (acc is! Map) return;
  for (final entry in acc.entries) {
    if (!_isOwnerNestKey(entry.key.toString())) continue;
    final v = entry.value;
    if (v is Map) yield v;
  }
}

String _firstNonEmpty(dynamic acc, List<String> keys) {
  if (acc is! Map) return '';
  for (final key in keys) {
    final v = acc[key];
    if (v == null) continue;
    final text = v.toString().trim();
    if (text.isNotEmpty && text != '0') return text;
  }
  return '';
}

String _thirdPartyScalar(dynamic acc, {required bool id, required bool code, required bool name}) {
  if (acc is! Map) return '';
  for (final entry in acc.entries) {
    if (!_isExplicitThirdPartyKey(entry.key.toString())) continue;
    final v = entry.value;
    if (v is Map || v is List) continue;
    final text = (v ?? '').toString().trim();
    if (text.isEmpty || text == '0') continue;
    final k = _normFieldKey(entry.key.toString());
    if (id && (k.endsWith('id') || k.contains('accountid'))) return text;
    if (code && k.endsWith('code')) return text;
    if (name && (k.endsWith('name') || k.endsWith('displayname'))) return text;
  }
  return '';
}

AccountThirdParty _pickExplicitThirdParty(dynamic acc) {
  if (acc is! Map) return const AccountThirdParty();
  final nested = _nestedThirdParty(acc);
  var id = '';
  var code = '';
  var name = '';
  if (nested is Map) {
    id = pickId(nested);
    code = pickAccountCode(nested);
    name = accountNameOf(nested);
  }
  if (id.isEmpty) {
    id = _thirdPartyScalar(acc, id: true, code: false, name: false);
  }
  if (id.isEmpty) {
    id = _firstNonEmpty(acc, const [
      'ThirdPartyId',
      'thirdPartyId',
      'ThirdPartyID',
      'thirdPartyID',
      'ThirdPartyAccountId',
      'thirdPartyAccountId',
      'ThirdPartyAccountID',
      'CorrespondingAccountId',
      'correspondingAccountId',
      'correspondingAccountID',
      'CorrespondingAccountID',
      'DefaultThirdPartyId',
      'defaultThirdPartyId',
      'DefaultCorrespondingAccountId',
      'defaultCorrespondingAccountId',
    ]);
  }
  if (code.isEmpty) {
    code = _thirdPartyScalar(acc, id: false, code: true, name: false);
  }
  if (code.isEmpty) {
    code = _firstNonEmpty(acc, const [
      'ThirdPartyCode',
      'thirdPartyCode',
      'ThirdPartyAccountCode',
      'thirdPartyAccountCode',
      'CorrespondingAccountCode',
      'correspondingAccountCode',
    ]);
  }
  if (name.isEmpty) {
    name = _thirdPartyScalar(acc, id: false, code: false, name: true);
  }
  if (name.isEmpty) {
    name = _firstNonEmpty(acc, const [
      'ThirdPartyName',
      'thirdPartyName',
      'ThirdPartyAccountName',
      'thirdPartyAccountName',
      'CorrespondingAccountName',
      'correspondingAccountName',
    ]);
  }
  return AccountThirdParty(id: id, code: code, name: name);
}

AccountThirdParty _rejectSelfParty(dynamic acc, AccountThirdParty party) {
  if (party.isEmpty && party.name.isEmpty) return const AccountThirdParty();
  var id = party.id;
  var code = party.code;
  var name = party.name;
  final selfId = pickId(acc);
  final selfCode = pickAccountCode(acc);
  final selfName = accountNameOf(acc);
  if (selfId.isNotEmpty && id == selfId) id = '';
  if (selfCode.isNotEmpty && normalizeAccountKey(code) == normalizeAccountKey(selfCode)) code = '';
  if (selfName.isNotEmpty && name == selfName) name = '';
  if (id.isEmpty && code.isEmpty) return const AccountThirdParty();
  return AccountThirdParty(id: id, code: code, name: name);
}

/// Third party assigned on a Wakeed account card — never the account's own Party/owner (الدائن).
AccountThirdParty pickAccountThirdParty(dynamic acc) {
  if (acc is! Map) return const AccountThirdParty();
  var party = _rejectSelfParty(acc, _pickExplicitThirdParty(acc));
  if (party.isEmpty) {
    for (final owner in _ownerNests(acc)) {
      final nested = _rejectSelfParty(owner, _pickExplicitThirdParty(owner));
      final distinct = _rejectSelfParty(acc, nested);
      if (!distinct.isEmpty && !distinct.matchesAccount(acc) && !distinct.matchesAccount(owner)) {
        party = distinct;
        break;
      }
    }
  }
  if (party.matchesAccount(acc)) return const AccountThirdParty();
  return party;
}

/// Unwrap Wakeed `{ data: { ... } }` / list-of-one payloads into the account object.
dynamic unwrapEntity(dynamic data) {
  var current = data;
  for (var i = 0; i < 5; i++) {
    if (current is List && current.isNotEmpty) {
      current = current.first;
      continue;
    }
    if (current is! Map) return current;
    if (pickId(current).isNotEmpty || pickAccountCode(current).isNotEmpty) return current;
    dynamic next;
    for (final key in const [
      'data',
      'Data',
      'result',
      'Result',
      'value',
      'Value',
      'item',
      'Item',
      'account',
      'Account',
      'normalAccount',
      'NormalAccount',
    ]) {
      final v = current[key];
      if (v != null) {
        next = v;
        break;
      }
    }
    if (next == null) return current;
    current = next;
  }
  return current;
}

void applyAccountThirdPartyFields(Map<String, dynamic> detail, AccountThirdParty party) {
  if (party.id.isEmpty) return;
  detail['thirdPartyID'] = party.id;
  detail['ThirdPartyId'] = party.id;
  detail['thirdPartyId'] = party.id;
  detail['relatedAccountID'] = party.id;
  detail['RelatedAccountId'] = party.id;
}

String pickAccountCurrencyId(dynamic acc) {
  if (acc is! Map) return '';
  final nested = acc['Currency'] ?? acc['currency'];
  final id = acc['CurrencyId'] ??
      acc['currencyId'] ??
      acc['CurrencyID'] ??
      acc['currencyID'] ??
      (nested is Map ? (nested['Id'] ?? nested['id']) : null);
  return id == null ? '' : id.toString().trim();
}

Map<String, dynamic>? pickAccountCurrency(dynamic acc) {
  if (acc is! Map) return null;
  final nested = acc['Currency'] ?? acc['currency'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return null;
}

String pickCurrencyCode(dynamic currency) {
  if (currency is! Map) return '';
  return (currency['Code'] ??
          currency['code'] ??
          currency['CurrencyCode'] ??
          currency['currencyCode'] ??
          currency['IsoCode'] ??
          currency['isoCode'] ??
          '')
      .toString()
      .trim();
}

String pickCurrencySymbol(dynamic currency) {
  if (currency is! Map) return '';
  return (currency['Symbol'] ??
          currency['symbol'] ??
          currency['CurrencySymbol'] ??
          currency['currencySymbol'] ??
          '')
      .toString()
      .trim();
}

num pickCurrencyRate(dynamic currency) {
  if (currency is! Map) return 1;
  final last = numOf(currency['lastRate'] ?? currency['LastRate'] ?? currency['last_rate']);
  if (last > 0) return last;
  const keys = [
    'Rate',
    'rate',
    'Equality',
    'equality',
    'equivalent',
    'Equivalent',
    'CurrencyEquality',
    'currencyEquality',
    'Equal',
    'equal',
    'ExchangeRate',
    'exchangeRate',
    'CurrencyRate',
    'currencyRate',
    'Price',
    'price',
  ];
  final values = <num>[];
  for (final key in keys) {
    if (!currency.containsKey(key) || currency[key] == null) continue;
    final n = numOf(currency[key]);
    if (n > 0) values.add(n);
  }
  for (final n in values) {
    if (n < 1) return n;
  }
  final quotes = values.where((n) => (n - 1).abs() > 0.0000001).toList();
  if (quotes.isEmpty) return values.isEmpty ? 1 : values.first;
  quotes.sort((a, b) => _fracDigits(b).compareTo(_fracDigits(a)));
  return quotes.first;
}

int _fracDigits(num n) {
  final s = n.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final i = s.indexOf('.');
  return i < 0 ? 0 : s.length - i - 1;
}

String todayInputValue() {
  final d = DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String toIsoDate(String dateValue) {
  final value = dateValue.trim().isEmpty ? todayInputValue() : dateValue.trim();
  return '${value}T00:00:00.000Z';
}

String formatApiError(dynamic payload) {
  final data = payload is Map && payload['data'] != null ? payload['data'] : payload;
  if (data == null) return (payload is Map ? payload['error'] : null)?.toString() ?? 'خطأ';
  if (data is String) return data;
  if (data is Map) {
    if (data['Message'] != null) return data['Message'].toString();
    if (data['message'] != null) return data['message'].toString();
    if (data['errors'] is Map) {
      final parts = <String>[];
      (data['errors'] as Map).forEach((k, v) {
        final list = v is List ? v : [v];
        parts.add('$k: ${list.join('، ')}');
      });
      return parts.join(' | ');
    }
    if (data['title'] != null) return data['title'].toString();
    if (data['error'] != null) return data['error'].toString();
    try {
      return data.toString().substring(0, data.toString().length.clamp(0, 500));
    } catch (_) {
      return data.toString();
    }
  }
  return data.toString();
}

String formatProxyError(dynamic data) {
  if (data == null) return 'خطأ في وكيد';
  if (data is String) return data;
  if (data is Map) {
    if (data['message'] != null) return data['message'].toString();
    if (data['Message'] != null) return data['Message'].toString();
    try {
      final s = data.toString();
      return s.length > 400 ? s.substring(0, 400) : s;
    } catch (_) {
      return 'خطأ في وكيد';
    }
  }
  return 'خطأ في وكيد';
}

String pickJournalNumber(dynamic obj) {
  if (obj is! Map) return '';
  final n = obj['JournalEntryNumber'] ??
      obj['journalEntryNumber'] ??
      obj['Number'] ??
      obj['number'] ??
      obj['journalNumber'] ??
      obj['JournalNumber'];
  if (n == 0 || n == '0' || n == null || n == '') return '';
  return n.toString();
}

dynamic unwrapCreated(dynamic created) {
  if (created is List && created.isNotEmpty) return unwrapCreated(created.first);
  if (created is Map &&
      created['data'] is Map &&
      created['journalEntryNumber'] == null &&
      created['JournalEntryNumber'] == null) {
    return unwrapCreated(created['data']);
  }
  return created;
}

String makeId() {
  const uuid = Uuid();
  return uuid.v4();
}

String manualEntryId() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  return 'm-$now-${rand.substring(rand.length > 6 ? rand.length - 6 : 0)}';
}
