import 'demo_finance.dart';

class DemoBankAccount {
  const DemoBankAccount({
    required this.bank,
    required this.holder,
    required this.number,
    required this.revision,
  });
  final String bank, holder, number;
  final int revision;
  String get masked => '•••• ${number.substring(number.length - 4)}';
  Map<String, Object?> toJson() => {
    'bank': bank,
    'holder': holder,
    'number': number,
    'revision': revision,
  };
  factory DemoBankAccount.fromJson(Map<String, dynamic> j) {
    final a = DemoBankAccount(
      bank: j['bank'] as String,
      holder: j['holder'] as String,
      number: j['number'] as String,
      revision: j['revision'] as int,
    );
    if (a.bank.trim() != a.bank ||
        a.bank.length < 3 ||
        a.bank.length > 80 ||
        a.holder.trim() != a.holder ||
        a.holder.length < 3 ||
        a.holder.length > 60 ||
        !RegExp(r'^\d{6,24}$').hasMatch(a.number) ||
        a.revision < 1) {
      throw const FormatException('Invalid payout bank account');
    }
    return a;
  }
}

class DemoPayout {
  const DemoPayout({
    required this.id,
    required this.amount,
    required this.account,
    required this.created,
    required this.updated,
    this.state = 'pending',
    this.revision = 0,
    this.reference = '',
    this.proof = '',
    this.note = '',
  });
  final String id, state, reference, proof, note;
  final int amount, revision;
  final DemoBankAccount account;
  final DateTime created, updated;
  String get label => const {
    'pending': 'Chờ chi trả demo',
    'recorded': 'Đã ghi nhận chứng từ demo',
    'rejected': 'Đã từ chối',
  }[state]!;
  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'account': account.toJson(),
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'state': state,
    'revision': revision,
    'reference': reference,
    'proof': proof,
    'note': note,
  };
  factory DemoPayout.fromJson(Map<String, dynamic> j) {
    final p = DemoPayout(
      id: j['id'] as String,
      amount: j['amount'] as int,
      account: DemoBankAccount.fromJson(j['account'] as Map<String, dynamic>),
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
      state: j['state'] as String,
      revision: j['revision'] as int,
      reference: j['reference'] as String,
      proof: j['proof'] as String,
      note: j['note'] as String,
    );
    if (!RegExp(r'^CT\d{4,}$').hasMatch(p.id) ||
        int.parse(p.id.substring(2)) < 1 ||
        p.amount < 1000 ||
        p.amount > 1000000000 ||
        p.amount % 1000 != 0 ||
        !['pending', 'recorded', 'rejected'].contains(p.state) ||
        p.revision < 0 ||
        (p.state != 'pending' && p.revision < 1) ||
        p.updated.isBefore(p.created) ||
        (p.state == 'recorded'
            ? p.reference.trim() != p.reference ||
                  p.reference.length < 3 ||
                  p.reference.length > 80 ||
                  p.note.isNotEmpty
            : p.reference.isNotEmpty || p.proof.isNotEmpty) ||
        (p.state == 'rejected'
            ? p.note.trim() != p.note ||
                  p.note.length < 5 ||
                  p.note.length > 300
            : p.note.isNotEmpty)) {
      throw const FormatException('Invalid payout record');
    }
    if (p.state == 'recorded') decodeProof(p.proof);
    return p;
  }
}
