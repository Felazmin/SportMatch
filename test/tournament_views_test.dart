import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  final start = DateTime(2026, 10, 9, 18);
  setUp(() => now = DateTime(2026, 10, 7, 10));
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  List<DemoParticipation> teams(DemoSession s) {
    owner(s);
    final a = s.saveActivity(
      title: 'Giải giao lưu',
      kind: DemoEventKind.tournament,
      start: start,
      durationMinutes: 120,
      capacity: 8,
      fee: 65000,
      description: 'Giải giao lưu cầu lông đôi cuối tuần.',
    );
    s.transitionActivity(a.id, 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.transitionActivity(a.id, 'approved', 1);
    final p = <DemoParticipation>[];
    for (var i = 0; i < 4; i++) {
      if (i == 0) {
        s.login(DemoSession.phone, DemoSession.password);
      } else {
        s.register('Player $i', 'player$i@example.com', 'Player1234');
      }
      p.add(
        s.joinEvent(
          eventId: a.id,
          start: start,
          quantity: 1,
          contact: 'Player $i',
          contactPhone: DemoSession.phone,
          team: 'Team $i',
          partner: 'Partner $i',
        ),
      );
    }
    owner(s);
    return p;
  }

  void results(DemoSession s, List<DemoParticipation> p) {
    final a = s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    final b = s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[2].id,
      start: start.add(const Duration(minutes: 30)),
      court: 1,
    );
    final c = s.scheduleTournamentMatch(
      first: p[2].id,
      second: p[3].id,
      start: start,
      court: 2,
    );
    final d = s.scheduleTournamentMatch(
      first: p[1].id,
      second: p[3].id,
      start: start.add(const Duration(hours: 1)),
      court: 1,
    );
    s.cancelTournamentMatch(d.id, 0, 'Adjust schedule');
    now = start.add(const Duration(hours: 1));
    for (var i = 0; i < p.length; i++) {
      s.login(
        i == 0 ? DemoSession.phone : 'player$i@example.com',
        i == 0 ? DemoSession.password : 'Player1234',
      );
      expect(s.demoCheckIn(p[i]), isTrue);
    }
    owner(s);
    s.finishTournamentMatch(a.id, 0, 21, 10);
    s.finishTournamentMatch(b.id, 0, 12, 21);
    s.finishTournamentMatch(c.id, 0, 21, 9);
  }

  test(
    'Results aggregate both score orientations and exclude cancelled matches',
    () {
      final s = open();
      final p = teams(s);
      results(s, p);
      final r = s.tournamentResults('HD0001', start);
      expect(r.map((r) => r.ticketId), p.map((p) => p.id));
      expect(
        (
          r[0].played,
          r[0].wins,
          r[0].losses,
          r[0].scored,
          r[0].conceded,
          r[0].difference,
        ),
        (2, 1, 1, 33, 31, 2),
      );
      expect(
        (r[2].played, r[2].wins, r[2].losses, r[2].scored, r[2].conceded),
        (2, 2, 0, 42, 21),
      );
      expect(r.fold<int>(0, (sum, r) => sum + r.played), 6);
      expect(r.fold<int>(0, (sum, r) => sum + r.difference), 0);
      expect(() => r.clear(), throwsUnsupportedError);
    },
  );
  test('Pending matches and cancelled tickets retain zero result rows', () {
    final s = open();
    final p = teams(s);
    s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    s.login(DemoSession.phone, DemoSession.password);
    s.cancelParticipation(p[0]);
    final r = s.tournamentResults('HD0001', start);
    expect(r.length, 4);
    expect(r.first.cancelled, isTrue);
    expect(
      r.every((r) => r.played == 0 && r.scored == 0 && r.wins == 0),
      isTrue,
    );
  });
  test(
    'Own fixtures preserve cancelled history; outsiders and wrong date denied',
    () {
      final s = open();
      final p = teams(s);
      results(s, p);
      expect(() => s.ownTournamentMatches('HD0001', start), throwsStateError);
      s.login(DemoSession.phone, DemoSession.password);
      expect(s.ownTournamentMatches('HD0001', start).map((m) => m.id), [
        'TD0001',
        'TD0002',
      ]);
      expect(
        () => s.ownTournamentMatches('HD0001', start).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => s.tournamentResults('HD0001', start.add(const Duration(days: 1))),
        throwsStateError,
      );
      s.login('player1@example.com', 'Player1234');
      expect(s.ownTournamentMatches('HD0001', start).last.state, 'cancelled');
      s.register('Outsider', 'out@example.com', 'Player1234');
      expect(() => s.tournamentResults('HD0001', start), throwsStateError);
      expect(() => s.managedTournaments, throwsStateError);
      s.logout();
      expect(() => s.tournamentResults('HD0001', start), throwsStateError);
    },
  );
  test('Directory includes current seeded/custom and immutable historical dates once', () {
    final s = open();
    final p = teams(s);
    final e = demoEvents.firstWhere((e) => e.kind == DemoEventKind.tournament);
    final seedStart = e.start(now);
    s.login(DemoSession.phone, DemoSession.password);
    s.joinEvent(
      eventId: e.id,
      start: seedStart,
      quantity: 1,
      contact: 'Minh Phat',
      contactPhone: DemoSession.phone,
      team: 'Seed Team',
      partner: 'Minh Anh',
    );
    owner(s);
    expect(s.managedTournaments.length, 2);
    s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    final custom = s.managedTournaments.singleWhere(
      (e) => e.event.id == 'HD0001',
    );
    expect((custom.teams, custom.matches, custom.completed), (4, 1, 0));
    now = now.add(const Duration(days: 1));
    final all = s.managedTournaments;
    expect(all.where((t) => t.event.id == e.id).map((t) => t.start), [
      seedStart,
      e.start(now),
    ]);
    expect(all.where((t) => t.event.id == 'HD0001').length, 1);
    expect(() => all.clear(), throwsUnsupportedError);
  });
  test(
    'Draft/social excluded; suspended/expired approved tournaments retained',
    () {
      final s = open();
      teams(s);
      s.saveActivity(
        title: 'Giải nháp',
        kind: DemoEventKind.tournament,
        start: start.add(const Duration(days: 1)),
        durationMinutes: 120,
        capacity: 8,
        fee: 65000,
        description: 'Giải chưa được duyệt công khai.',
      );
      s.saveActivity(
        title: 'Giao lưu',
        kind: DemoEventKind.social,
        start: start,
        durationMinutes: 120,
        capacity: 8,
        fee: 65000,
        description: 'Buổi giao lưu không phải giải đấu.',
      );
      expect(s.managedTournaments.length, 2);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionActivity(
        'HD0001',
        'suspended',
        2,
        note: 'Pause registration',
      );
      now = start.add(const Duration(days: 3));
      expect(s.managedTournaments.any((e) => e.event.id == 'HD0001'), isTrue);
      expect(s.availableEvents.any((e) => e.id == 'HD0001'), isFalse);
    },
  );
  test(
    'Derived results and directory survive restart without a second schema',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final p = teams(s);
      results(s, p);
      await s.flush();
      final before = s.tournamentResults('HD0001', start);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      final after = r.tournamentResults('HD0001', start);
      expect(
        after.map((r) => (r.ticketId, r.wins, r.scored, r.conceded)),
        before.map((r) => (r.ticketId, r.wins, r.scored, r.conceded)),
      );
      final entry = r.managedTournaments.singleWhere(
        (e) => e.event.id == 'HD0001',
      );
      expect((entry.teams, entry.matches, entry.completed), (4, 3, 3));
    },
  );
}
