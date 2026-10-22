import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  (DemoParticipation, DemoParticipation) teams(DemoSession s) {
    final e = demoEvents.firstWhere((e) => e.kind == DemoEventKind.tournament);
    s.login(DemoSession.phone, DemoSession.password);
    final a = s.joinEvent(
      eventId: e.id,
      start: e.start(now),
      quantity: 1,
      contact: 'Minh Phat',
      contactPhone: DemoSession.phone,
      team: 'Team A',
      partner: 'Minh Anh',
    );
    s.register('Player B', 'b@example.com', 'Player1234');
    final b = s.joinEvent(
      eventId: e.id,
      start: e.start(now),
      quantity: 1,
      contact: 'Player B',
      contactPhone: DemoSession.phone,
      team: 'Team B',
      partner: 'Player C',
    );
    owner(s);
    return (a, b);
  }

  test(
    'Reschedule preserves ID/team, validates reason/window and revisions',
    () {
      final s = open();
      final (a, b) = teams(s);
      final m = s.scheduleTournamentMatch(
        first: a.id,
        second: b.id,
        start: a.start,
        court: 1,
      );
      expect(
        () => s.rescheduleTournamentMatch(m.id, 0, m.start, 1, 'Unchanged'),
        throwsStateError,
      );
      expect(
        () => s.rescheduleTournamentMatch(m.id, 0, m.start, 2, 'no'),
        throwsStateError,
      );
      expect(
        () => s.rescheduleTournamentMatch(
          m.id,
          0,
          m.start.add(const Duration(hours: 4)),
          2,
          'New time',
        ),
        throwsStateError,
      );
      s.rescheduleTournamentMatch(
        m.id,
        0,
        m.start.add(const Duration(minutes: 30)),
        2,
        'Change court schedule',
      );
      final changed = s.tournamentMatches(a.eventId, a.start).single;
      expect(
        (
          changed.id,
          changed.first,
          changed.second,
          changed.court,
          changed.revision,
        ),
        (m.id, a.id, b.id, 2, 1),
      );
      expect(
        () => s.rescheduleTournamentMatch(m.id, 0, m.start, 1, 'Stale screen'),
        throwsStateError,
      );
      expect(s.operationAudit.first.action, contains('Change court schedule'));
      s.login(DemoSession.phone, DemoSession.password);
      expect(
        () => s.rescheduleTournamentMatch(m.id, 1, m.start, 1, 'Player change'),
        throwsStateError,
      );
      owner(s);
      now = changed.start;
      expect(
        () => s.rescheduleTournamentMatch(
          m.id,
          1,
          changed.start.add(const Duration(minutes: 30)),
          1,
          'Already started',
        ),
        throwsStateError,
      );
    },
  );
  test('Reschedule rejects team overlaps and cancelled teams, leaves old slot intact', () {
    final s = open();
    final (a, b) = teams(s);
    final m = s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start,
      court: 1,
    );
    s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start.add(const Duration(hours: 1)),
      court: 2,
    );
    expect(
      () => s.rescheduleTournamentMatch(
        m.id,
        0,
        a.start.add(const Duration(hours: 1)),
        1,
        'Overlap teams',
      ),
      throwsStateError,
    );
    expect(s.tournamentMatches(a.eventId, a.start).first.start, a.start);
    s.login(DemoSession.phone, DemoSession.password);
    s.cancelParticipation(a);
    owner(s);
    expect(
      () => s.rescheduleTournamentMatch(m.id, 0, a.start, 2, 'Cancelled team'),
      throwsStateError,
    );
  });
  test(
    'Only Admin can correct completed scores; reason and stale guards apply',
    () {
      final s = open();
      final (a, b) = teams(s);
      final m = s.scheduleTournamentMatch(
        first: a.id,
        second: b.id,
        start: a.start,
        court: 1,
      );
      admin(s);
      expect(
        () => s.correctTournamentResult(m.id, 0, 10, 21, 'Wrong result'),
        throwsStateError,
      );
      now = a.start.add(const Duration(minutes: 30));
      s.login(DemoSession.phone, DemoSession.password);
      s.demoCheckIn(a);
      s.login('b@example.com', 'Player1234');
      s.demoCheckIn(b);
      owner(s);
      s.finishTournamentMatch(m.id, 0, 21, 10);
      expect(
        () => s.correctTournamentResult(m.id, 1, 10, 21, 'Owner correction'),
        throwsStateError,
      );
      admin(s);
      for (final scores in [(21, 10), (10, 10), (101, 10)]) {
        expect(
          () => s.correctTournamentResult(
            m.id,
            1,
            scores.$1,
            scores.$2,
            'Wrong score entry',
          ),
          throwsStateError,
        );
      }
      expect(
        () => s.correctTournamentResult(m.id, 1, 10, 21, 'no'),
        throwsStateError,
      );
      s.correctTournamentResult(m.id, 1, 10, 21, 'Wrong score orientation');
      expect(s.tournamentResults(a.eventId, a.start).first.wins, 0);
      expect(s.operationAudit.first.action, contains('21:10'));
      expect(s.operationAudit.first.action, contains('10:21'));
      expect(
        () => s.correctTournamentResult(m.id, 1, 21, 10, 'Stale correction'),
        throwsStateError,
      );
    },
  );
  test('Changes and long reasons persist after failed save retry', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final (a, b) = teams(s);
    final m = s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start,
      court: 1,
    );
    final reason = 'a' * 300;
    s.rescheduleTournamentMatch(
      m.id,
      0,
      a.start.add(const Duration(minutes: 30)),
      2,
      reason,
    );
    now = a.start.add(const Duration(hours: 1));
    s.login(DemoSession.phone, DemoSession.password);
    s.demoCheckIn(a);
    s.login('b@example.com', 'Player1234');
    s.demoCheckIn(b);
    owner(s);
    s.finishTournamentMatch(m.id, 1, 21, 10);
    admin(s);
    store.failWrite = true;
    s.correctTournamentResult(m.id, 2, 10, 21, reason);
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    final changed = r.tournamentMatches(a.eventId, a.start).single;
    expect(
      (changed.revision, changed.court, changed.firstScore, changed.note),
      (3, 2, 10, reason),
    );
    expect(
      r.operationAudit.where((e) => e.action.contains('Sửa kết quả')).length,
      1,
    );
  });
}
