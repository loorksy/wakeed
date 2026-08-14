class LedgerEntry {
  LedgerEntry({
    required this.id,
    this.ownerKey = '',
    this.createdAt,
    this.entryDate = '',
    this.journalNumber = '',
    this.journalId = '',
    this.kind = 'each',
    this.name = '',
    this.amount = 0,
    this.debitAccount = '',
    this.debitAccountName = '',
    this.creditAccount = '',
    this.creditAccountName = '',
    this.notes = '',
    this.statement = '',
  });

  final String id;
  final String ownerKey;
  final String? createdAt;
  final String entryDate;
  final String journalNumber;
  final String journalId;
  final String kind;
  final String name;
  final num amount;
  final String debitAccount;
  final String debitAccountName;
  final String creditAccount;
  final String creditAccountName;
  final String notes;
  final String statement;

  factory LedgerEntry.fromJson(Map<String, dynamic> row) {
    return LedgerEntry(
      id: (row['id'] ?? '').toString(),
      ownerKey: (row['owner_key'] ?? row['ownerKey'] ?? '').toString(),
      createdAt: (row['created_at'] ?? row['createdAt'])?.toString(),
      entryDate: (row['entry_date'] ?? row['entryDate'] ?? '').toString(),
      journalNumber: (row['journal_number'] ?? row['journalNumber'] ?? '').toString(),
      journalId: (row['journal_id'] ?? row['journalId'] ?? '').toString(),
      kind: (row['kind'] ?? 'each').toString(),
      name: (row['name'] ?? '').toString(),
      amount: num.tryParse((row['amount'] ?? 0).toString()) ?? 0,
      debitAccount: (row['debit_account'] ?? row['debitAccount'] ?? '').toString(),
      debitAccountName: (row['debit_account_name'] ?? row['debitAccountName'] ?? '').toString(),
      creditAccount: (row['credit_account'] ?? row['creditAccount'] ?? '').toString(),
      creditAccountName: (row['credit_account_name'] ?? row['creditAccountName'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      statement: (row['statement'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerKey': ownerKey,
        'createdAt': createdAt,
        'entryDate': entryDate,
        'journalNumber': journalNumber,
        'journalId': journalId,
        'kind': kind,
        'name': name,
        'amount': amount,
        'debitAccount': debitAccount,
        'debitAccountName': debitAccountName,
        'creditAccount': creditAccount,
        'creditAccountName': creditAccountName,
        'notes': notes,
        'statement': statement,
      };
}

class WakeedSubscription {
  WakeedSubscription({this.id = '', this.name = '', required this.ownerKey});

  final String id;
  final String name;
  final String ownerKey;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ownerKey': ownerKey};

  factory WakeedSubscription.fromJson(Map<String, dynamic> json) {
    return WakeedSubscription(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      ownerKey: (json['ownerKey'] ?? json['OwnerKey'] ?? json['owner_key'] ?? '').toString(),
    );
  }
}

class ProfitEntry {
  ProfitEntry({
    required this.id,
    this.name = '',
    this.debit = '',
    this.debitAmount = '',
    this.credit = '',
    this.creditAmount = '',
    this.note = '',
  });

  String id;
  String name;
  String debit;
  String debitAmount;
  String credit;
  String creditAmount;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'debit': debit,
        'debitAmount': debitAmount,
        'credit': credit,
        'creditAmount': creditAmount,
        'note': note,
      };

  factory ProfitEntry.fromJson(Map<String, dynamic> json) {
    return ProfitEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      debit: (json['debit'] ?? '').toString(),
      debitAmount: (json['debitAmount'] ?? json['debit_amount'] ?? '').toString(),
      credit: (json['credit'] ?? '').toString(),
      creditAmount: (json['creditAmount'] ?? json['credit_amount'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class ManualEntry {
  ManualEntry({
    required this.id,
    this.name = '',
    this.amount = '',
    this.debit = '',
    this.credit = '',
    this.note = '',
  });

  String id;
  String name;
  String amount;
  String debit;
  String credit;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'debit': debit,
        'credit': credit,
        'note': note,
      };

  factory ManualEntry.fromJson(Map<String, dynamic> json) {
    return ManualEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      amount: (json['amount'] ?? '').toString(),
      debit: (json['debit'] ?? '').toString(),
      credit: (json['credit'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class PreparedJournal {
  PreparedJournal({
    required this.rows,
    required this.resolved,
    required this.section,
    this.source,
  });

  final List<dynamic> rows;
  final Map<String, dynamic> resolved;
  final String section;
  final String? source;
}

enum AppPhase { boot, license, blocked, login, home }

enum SubmitPhase { loading, success, error, confirm }

class SubmitJob {
  bool active = false;
  SubmitPhase phase = SubmitPhase.loading;
  String title = '';
  String message = '';
  String details = '';
}

class AccountPickTarget {
  AccountPickTarget.debit() : type = 'debit', entryId = null;
  AccountPickTarget.credit(this.entryId) : type = 'credit';
  AccountPickTarget.chargeDebit(this.entryId) : type = 'chargeDebit';
  AccountPickTarget.chargeCredit(this.entryId) : type = 'chargeCredit';
  AccountPickTarget.profitDebit(this.entryId) : type = 'profitDebit';
  AccountPickTarget.profitCredit(this.entryId) : type = 'profitCredit';

  final String type;
  final String? entryId;
}
