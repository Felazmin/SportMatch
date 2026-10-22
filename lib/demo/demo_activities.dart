import 'demo_events.dart';

class DemoActivity {
  const DemoActivity({
    required this.event,
    required this.owner,
    required this.created,
    required this.updated,
    this.state = 'draft',
    this.note = '',
    this.revision = 0,
    this.groupId = '',
    this.reviewDecision = '',
  });
  final DemoEvent event;
  final String owner, state, note;
  final DateTime created, updated;
  final int revision;
  final String groupId;
  final String reviewDecision;
  String get id => event.id;
  String get label => {
    'draft': 'Bản nháp',
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'rejected': reviewDecision == 'supplement' ? 'Cần bổ sung' : 'Bị từ chối',
    'suspended': 'Tạm ngưng',
    'cancelled': 'Đã hủy hoạt động',
  }[state]!;
  Map<String, Object?> toJson() => {
    'event': event.toJson(),
    'owner': owner,
    'state': state,
    'note': note,
    'revision': revision,
    'groupId': groupId,
    'reviewDecision': reviewDecision,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
  };
  factory DemoActivity.fromJson(Map<String, dynamic> j) {
    final a = DemoActivity(
      event: DemoEvent.fromJson(j['event'] as Map<String, dynamic>),
      owner: j['owner'] as String,
      state: j['state'] as String,
      note: j['note'] as String,
      revision: j['revision'] as int,
      groupId: (j['groupId'] ?? '') as String,
      reviewDecision: (j['reviewDecision'] ?? '') as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
    );
    final minimum = const {
      'draft': 0,
      'pending': 1,
      'approved': 2,
      'rejected': 2,
      'suspended': 3,
      'cancelled': 3,
    }[a.state];
    if (![
          '',
          'approved',
          'supplement',
          'rejected',
        ].contains(a.reviewDecision) ||
        minimum == null ||
        (a.state == 'cancelled' &&
            !a.updated.isBefore(a.event.scheduledStart!)) ||
        (a.groupId.isNotEmpty && !RegExp(r'^NC\d{4,}$').hasMatch(a.groupId)) ||
        a.owner != '__owner__' ||
        a.revision < minimum ||
        a.updated.isBefore(a.created) ||
        (['rejected', 'suspended', 'cancelled'].contains(a.state)
            ? a.note.trim() != a.note ||
                  a.note.length < 5 ||
                  a.note.length > 300
            : a.note.isNotEmpty)) {
      throw const FormatException('Invalid activity workflow');
    }
    return a;
  }
}
