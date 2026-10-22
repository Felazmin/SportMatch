part of 'demo_session.dart';

extension DemoMatchesSession on DemoSession {
  void _requireAllocatedCourt(DemoParticipation ticket, int court) {
    final allocated = eventCourts(ticket.eventId, ticket.start);
    if (allocated.isNotEmpty && !allocated.any((b) => b.court == court)) {
      throw StateError('Chọn một sân đã phân cho giải đấu.');
    }
  }

  List<DemoTournamentEntry> get managedTournaments {
    _requireManager();
    final events = <(String, DateTime), DemoEvent>{
      for (final e in demoEvents.where(
        (e) => e.kind == DemoEventKind.tournament,
      ))
        (e.id, e.start(now)): e,
      for (final a in managedActivities.where(
        (a) =>
            a.event.kind == DemoEventKind.tournament &&
            ['approved', 'suspended'].contains(a.state),
      ))
        (a.id, a.event.scheduledStart!): a.event,
      for (final p in _participations.where(
        (p) => p.event.kind == DemoEventKind.tournament,
      ))
        (p.eventId, p.start): p.event,
    };
    return List.unmodifiable(
      [
        for (final e in events.entries)
          DemoTournamentEntry(
            event: e.value,
            start: e.key.$2,
            teams: _participations
                .where(
                  (p) =>
                      !p.cancelled &&
                      p.eventId == e.key.$1 &&
                      p.start == e.key.$2,
                )
                .length,
            matches: tournamentMatches(
              e.key.$1,
              e.key.$2,
            ).where((m) => m.state != 'cancelled').length,
            completed: tournamentMatches(
              e.key.$1,
              e.key.$2,
            ).where((m) => m.state == 'completed').length,
          ),
      ]..sort((a, b) {
        final day = a.start.compareTo(b.start);
        return day != 0 ? day : a.event.id.compareTo(b.event.id);
      }),
    );
  }

  List<DemoMatch> ownTournamentMatches(String eventId, DateTime start) {
    final matches = tournamentMatches(eventId, start);
    if (role != DemoRole.player) {
      throw StateError('Chỉ tài khoản người chơi có lịch đội của mình.');
    }
    final ids = _participations
        .where(
          (p) =>
              p.owner == user!.identifier &&
              p.eventId == eventId &&
              p.start == start,
        )
        .map((p) => p.id)
        .toSet();
    return List.unmodifiable(
      matches.where((m) => ids.contains(m.first) || ids.contains(m.second)),
    );
  }

  List<DemoTeamResults> tournamentResults(String eventId, DateTime start) {
    final completed = tournamentMatches(
      eventId,
      start,
    ).where((m) => m.state == 'completed').toList();
    final results = <DemoTeamResults>[];
    for (final p in _participations.where(
      (p) =>
          p.event.kind == DemoEventKind.tournament &&
          p.eventId == eventId &&
          p.start == start,
    )) {
      var played = 0, wins = 0, scored = 0, conceded = 0;
      for (final m in completed.where(
        (m) => m.first == p.id || m.second == p.id,
      )) {
        final first = m.first == p.id;
        final a = first ? m.firstScore! : m.secondScore!;
        final b = first ? m.secondScore! : m.firstScore!;
        played++;
        scored += a;
        conceded += b;
        if (a > b) wins++;
      }
      results.add(
        DemoTeamResults(
          ticketId: p.id,
          team: p.team,
          cancelled: p.cancelled,
          played: played,
          wins: wins,
          losses: played - wins,
          scored: scored,
          conceded: conceded,
        ),
      );
    }
    results.sort((a, b) {
      final name = venueSearchText(a.team).compareTo(venueSearchText(b.team));
      return name != 0 ? name : a.ticketId.compareTo(b.ticketId);
    });
    return List.unmodifiable(results);
  }

