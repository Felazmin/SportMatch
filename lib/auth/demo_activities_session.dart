part of 'demo_session.dart';

extension DemoActivitiesSession on DemoSession {
  bool eventOccurrenceExists(String eventId, DateTime start) {
    final event = _activityEvent(eventId);
    if (event == null) return false;
    if (event.scheduledStart != null) return start == event.scheduledStart;
    return start == event.start(now) ||
        _participations.any((p) => p.eventId == eventId && p.start == start) ||
        _courtBlocks.any((b) => b.eventId == eventId && b.start == start);
  }

  List<DemoCourtBlock> eventCourts(String eventId, DateTime start) =>
      List.unmodifiable(
        _courtBlocks.where((b) => b.eventId == eventId && b.start == start),
      );

  void allocateEventCourts(
    String eventId,
    DateTime start,
    List<int> courts, {
    required List<String> expectedBlockIds,
  }) {
    _requireManager();
    final event = _activityEvent(eventId);
    final current = eventCourts(eventId, start);
    final activity = _activities.where((a) => a.id == eventId).firstOrNull;
    if (event == null ||
        !eventOccurrenceExists(eventId, start) ||
        !start.isAfter(now) ||
        bookingDay(start)
            .isAfter(bookingDay(now).add(const Duration(days: 6))) ||
        eventCancellation(eventId, start) != null ||
        (activity != null &&
            !['approved', 'suspended'].contains(activity.state)) ||
        !setEquals(
          current.map((b) => b.id).toSet(),
          expectedBlockIds.toSet(),
        ) ||
        expectedBlockIds.length != current.length ||
        courts.toSet().length != courts.length ||
        courts.any(
          (c) => c < 1 || c > 3 || !_operations.published.enabled[c - 1],
        )) {
      throw StateError(
        'Lịch hoặc phân sân đã thay đổi; chọn sân hoạt động trong 7 ngày.',
      );
    }
    final ids = _participations
        .where((p) => p.eventId == eventId && p.start == start)
        .map((p) => p.id)
        .toSet();
    if (_matches.any(
      (m) =>
          ids.contains(m.first) &&
          m.state != 'cancelled' &&
          !courts.contains(m.court),
    )) {
      throw StateError(
        'Sân phải bao gồm tất cả trận đã xếp lịch; đổi/hủy trận trước.',
      );
    }
    final next = <DemoCourtBlock>[];
    for (final court in courts) {
      final b = DemoCourtBlock(
        id: 'KB${(_nextBlock + next.length).toString().padLeft(4, '0')}',
        court: court,
        start: start,
        hours: event.durationMinutes ~/ 60,
        eventId: eventId,
        reason: 'Hoạt động: ${event.title}',
      );
      DemoCourtBlock.fromJson(b.toJson());
      if (_bookings.any(
            (r) =>
                !r.cancelled &&
                r.facilityId.isEmpty &&
                r.court == court &&
                start.isBefore(r.end) &&
                b.end.isAfter(r.start),
          ) ||
          _courtBlocks.any(
            (r) =>
                !current.contains(r) &&
                r.facilityId.isEmpty &&
                r.court == court &&
                start.isBefore(r.end) &&
                b.end.isAfter(r.start),
          )) {
        throw StateError('Sân $court đang có lịch đặt hoặc khóa giờ.');
      }
      next.add(b);
    }
    if (_courtBlocks.length - current.length + next.length > 500) {
      throw StateError('Đã đạt giới hạn lịch khóa demo.');
    }
    if (setEquals(current.map((b) => b.court).toSet(), courts.toSet())) return;
    _courtBlocks.removeWhere(current.contains);
    _courtBlocks.addAll(next);
    _nextBlock += next.length;
    _recordOperation(
      'Phân sân $eventId ${start.toIso8601String()}: ${courts.join(', ')}',
    );
  }

  DemoEventCancellation? eventCancellation(String eventId, DateTime start) =>
      _eventCancellations
          .where((c) => c.eventId == eventId && c.start == start)
          .firstOrNull;

