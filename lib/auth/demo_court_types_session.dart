part of 'demo_session.dart';

extension DemoCourtTypesSession on DemoSession {
  List<DemoCourtType> get managedCourtTypes {
    _requireManager();
    return List.unmodifiable(_courtTypes);
  }

  List<DemoCourtType> get approvedCourtTypes {
    _requireReady();
    return List.unmodifiable(_courtTypes.where((t) => t.state == 'approved'));
  }

  String courtTypeName(String id) {
    _requireReady();
    return _courtTypes
            .where(
              (t) =>
                  t.id == id &&
                  (['approved', 'suspended'].contains(t.state) ||
                      (user != null && role != DemoRole.player)),
            )
            .firstOrNull
            ?.name ??
        '';
  }

  DemoCourtType saveCourtType({
    String? id,
    int? expectedRevision,
    required String name,
    required String sport,
    required String description,
  }) {
    _requireManager();
    if (role != DemoRole.owner) {
      throw StateError('Chỉ Chủ sân được đề xuất loại sân.');
    }
    final old = _courtTypes.where((t) => t.id == id).firstOrNull;
    if (id != null &&
        (old == null ||
            old.revision != expectedRevision ||
            !['draft', 'rejected'].contains(old.state))) {
      throw StateError('Hồ sơ đã thay đổi.');
    }
    if (old == null && _courtTypes.length >= 100) {
      throw StateError('Tối đa 100 loại sân demo.');
    }
    final t = DemoCourtType(
      id: old?.id ?? 'LS${_nextCourtType.toString().padLeft(4, '0')}',
      name: name.trim(),
      sport: sport,
      description: description.trim(),
      created: old?.created ?? now,
      updated: now,
      revision: old == null ? 0 : old.revision + 1,
    );
    try {
      DemoCourtType.fromJson(t.toJson());
    } on FormatException {
      throw StateError('Tên cần 3–80 ký tự, mô tả 5–1000 ký tự và môn hợp lệ.');
    }
    if (_courtTypes.any(
      (o) =>
          o.id != t.id &&
          o.sport == t.sport &&
          venueSearchText(o.name) == venueSearchText(t.name),
    )) {
      throw StateError('Tên loại sân đã tồn tại.');
    }
    if (old == null) {
      _courtTypes.add(t);
      _nextCourtType++;
    } else {
      _courtTypes[_courtTypes.indexOf(old)] = t;
    }
    _recordOperation('Lưu loại sân ${t.id}');
    return t;
  }

  void transitionCourtType(
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
    final old = _courtTypes.where((t) => t.id == id).firstOrNull;
    if (old == null || old.revision != expectedRevision) {
      throw StateError('Hồ sơ đã thay đổi.');
    }
    final allowed = role == DemoRole.owner
        ? old.state == 'draft' && state == 'pending'
        : (old.state == 'pending' &&
                  ['approved', 'rejected'].contains(state)) ||
              (old.state == 'approved' && state == 'suspended') ||
              (old.state == 'suspended' && state == 'approved');
    if (!allowed) throw StateError('Không có quyền chuyển trạng thái này.');
    final t = DemoCourtType(
      id: old.id,
      name: old.name,
      sport: old.sport,
      description: old.description,
      created: old.created,
      updated: now,
      state: state,
      revision: old.revision + 1,
      note: ['rejected', 'suspended'].contains(state) ? note.trim() : '',
      reviewDecision: requestSupplement
          ? 'supplement'
          : ['approved', 'rejected'].contains(state)
          ? state
          : old.reviewDecision,
    );
    try {
      DemoCourtType.fromJson(t.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _courtTypes[_courtTypes.indexOf(old)] = t;
    _recordOperation(
      '${t.label} loại sân ${t.id}${t.note.isEmpty ? '' : ': ${t.note}'}',
      subject: t.id,
      decision: requestSupplement
          ? 'supplement'
          : ['approved', 'rejected'].contains(state)
          ? state
          : '',
      note: t.note,
    );
  }

  void _validateFacilityType(
    FacilityProfile p, {
    FacilityProfile? retained,
    bool requireApproved = false,
  }) {
    if (p.courtTypeId.isEmpty) return;
    final t = _courtTypes.where((t) => t.id == p.courtTypeId).firstOrNull;
    if (t == null ||
        t.sport != p.sport ||
        (t.state != 'approved' &&
            (requireApproved ||
                retained?.courtTypeId != p.courtTypeId ||
                retained?.sport != p.sport))) {
      throw StateError(
        'Loại sân chưa được duyệt hoặc không phù hợp với môn thể thao.',
      );
    }
  }
}
