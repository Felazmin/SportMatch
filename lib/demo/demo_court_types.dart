import 'demo_facilities.dart';

class DemoCourtType {
  const DemoCourtType({
    required this.id,
    required this.name,
    required this.sport,
    required this.description,
    required this.created,
    required this.updated,
    this.state = 'draft',
    this.note = '',
    this.revision = 0,
    this.reviewDecision = '',
  });
  final String id, name, sport, description, state, note;
  final DateTime created, updated;
  final int revision;
  final String reviewDecision;
  String get label => switch (state) {
    'draft' => 'Bản nháp',
    'pending' => 'Chờ duyệt',
    'approved' => 'Đã duyệt',
    'rejected' => reviewDecision == 'rejected' ? 'Bị từ chối' : 'Cần bổ sung',
    'suspended' => 'Tạm ngưng',
    _ => 'Không hợp lệ',
  };
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sport': sport,
    'description': description,
    'state': state,
    'note': note,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'revision': revision,
    'reviewDecision': reviewDecision,
  };
  factory DemoCourtType.fromJson(Map<String, dynamic> j) {
    final t = DemoCourtType(
      id: j['id'] as String,
      name: j['name'] as String,
      sport: j['sport'] as String,
      description: j['description'] as String,
      state: j['state'] as String,
      note: j['note'] as String,
      created: DateTime.parse(j['created'] as String),
      updated: DateTime.parse(j['updated'] as String),
      revision: j['revision'] as int,
      reviewDecision: (j['reviewDecision'] ?? '') as String,
    );
    final minimum = switch (t.state) {
      'draft' => 0,
      'pending' => 1,
      'approved' || 'rejected' => 2,
      'suspended' => 3,
      _ => -1,
    };
    if (![
          '',
          'approved',
          'supplement',
          'rejected',
        ].contains(t.reviewDecision) ||
        !RegExp(r'^LS\d{4,}$').hasMatch(t.id) ||
        t.name != t.name.trim() ||
        t.name.length < 3 ||
        t.name.length > 80 ||
        !facilitySports.contains(t.sport) ||
        t.description.trim().length < 5 ||
        t.description.length > 1000 ||
        minimum < 0 ||
        t.revision < minimum ||
        t.updated.isBefore(t.created) ||
        t.note != t.note.trim() ||
        t.note.length > 300 ||
        (['rejected', 'suspended'].contains(t.state)
            ? t.note.length < 5
            : t.note.isNotEmpty)) {
      throw const FormatException('Invalid court type');
    }
    return t;
  }
}
