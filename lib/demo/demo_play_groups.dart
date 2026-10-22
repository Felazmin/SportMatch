import 'demo_finance.dart';

const playGroupSports = {
  'badminton': 'Cầu lông',
  'football': 'Bóng đá',
  'pickleball': 'Pickleball',
};

class DemoPlayGroup {
  const DemoPlayGroup({
    required this.id,
    required this.owner,
    required this.name,
    required this.sport,
    required this.description,
    required this.created,
    required this.updated,
    this.state = 'draft',
    this.note = '',
    this.revision = 0,
    this.requiresApproval = false,
    this.photo = '',
    this.reviewDecision = '',
  });
  final String id, owner, name, sport, description, state, note;
  final DateTime created, updated;
  final int revision;
  final bool requiresApproval;
  final String photo;
  final String reviewDecision;
  String get label => {
    'draft': 'Bản nháp',
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'rejected': reviewDecision == 'supplement' ? 'Cần bổ sung' : 'Bị từ chối',
    'suspended': 'Tạm ngưng',
  }[state]!;
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'name': name,
    'sport': sport,
    'description': description,
    'state': state,
    'note': note,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'revision': revision,
    'requiresApproval': requiresApproval,
    'photo': photo,
    'reviewDecision': reviewDecision,
  };
  factory DemoPlayGroup.fromJson(Map<String, dynamic> j) {
    final g = DemoPlayGroup(
      id: j['id'] as String,
      owner: j['owner'] as String,
      name: j['name'] as String,
      sport: j['sport'] as String,
      description: j['description'] as String,
      state: j['state'] as String,
      note: j['note'] as String,
      revision: j['revision'] as int,
      requiresApproval: (j['requiresApproval'] ?? false) as bool,
      photo: (j['photo'] ?? '') as String,
      reviewDecision: (j['reviewDecision'] ?? '') as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
    );
    if (![
          '',
          'approved',
          'supplement',
          'rejected',
        ].contains(g.reviewDecision) ||
        !RegExp(r'^NC\d{4,}$').hasMatch(g.id) ||
        int.parse(g.id.substring(2)) < 1 ||
        g.owner != '__owner__' ||
        g.name.trim() != g.name ||
        g.name.length < 3 ||
        g.name.length > 80 ||
        !playGroupSports.containsKey(g.sport) ||
        g.description.trim() != g.description ||
        g.description.length < 10 ||
        g.description.length > 1000 ||
        g.updated.isBefore(g.created) ||
        ![
          'draft',
          'pending',
          'approved',
          'rejected',
          'suspended',
        ].contains(g.state) ||
        g.revision < 0 ||
        (g.state != 'draft' && g.revision < 1) ||
        ((g.state == 'rejected' || g.state == 'suspended')
            ? g.note.trim() != g.note ||
                  g.note.length < 5 ||
                  g.note.length > 300
            : g.note.isNotEmpty)) {
      throw const FormatException('Invalid play group');
    }
    if (g.photo.isNotEmpty) decodeProof(g.photo);
    return g;
  }
}

class DemoGroupRequest {
  const DemoGroupRequest({
    required this.groupId,
    required this.member,
    required this.state,
    required this.created,
    required this.updated,
    required this.revision,
    this.note = '',
  });
  final String groupId, member, state, note;
  final DateTime created, updated;
  final int revision;
  String get key => '$groupId:$member';
  String get label => const {
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'rejected': 'Từ chối',
    'withdrawn': 'Đã rút',
    'removed': 'Đã thu hồi tư cách',
  }[state]!;
  Map<String, Object?> toJson() => {
    'groupId': groupId,
    'member': member,
    'state': state,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'revision': revision,
    'note': note,
  };
  factory DemoGroupRequest.fromJson(Map<String, dynamic> j) {
    final r = DemoGroupRequest(
      groupId: j['groupId'] as String,
      member: j['member'] as String,
      state: j['state'] as String,
      created: DateTime.parse(j['created'] as String).toLocal(),
      updated: DateTime.parse(j['updated'] as String).toLocal(),
      revision: j['revision'] as int,
      note: j['note'] as String,
    );
    if (!RegExp(r'^NC\d{4,}$').hasMatch(r.groupId) ||
        r.member.isEmpty ||
        ![
          'pending',
          'approved',
          'rejected',
          'withdrawn',
          'removed',
        ].contains(r.state) ||
        r.updated.isBefore(r.created) ||
        r.revision < 0 ||
        (r.state != 'pending' && r.revision < 1) ||
        (['rejected', 'removed'].contains(r.state)
            ? r.note.trim() != r.note ||
                  r.note.length < 5 ||
                  r.note.length > 300
            : r.note.isNotEmpty)) {
      throw const FormatException('Invalid group request');
    }
    return r;
  }
}
