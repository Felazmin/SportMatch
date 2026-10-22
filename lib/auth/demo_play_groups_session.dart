part of 'demo_session.dart';

typedef DemoGroupMember = ({String identifier, String name});

extension DemoPlayGroupsSession on DemoSession {
  DemoPlayGroup? publicPlayGroup(String id) =>
      _playGroups.where((g) => g.id == id && g.state == 'approved').firstOrNull;
  Map<String, String> get publicGroups => Map.unmodifiable({
    ...demoGroups,
    for (final g in _playGroups.where((g) => g.state == 'approved'))
      g.id: g.name,
  });
  List<DemoPlayGroup> get managedPlayGroups {
    _requireManager();
    return List.unmodifiable(
      _playGroups.where(
        (g) => role == DemoRole.admin || g.owner == user!.identifier,
      ),
    );
  }

  DemoPlayGroup savePlayGroup({
    String? id,
    int? expectedRevision,
    required String name,
    required String sport,
    required String description,
    bool requiresApproval = false,
    String? photo,
  }) {
    _requireManager();
    if (role != DemoRole.owner) throw StateError('Chỉ Chủ sân được tạo nhóm.');
    final old = _playGroups.where((g) => g.id == id).firstOrNull;
    if (id != null &&
        (old == null ||
            old.owner != user!.identifier ||
            old.revision != expectedRevision ||
            !['draft', 'rejected'].contains(old.state))) {
      throw StateError('Hồ sơ đã thay đổi hoặc không thể chỉnh sửa.');
    }
    if (id == null && _playGroups.length >= 100) {
      throw StateError('Đã đủ 100 nhóm demo.');
    }
    final group = DemoPlayGroup(
      id: old?.id ?? 'NC${_nextPlayGroup.toString().padLeft(4, '0')}',
      owner: user!.identifier,
      name: name.trim(),
      sport: sport,
      description: description.trim(),
      requiresApproval: requiresApproval,
      photo: photo ?? old?.photo ?? '',
      created: old?.created ?? now,
      updated: now,
      revision: old == null ? 0 : old.revision + 1,
    );
    try {
      DemoPlayGroup.fromJson(group.toJson());
    } on FormatException {
      throw StateError(
        'Tên 3–80 ký tự, mô tả 10–1.000 ký tự; chọn môn hợp lệ.',
      );
    }
    if (demoGroups.values.any(
          (name) => venueSearchText(name) == venueSearchText(group.name),
        ) ||
        _playGroups.any(
          (g) =>
              g.id != group.id &&
              venueSearchText(g.name) == venueSearchText(group.name),
        )) {
      throw StateError('Tên nhóm đã tồn tại.');
    }
    if (old == null) {
      _playGroups.add(group);
      _nextPlayGroup++;
    } else {
      _playGroups[_playGroups.indexOf(old)] = group;
    }
    _recordOperation('Lưu nhóm ${group.id}');
    return group;
  }