  List<DemoMatch> tournamentMatches(String eventId, DateTime start) {
    _requireReady();
    if (user == null ||
        (role == DemoRole.player &&
            !_participations.any(
              (p) =>
                  p.owner == user!.identifier &&
                  p.eventId == eventId &&
                  p.start == start,
            ))) {
      throw StateError('Cần tài khoản quản lý hoặc vé của giải đấu này.');
    }
    final ids = _participations
        .where((p) => p.eventId == eventId && p.start == start)
        .map((p) => p.id)
        .toSet();
    return List.unmodifiable(
      _matches.where((m) => ids.contains(m.first)).toList()
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  String tournamentTeam(String ticketId) {
    final p = _participations.where((p) => p.id == ticketId).firstOrNull;
    if (p == null) throw StateError('Không tìm thấy đội.');
    tournamentMatches(p.eventId, p.start);
    return '${p.team} · ${p.id}${p.cancelled ? ' (đã hủy vé)' : ''}';
  }

  DemoMatch scheduleTournamentMatch({
    required String first,
    required String second,
    required DateTime start,
    required int court,
  }) {
    _requireManager();
    final a = _participations.where((p) => p.id == first).firstOrNull;
    final b = _participations.where((p) => p.id == second).firstOrNull;
    if (a != null) _requireAllocatedCourt(a, court);
    if (a == null ||
        b == null ||
        a.cancelled ||
        b.cancelled ||
        !start.isAfter(now) ||
        a.attendance == DemoAttendance.absent ||
        b.attendance == DemoAttendance.absent) {
      throw StateError('Chọn hai vé còn hiệu lực và giờ đấu tương lai.');
    }
    final m = DemoMatch(
      id: 'TD${_nextMatch.toString().padLeft(4, '0')}',
      first: first,
      second: second,
      start: start,
      court: court,
    );
    try {
      DemoMatch.fromJson(m.toJson());
      validateMatches([..._matches, m], _participations, _nextMatch + 1);
    } on FormatException {
      throw StateError(
        'Hai đội phải thuộc cùng giải; trận 30 phút nằm trong giờ giải, không trùng sân hoặc đội.',
      );
    }
    _matches.add(m);
    _nextMatch++;
    _recordOperation('Xếp lịch trận ${m.id}');
    return m;
  }

  void finishTournamentMatch(
    String id,
    int expectedRevision,
    int firstScore,
    int secondScore,
  ) => _changeTournamentMatch(
    id,
    expectedRevision,
    'completed',
    firstScore: firstScore,
    secondScore: secondScore,
  );

  void rescheduleTournamentMatch(
    String id,
    int expectedRevision,
    DateTime start,
    int court,
    String reason,
  ) {
    _requireManager();
    final old = _matches.where((m) => m.id == id).firstOrNull;
    if (old == null ||
        old.revision != expectedRevision ||
        old.state != 'scheduled' ||
        !old.start.isAfter(now) ||
        !start.isAfter(now)) {
      throw StateError(
        'Chỉ đổi lịch trận chưa bắt đầu; mở lại lịch nếu đã thay đổi.',
      );
    }
    if (old.start == start && old.court == court) {
      throw StateError('Chọn giờ hoặc sân khác lịch hiện tại.');
    }
    final teams = _participations.where(
      (p) => p.id == old.first || p.id == old.second,
    );
    _requireAllocatedCourt(teams.first, court);
    if (teams.any(
      (p) => p.cancelled || p.attendance == DemoAttendance.absent,
    )) {
      throw StateError('Đội đã hủy vé hoặc vắng mặt.');
    }
    final note = reason.trim();
    if (note.length < 5 || note.length > 300) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    final m = DemoMatch(
      id: old.id,
      first: old.first,
      second: old.second,
      start: start,
      court: court,
      revision: old.revision + 1,
      note: note,
    );
    try {
      DemoMatch.fromJson(m.toJson());
      validateMatches(
        [for (final current in _matches) current.id == id ? m : current],
        _participations,
        _nextMatch,
      );
    } on FormatException {
      throw StateError(
        'Lịch mới phải nằm trong giải, không trùng sân hoặc đội.',
      );
    }
    _matches[_matches.indexOf(old)] = m;
    _recordOperation(
      'Đổi lịch $id: ${old.start.toIso8601String()} sân ${old.court} → '
      '${start.toIso8601String()} sân $court; $note',
    );
  }

  void correctTournamentResult(
    String id,
    int expectedRevision,
    int firstScore,
    int secondScore,
    String reason,
  ) {
    _requireAdmin();
    final old = _matches.where((m) => m.id == id).firstOrNull;
    if (old == null ||
        old.revision != expectedRevision ||
        old.state != 'completed' ||
        now.isBefore(old.end)) {
      throw StateError('Kết quả đã thay đổi hoặc chưa thể sửa.');
    }
    if (firstScore == old.firstScore && secondScore == old.secondScore) {
      throw StateError('Điểm mới phải khác kết quả hiện tại.');
    }
    final note = reason.trim();
    if (note.length < 5 || note.length > 300) {
      throw StateError('Lý do cần 5–300 ký tự.');
    }
    final m = DemoMatch(
      id: old.id,
      first: old.first,
      second: old.second,
      start: old.start,
      court: old.court,
      revision: old.revision + 1,
      state: 'completed',
      firstScore: firstScore,
      secondScore: secondScore,
      note: note,
    );
    try {
      DemoMatch.fromJson(m.toJson());
    } on FormatException {
      throw StateError('Điểm 0–99 và không hòa.');
    }
    _matches[_matches.indexOf(old)] = m;
    _recordOperation(
      'Sửa kết quả $id: ${old.firstScore}:${old.secondScore} → '
      '$firstScore:$secondScore; $note',
    );
  }

  void cancelTournamentMatch(String id, int expectedRevision, String note) =>
      _changeTournamentMatch(
        id,
        expectedRevision,
        'cancelled',
        note: note.trim(),
      );

  void _changeTournamentMatch(
    String id,
    int revision,
    String state, {
    int? firstScore,
    int? secondScore,
    String note = '',
  }) {
    _requireManager();
    final old = _matches.where((m) => m.id == id).firstOrNull;
    if (old == null || old.revision != revision || old.state != 'scheduled') {
      throw StateError('Trận đã thay đổi hoặc đã chốt kết quả.');
    }
    if (state == 'completed') {
      final teams = _participations.where(
        (p) => p.id == old.first || p.id == old.second,
      );
      if (now.isBefore(old.end) ||
          teams.any(
            (p) =>
                p.cancelled ||
                ![
                  DemoAttendance.checkedIn,
                  DemoAttendance.completed,
                ].contains(p.attendance),
          )) {
        throw StateError(
          'Chỉ ghi kết quả sau giờ kết thúc, cả hai đội đã check-in.',
        );
      }
    }
    final m = DemoMatch(
      id: old.id,
      first: old.first,
      second: old.second,
      start: old.start,
      court: old.court,
      revision: old.revision + 1,
      state: state,
      firstScore: firstScore,
      secondScore: secondScore,
      note: note,
    );
    try {
      DemoMatch.fromJson(m.toJson());
    } on FormatException {
      throw StateError('Điểm 0–99, không hòa; lý do hủy cần 5–300 ký tự.');
    }
    _matches[_matches.indexOf(old)] = m;
    _recordOperation('${m.label} ${m.id}');
  }
}
