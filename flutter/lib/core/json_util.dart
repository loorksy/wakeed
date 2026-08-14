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
  num? firstNonOne;
  num? firstAny;
  const keys = [
    'Equality',
    'equality',
    'CurrencyEquality',
    'currencyEquality',
    'Equal',
    'equal',
    'ExchangeRate',
    'exchangeRate',
    'CurrencyRate',
    'currencyRate',
    'Rate',
    'rate',
    'Price',
    'price',
  ];
  for (final key in keys) {
    if (!currency.containsKey(key) || currency[key] == null) continue;
    final n = numOf(currency[key]);
    if (n == 0) continue;
    firstAny ??= n;
    if ((n - 1).abs() > 0.0000001) {
      firstNonOne ??= n;
      break;
    }
  }
  return firstNonOne ?? firstAny ?? 1;
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