  void cancelEventOccurrence(String eventId, DateTime start, String reason) {
    _requireManager();
    final event = demoEvents.where((e) => e.id == eventId).firstOrNull;
    final note = reason.trim();
    if (event == null ||
        !eventOccurrenceExists(eventId, start) ||
        !start.isAfter(now) ||
        eventCancellation(eventId, start) != null ||
        _eventCancellations.length >= 1000 ||
        note.length < 5 ||
        note.length > 300) {
      throw StateError('Lịch đã thay đổi hoặc đã hủy; lý do cần 5–300 ký tự.');
    }
    final cancellation = DemoEventCancellation(
      eventId: eventId,
      start: start,
      created: now,
      actor: user!.identifier,
      reason: note,
    );
    DemoEventCancellation.fromJson(cancellation.toJson());
    final tickets = _participations
        .where((p) => p.eventId == eventId && p.start == start)
        .toList();
    if (tickets.any(
      (p) => !p.cancelled && p.attendance != DemoAttendance.pending,
    )) {
      throw StateError('Buổi đã có check-in, không thể hủy toàn bộ.');
    }
    _cancelEventTickets(tickets, note);
    _courtBlocks.removeWhere((b) => b.eventId == eventId && b.start == start);
    _eventCancellations.add(cancellation);
    _recordOperation(
      'Hủy buổi $eventId ${start.toIso8601String()}; hoàn đủ vé đã thanh toán',
    );
  }

  List<DemoEvent> get availableEvents => List.unmodifiable([
    ...demoEvents,
    for (final a in _activities.where(
      (a) =>
          a.state == 'approved' &&
          (a.groupId.isEmpty || publicGroups.containsKey(a.groupId)) &&
          a.event.end(a.event.scheduledStart!).isAfter(now),
    ))
      a.event,
  ]);
  List<DemoActivity> get managedActivities {
    _requireManager();
    return List.unmodifiable(
      _activities.where(
        (a) => role == DemoRole.admin || a.owner == user!.identifier,
      ),
    );
  }

  DemoEvent? _activityEvent(String id) =>
      demoEvents.where((e) => e.id == id).firstOrNull ??
      _activities.where((a) => a.id == id).firstOrNull?.event;
  List<DemoEvent> eventsForGroup(String id) => List.unmodifiable([
    for (final a in _activities.where((a) => a.groupId == id))
      if (availableEvents.any((e) => e.id == a.id)) a.event,
  ]);
  String? eventGroupName(String id) {
    final a = _activities.where((a) => a.id == id).firstOrNull;
    return a == null || a.groupId.isEmpty ? null : publicGroups[a.groupId];
  }

  DemoActivity saveActivity({
    String? id,
    int? expectedRevision,
    required String title,
    required DemoEventKind kind,
    required DateTime start,
    required int durationMinutes,
    required int capacity,
    required int fee,
    required String description,
    String groupId = '',
  }) {
    _requireManager();
    if (role != DemoRole.owner) {
      throw StateError('Chỉ Chủ sân được tạo hoạt động.');
    }
    final old = _activities.where((a) => a.id == id).firstOrNull;
    if (id != null &&
        (old == null ||
            old.owner != user!.identifier ||
            old.revision != expectedRevision ||
            !['draft', 'rejected'].contains(old.state))) {
      throw StateError('Hồ sơ đã thay đổi hoặc không thể chỉnh sửa.');
    }
    if (!start.isAfter(now) ||
        start.isUtc ||
        bookingDay(start)
            .isAfter(bookingDay(now).add(const Duration(days: 30)))) {
      throw StateError('Chọn lịch tương lai trong 30 ngày.');
    }
    if (old == null && _activities.length >= 100) {
      throw StateError('Đã đủ 100 hoạt động demo.');
    }
    final event = DemoEvent(
      // Group activities use the existing badminton event contract.
      id: old?.id ?? 'HD${_nextActivity.toString().padLeft(4, '0')}',
      title: title.trim(),
      kind: kind,
      hour: start.hour,
      scheduledStart: start,
      durationMinutes: durationMinutes,
      capacity: capacity,
      fee: fee,
      description: description.trim(),
    );
    final a = DemoActivity(
      event: event,
      groupId: groupId,
      owner: user!.identifier,
      created: old?.created ?? now,
      updated: now,
      revision: old == null ? 0 : old.revision + 1,
    );
    try {
      if (groupId.isNotEmpty &&
          !_playGroups.any(
            (g) =>
                g.id == groupId &&
                g.owner == user!.identifier &&
                g.state == 'approved' &&
                g.sport == 'badminton',
          )) {
        throw StateError('Chọn nhóm cầu lông đã duyệt và đang hoạt động.');
      }
      DemoActivity.fromJson(a.toJson());
    } on FormatException {
      throw StateError(
        'Kiểm tra tên, mô tả, giờ 06–22h, số chỗ và phí 10.000–1.000.000đ.',
      );
    }
    if (_activities.any(
      (other) =>
          other.id != a.id &&
          other.event.scheduledStart == start &&
          venueSearchText(other.event.title) == venueSearchText(event.title),
    )) {
      throw StateError('Tên hoạt động đã tồn tại ở lịch này.');
    }
    if (old == null) {
      _activities.add(a);
      _nextActivity++;
    } else {
      _activities[_activities.indexOf(old)] = a;
    }
    _recordOperation('Lưu hoạt động ${a.id}');
    return a;
  }