  void transitionPlayGroup(
    String id,
    String state,
    int expectedRevision, {
    String note = '',
    bool requestSupplement = false,
  }) {
    _requireManager();
    if (requestSupplement && state != 'rejected') {
      throw StateError('Quyết định không hợp lệ.');
    }
    final old = _playGroups.where((g) => g.id == id).firstOrNull;
    if (old == null || old.revision != expectedRevision) {
      throw StateError('Hồ sơ đã thay đổi.');
    }
    final allowed = role == DemoRole.owner
        ? old.owner == user!.identifier &&
              old.state == 'draft' &&
              state == 'pending'
        : (old.state == 'pending' &&
                  ['approved', 'rejected'].contains(state)) ||
              (old.state == 'approved' && state == 'suspended') ||
              (old.state == 'suspended' && state == 'approved');
    if (!allowed) throw StateError('Không thể chuyển trạng thái nhóm.');
    final g = DemoPlayGroup(
      id: old.id,
      owner: old.owner,
      name: old.name,
      sport: old.sport,
      description: old.description,
      requiresApproval: old.requiresApproval,
      photo: old.photo,
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      state: state,
      note: ['rejected', 'suspended'].contains(state) ? note.trim() : '',
      reviewDecision: requestSupplement
          ? 'supplement'
          : ['approved', 'rejected'].contains(state)
          ? state
          : old.reviewDecision,
    );
    try {
      DemoPlayGroup.fromJson(g.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _playGroups[_playGroups.indexOf(old)] = g;
    _recordOperation(
      '${g.label} nhóm ${g.id}',
      subject: g.id,
      decision: requestSupplement
          ? 'supplement'
          : ['approved', 'rejected'].contains(state)
          ? state
          : '',
      note: g.note,
    );
  }

  DemoGroupRequest? ownGroupRequest(String id) => _groupRequests
      .where((r) => r.groupId == id && r.member == user?.identifier)
      .firstOrNull;

  List<DemoGroupRequest> groupRequests(String id) {
    _requireManager();
    if (!managedPlayGroups.any((g) => g.id == id)) {
      throw StateError('Không có quyền quản lý nhóm.');
    }
    return List.unmodifiable(_groupRequests.where((r) => r.groupId == id));
  }

  List<DemoGroupMember> groupMembers(String id) {
    _requireManager();
    if (!managedPlayGroups.any((g) => g.id == id)) {
      throw StateError('Không có quyền quản lý nhóm.');
    }
    final members =
        [
          for (final entry in _groups.entries)
            if (entry.value.contains(id))
              (
                identifier: entry.key,
                name: entry.key == DemoSession.phone
                    ? _demoUser.name
                    : _registered[entry.key]?.user.name ??
                          _staff[entry.key]?.user.name ??
                          entry.key,
              ),
        ]..sort((a, b) {
          final name = venueSearchText(a.name)
              .compareTo(venueSearchText(b.name));
          return name != 0 ? name : a.identifier.compareTo(b.identifier);
        });
    return List.unmodifiable(members);
  }

  String groupMemberName(String identifier) {
    _requireManager();
    if (!_groupRequests.any(
      (r) =>
          r.member == identifier &&
          managedPlayGroups.any((g) => g.id == r.groupId),
    )) {
      throw StateError('Không có thành viên trong nhóm được quản lý.');
    }
    return identifier == DemoSession.phone
        ? _demoUser.name
        : _registered[identifier]?.user.name ?? identifier;
  }

  void reviewGroupRequest(
    String groupId,
    String member,
    int expectedRevision, {
    required bool approve,
    String note = '',
  }) {
    _requireManager();
    final g = managedPlayGroups.where((g) => g.id == groupId).firstOrNull;
    final old = _groupRequests
        .where((r) => r.groupId == groupId && r.member == member)
        .firstOrNull;
    if (g == null ||
        g.state != 'approved' ||
        !g.requiresApproval ||
        old == null ||
        old.state != 'pending' ||
        old.revision != expectedRevision ||
        _operations.blocked.contains(member)) {
      throw StateError(
        'Yêu cầu đã thay đổi hoặc nhóm/tài khoản không hoạt động.',
      );
    }
    final next = DemoGroupRequest(
      groupId: groupId,
      member: member,
      state: approve ? 'approved' : 'rejected',
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      note: approve ? '' : note.trim(),
    );
    try {
      DemoGroupRequest.fromJson(next.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _groupRequests[_groupRequests.indexOf(old)] = next;
    if (approve) _groups.putIfAbsent(member, () => <String>{}).add(groupId);
    _recordOperation(
      '${approve ? 'Duyệt' : 'Từ chối'} thành viên nhóm $groupId',
    );
  }

  void removeGroupMember(
    String groupId,
    String member,
    int expectedRevision, {
    required String reason,
  }) {
    _requireManager();
    final g = managedPlayGroups.where((g) => g.id == groupId).firstOrNull;
    final old = _groupRequests
        .where((r) => r.groupId == groupId && r.member == member)
        .firstOrNull;
    if (g == null ||
        !g.requiresApproval ||
        !['approved', 'suspended'].contains(g.state) ||
        old == null ||
        old.state != 'approved' ||
        old.revision != expectedRevision ||
        !(_groups[member]?.contains(groupId) ?? false)) {
      throw StateError('Thành viên hoặc nhóm đã thay đổi. Mở lại hồ sơ.');
    }
    final next = DemoGroupRequest(
      groupId: groupId,
      member: member,
      state: 'removed',
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      note: reason.trim(),
    );
    try {
      DemoGroupRequest.fromJson(next.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _groupRequests[_groupRequests.indexOf(old)] = next;
    _groups[member]!.remove(groupId);
    _recordOperation('Thu hồi thành viên $member nhóm $groupId: ${next.note}');
  }
}
