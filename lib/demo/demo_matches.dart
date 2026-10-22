import 'demo_events.dart';
import 'demo_finance.dart';

class DemoTeamResults {
  const DemoTeamResults({
    required this.ticketId,
    required this.team,
    required this.cancelled,
    required this.played,
    required this.wins,
    required this.losses,
    required this.scored,
    required this.conceded,
  });
  final String ticketId, team;
  final bool cancelled;
  final int played, wins, losses, scored, conceded;
  int get difference => scored - conceded;
}

class DemoTournamentEntry {
  const DemoTournamentEntry({
    required this.event,
    required this.start,
    required this.teams,
    required this.matches,
    required this.completed,
  });
  final DemoEvent event;
  final DateTime start;
  final int teams, matches, completed;
}

class DemoMatch {
  const DemoMatch({
    required this.id,
    required this.first,
    required this.second,
    required this.start,
    required this.court,
    this.revision = 0,
    this.state = 'scheduled',
    this.firstScore,
    this.secondScore,
    this.note = '',
  });
  final String id, first, second, state, note;
  final DateTime start;
  final int court, revision;
  final int? firstScore, secondScore;
  DateTime get end => start.add(const Duration(minutes: 30));
  String get label => switch (state) {
    'completed' => 'Đã có kết quả',
    'cancelled' => 'Đã hủy trận',
    _ => 'Đã xếp lịch',
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'first': first,
    'second': second,
    'start': start.toIso8601String(),
    'court': court,
    'revision': revision,
    'state': state,
    'firstScore': firstScore,
    'secondScore': secondScore,
    'note': note,
  };
  factory DemoMatch.fromJson(Map<String, dynamic> j) {
    final m = DemoMatch(
      id: j['id'] as String,
      first: j['first'] as String,
      second: j['second'] as String,
      start: DateTime.parse(j['start'] as String),
      court: j['court'] as int,
      revision: j['revision'] as int,
      state: j['state'] as String,
      firstScore: j['firstScore'] as int?,
      secondScore: j['secondScore'] as int?,
      note: j['note'] as String,
    );
    if (!RegExp(r'^TD[0-9]{4,}$').hasMatch(m.id) ||
        int.parse(m.id.substring(2)) < 1 ||
        m.first == m.second ||
        m.court < 1 ||
        m.court > 3 ||
        m.revision < 0 ||
        m.start.isUtc ||
        m.start.minute % 30 != 0 ||
        m.start.second != 0 ||
        m.start.millisecond != 0 ||
        m.start.microsecond != 0 ||
        !['scheduled', 'completed', 'cancelled'].contains(m.state) ||
        (m.state != 'scheduled' && m.revision < 1) ||
        (m.state == 'completed'
            ? m.firstScore == null ||
                  m.secondScore == null ||
                  m.firstScore! < 0 ||
                  m.firstScore! > 99 ||
                  m.secondScore! < 0 ||
                  m.secondScore! > 99 ||
                  m.firstScore == m.secondScore
            : m.firstScore != null || m.secondScore != null) ||
        (m.state == 'cancelled'
            ? m.note.trim() != m.note ||
                  m.note.length < 5 ||
                  m.note.length > 300
            : m.note.isNotEmpty &&
                  (m.note.trim() != m.note ||
                      m.note.length < 5 ||
                      m.note.length > 300 ||
                      m.revision < 1))) {
      throw const FormatException('Invalid tournament match');
    }
    return m;
  }
}

// Ticket IDs preserve the event date and team identity, including historical cancellations.
void validateMatches(
  List<DemoMatch> matches,
  List<DemoParticipation> tickets,
  int nextId,
) {
  final byId = {for (final p in tickets) p.id: p};
  final ids = <String>{};
  if (matches.length > 1000 || nextId < 1) {
    throw const FormatException('Invalid match registry');
  }
  for (final m in matches) {
    final a = byId[m.first], b = byId[m.second];
    if (!ids.add(m.id) ||
        int.parse(m.id.substring(2)) >= nextId ||
        a == null ||
        b == null ||
        a.event.kind != DemoEventKind.tournament ||
        a.eventId != b.eventId ||
        a.start != b.start ||
        m.start.isBefore(a.start) ||
        m.end.isAfter(a.event.end(a.start))) {
      throw const FormatException('Invalid match ticket link');
    }
    if (m.state == 'completed' &&
        [a, b].any(
          (p) =>
              p.cancelled ||
              ![
                DemoAttendance.checkedIn,
                DemoAttendance.completed,
              ].contains(p.attendance),
        )) {
      throw const FormatException('Invalid match attendance');
    }
    if (m.state == 'cancelled') continue;
    for (final other in matches.where(
      (o) => o.id != m.id && o.state != 'cancelled',
    )) {
      if (m.start.isBefore(other.end) &&
          other.start.isBefore(m.end) &&
          (m.court == other.court ||
              [
                m.first,
                m.second,
              ].any((id) => id == other.first || id == other.second))) {
        throw const FormatException('Overlapping tournament matches');
      }
    }
  }
}