  void transitionActivity(
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
    final old = _activities.where((a) => a.id == id).firstOrNull;
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
    if (!allowed ||
        (['pending', 'approved'].contains(state) &&
            old.groupId.isNotEmpty &&
            !_playGroups.any(
              (g) => g.id == old.groupId && g.state == 'approved',
            )) ||
        (['pending', 'approved'].contains(state) &&
            !old.event.scheduledStart!.isAfter(now))) {
      throw StateError('Không thể chuyển trạng thái hoặc lịch đã bắt đầu.');
    }
    final a = DemoActivity(
      event: old.event,
      groupId: old.groupId,
      owner: old.owner,
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
      DemoActivity.fromJson(a.toJson());
    } on FormatException {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    _activities[_activities.indexOf(old)] = a;
    _recordOperation(
      '${a.label} hoạt động ${a.id}',
      subject: a.id,
      decision: requestSupplement
          ? 'supplement'
          : ['approved', 'rejected'].contains(state)
          ? state
          : '',
      note: a.note,
    );
  }

  void cancelActivity(String id, int expectedRevision, String reason) {
    _requireManager();
    final old = managedActivities.where((a) => a.id == id).firstOrNull;
    final note = reason.trim();
    final tickets = _participations.where((p) => p.eventId == id).toList();
    if (old == null ||
        old.revision != expectedRevision ||
        !['approved', 'suspended'].contains(old.state) ||
        !old.event.scheduledStart!.isAfter(now) ||
        note.length < 5 ||
        note.length > 300 ||
        tickets.any(
          (p) => !p.cancelled && p.attendance != DemoAttendance.pending,
        )) {
      throw StateError(
        'Chỉ hủy hoạt động chưa bắt đầu/chưa check-in; lý do cần 5–300 ký tự.',
      );
    }
    final next = DemoActivity(
      event: old.event,
      owner: old.owner,
      groupId: old.groupId,
      created: old.created,
      updated: now,
      revision: old.revision + 1,
      state: 'cancelled',
      note: note,
    );
    DemoActivity.fromJson(next.toJson());
    _cancelEventTickets(tickets, note);
    _courtBlocks.removeWhere(
      (b) => b.eventId == id && b.start == old.event.scheduledStart,
    );
    _activities[_activities.indexOf(old)] = next;
    _recordOperation('Hủy hoạt động $id; hoàn đủ vé đã thanh toán');
  }

  void _cancelEventTickets(List<DemoParticipation> tickets, String note) {
    final payments = <String, DemoPayment>{};
    for (final ticket in tickets.where((p) => !p.cancelled)) {
      final oldPayment = _payments[ticket.id];
      final p = oldPayment == null
          ? DemoPayment(bookingId: ticket.id, deadline: ticket.start)
          : DemoPayment.fromJson(oldPayment.toJson());
      p.cancellation = DemoCancellationState.accepted;
      p.cancellationReason = note;
      p.cancellationNote = note;
      p.cancellationRequestedAt ??= now;
      if (p.state == DemoPaymentState.approved) {
        p.refund = DemoRefundState.pending;
        p.refundAmount = ticket.total;
      }
      DemoPayment.fromJson(p.toJson());
      payments[ticket.id] = p;
    }
    final ticketIds = tickets.map((p) => p.id).toSet();
    final matches = <String, DemoMatch>{};
    for (final m in _matches.where(
      (m) => ticketIds.contains(m.first) && m.state != 'cancelled',
    )) {
      if (m.state != 'scheduled' || !m.start.isAfter(now)) {
        throw StateError(
          'Trận đã bắt đầu hoặc có kết quả, không thể hủy toàn bộ.',
        );
      }
      final nextMatch = DemoMatch(
        id: m.id,
        first: m.first,
        second: m.second,
        start: m.start,
        court: m.court,
        revision: m.revision + 1,
        state: 'cancelled',
        note: note,
      );
      DemoMatch.fromJson(nextMatch.toJson());
      matches[m.id] = nextMatch;
    }
    // Commit only after every affected payment and fixture has been validated.
    for (final ticket in tickets) {
      ticket.cancelled = true;
    }
    _payments.addAll(payments);
    for (var i = 0; i < _matches.length; i++) {
      _matches[i] = matches[_matches[i].id] ?? _matches[i];
    }
  }
}
