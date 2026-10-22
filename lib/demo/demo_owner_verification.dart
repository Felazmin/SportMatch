import 'demo_finance.dart';

class DemoOwnerVerification {
  const DemoOwnerVerification({
    required this.name,
    required this.phone,
    required this.proof,
    required this.state,
    required this.created,
    required this.updated,
    required this.revision,
    this.note = '',
    this.reviewDecision = '',
  });
  final String name, phone, proof, state, note, reviewDecision;
  final DateTime created, updated;
  final int revision;
  String get label => {
    'pending': 'Chờ xác minh',
    'verified': 'Đã xác minh demo',
    'rejected': reviewDecision == 'rejected'
        ? 'Bị từ chối'
        : 'Cần bổ sung hồ sơ',
  }[state]!;
  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'proof': proof,
    'state': state,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'revision': revision,
    'note': note,
    'reviewDecision': reviewDecision,
  };
  factory DemoOwnerVerification.fromJson(Map<String, dynamic> j) {
    final v = DemoOwnerVerification(
      name: j['name'] as String,
      phone: j['phone'] as String,
      proof: j['proof'] as String,
      state: j['state'] as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
      revision: j['revision'] as int,
      note: j['note'] as String,
      reviewDecision: (j['reviewDecision'] ?? '') as String,
    );
    if (![
          '',
          'approved',
          'supplement',
          'rejected',
        ].contains(v.reviewDecision) ||
        v.name.trim() != v.name ||
        v.name.length < 3 ||
        v.name.length > 60 ||
        !RegExp(r'^0[35789]\d{8}$').hasMatch(v.phone) ||
        !['pending', 'verified', 'rejected'].contains(v.state) ||
        v.revision < (v.state == 'pending' ? 1 : 2) ||
        v.updated.isBefore(v.created) ||
        (v.state == 'rejected'
            ? v.note.trim() != v.note ||
                  v.note.length < 5 ||
                  v.note.length > 300
            : v.note.isNotEmpty)) {
      throw const FormatException('Invalid owner verification');
    }
    decodeProof(v.proof);
    return v;
  }
}
