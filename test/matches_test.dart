import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  final start = DateTime(2026, 10, 9, 18);
  setUp(() => now = DateTime(2026, 10, 7, 10));
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void manager(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  List<DemoParticipation> teams(DemoSession s) {
    manager(s);
    final a = s.saveActivity(
      title: 'Giải cuối tuần',
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
    final result = <DemoParticipation>[];
    for (var i = 0; i < 4; i++) {
      if (i == 0) {
        s.login(DemoSession.phone, DemoSession.password);
      } else {
        s.register('Player $i', 'player$i@example.com', 'Player1234');
      }
      result.add(
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
    manager(s);
    return result;
  }

  test('Only managers schedule; players need own tournament ticket', () {
    final s = open();
    final p = teams(s);
    s.login(DemoSession.phone, DemoSession.password);
    expect(
      () => s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      ),
      throwsStateError,
    );
    expect(s.tournamentMatches('HD0001', start), isEmpty);
    s.register('Outsider', 'out@example.com', 'Player1234');
    expect(() => s.tournamentMatches('HD0001', start), throwsStateError);
    expect(() => s.tournamentTeam(p[0].id), throwsStateError);
    manager(s);
    final m = s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    expect(m.id, 'TD0001');
    expect(
      () => s.tournamentMatches('HD0001', start).clear(),
      throwsUnsupportedError,
    );
  });
  test(
    'Reject identical teams, invalid slots/courts, overflow and expired times',
    () {
      final s = open();
      final p = teams(s);
      for (final t in [
        start.subtract(const Duration(minutes: 30)),
        start.add(const Duration(minutes: 1)),
        start.add(const Duration(hours: 2)),
      ]) {
        expect(
          () => s.scheduleTournamentMatch(
            first: p[0].id,
            second: p[1].id,
            start: t,
            court: 1,
          ),
          throwsStateError,
        );
      }
      expect(
        () => s.scheduleTournamentMatch(
          first: p[0].id,
          second: p[0].id,
          start: start,
          court: 1,
        ),
        throwsStateError,
      );
      expect(
        () => s.scheduleTournamentMatch(
          first: p[0].id,
          second: p[1].id,
          start: start,
          court: 4,
        ),
        throwsStateError,
      );
      now = start;
      expect(
        () => s.scheduleTournamentMatch(
          first: p[0].id,
          second: p[1].id,
          start: start,
          court: 1,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Court/team overlaps rejected; adjacent slots and different courts allowed',
    () {
      final s = open();
      final p = teams(s);
      s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      expect(
        () => s.scheduleTournamentMatch(
          first: p[2].id,
          second: p[3].id,
          start: start,
          court: 1,
        ),
        throwsStateError,
      );
      expect(
        () => s.scheduleTournamentMatch(
          first: p[0].id,
          second: p[2].id,
          start: start,
          court: 2,
        ),
        throwsStateError,
      );
      s.scheduleTournamentMatch(
        first: p[2].id,
        second: p[3].id,
        start: start,
        court: 2,
      );
      expect(
        s
            .scheduleTournamentMatch(
              first: p[0].id,
              second: p[2].id,
              start: start.add(const Duration(minutes: 30)),
              court: 1,
            )
            .id,
        'TD0003',
      );
    },
  );
  test(
    'Cancelled fixture frees slot, keeps reason/tickets and stale guards',
    () {
      final s = open();
      final p = teams(s);
      final m = s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      expect(() => s.cancelTournamentMatch(m.id, 0, 'no'), throwsStateError);
      s.cancelTournamentMatch(m.id, 0, 'Adjust match schedule');
      expect(
        () => s.cancelTournamentMatch(m.id, 0, 'Adjust again'),
        throwsStateError,
      );
      expect(p.every((p) => !p.cancelled), isTrue);
      s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      expect(s.tournamentMatches('HD0001', start).length, 2);
    },
  );
  test(
    'Results require end time and both check-ins; scores validated and locked',
    () {
      final s = open();
      final p = teams(s);
      final m = s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      expect(() => s.finishTournamentMatch(m.id, 0, 21, 10), throwsStateError);
      now = start.add(const Duration(minutes: 30));
      expect(() => s.finishTournamentMatch(m.id, 0, 21, 10), throwsStateError);
      s.login(DemoSession.phone, DemoSession.password);
      expect(s.demoCheckIn(p[0]), isTrue);
      s.login('player1@example.com', 'Player1234');
      expect(s.demoCheckIn(p[1]), isTrue);
      manager(s);
      for (final scores in [(21, 21), (-1, 10), (100, 10)]) {
        expect(
          () => s.finishTournamentMatch(m.id, 0, scores.$1, scores.$2),
          throwsStateError,
        );
      }
      s.finishTournamentMatch(m.id, 0, 21, 10);
      expect(s.tournamentMatches('HD0001', start).single.firstScore, 21);
      expect(() => s.finishTournamentMatch(m.id, 1, 10, 21), throwsStateError);
      expect(
        () => s.cancelTournamentMatch(m.id, 1, 'Changing result'),
        throwsStateError,
      );
    },
  );
  test('Cancelled team cannot be scheduled/scored but old fixture remains readable', () {
    final s = open();
    final p = teams(s);
    final m = s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.cancelParticipation(p[0]), isTrue);
    manager(s);
    expect(s.tournamentTeam(p[0].id), contains('đã hủy vé'));
    expect(
      () => s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[2].id,
        start: start.add(const Duration(minutes: 30)),
        court: 2,
      ),
      throwsStateError,
    );
    now = start.add(const Duration(minutes: 30));
    expect(() => s.finishTournamentMatch(m.id, 0, 21, 10), throwsStateError);
  });
  test('Save failure retry/restart and old snapshots remain valid', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final p = teams(s);
    store.failWrite = true;
    s.scheduleTournamentMatch(
      first: p[0].id,
      second: p[1].id,
      start: start,
      court: 1,
    );
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    expect(r.tournamentMatches('HD0001', start).single.id, 'TD0001');
    final j = jsonDecode(store.value!) as Map<String, dynamic>;
    j.remove('matches');
    j.remove('nextMatch');
    store.value = jsonEncode(j);
    final legacy = open(store);
    await legacy.initialize();
    expect(legacy.loadFailed, isFalse);
    expect(legacy.tournamentMatches('HD0001', start), isEmpty);
  });
  test('Matches cannot cross tournament dates or social registrations', () {
    final s = open();
    final p = teams(s);
    s.register('Social player', 'social@example.com', 'Player1234');
    final social = demoEvents.firstWhere((e) => e.kind == DemoEventKind.social);
    final q = s.joinEvent(
      eventId: social.id,
      start: social.start(now),
      quantity: 1,
      contact: 'Social player',
      contactPhone: DemoSession.phone,
    );
    manager(s);
    expect(
      () => s.scheduleTournamentMatch(
        first: p[0].id,
        second: q.id,
        start: start,
        court: 1,
      ),
      throwsStateError,
    );
    expect(
      () => s.scheduleTournamentMatch(
        first: q.id,
        second: p[0].id,
        start: start,
        court: 1,
      ),
      throwsStateError,
    );
  });
  for (final corrupt in [false, true]) {
    test(
      'Completed results persist; invalid attendance rejected: $corrupt',
      () async {
        final store = TestSessionStore();
        final s = open(store);
        await s.initialize();
        final p = teams(s);
        final m = s.scheduleTournamentMatch(
          first: p[0].id,
          second: p[1].id,
          start: start,
          court: 1,
        );
        now = start.add(const Duration(minutes: 30));
        s.login(DemoSession.phone, DemoSession.password);
        s.demoCheckIn(p[0]);
        s.login('player1@example.com', 'Player1234');
        s.demoCheckIn(p[1]);
        manager(s);
        s.finishTournamentMatch(m.id, 0, 21, 15);
        await s.flush();
        if (corrupt) {
          final j = jsonDecode(store.value!) as Map<String, dynamic>;
          final ticket =
              (j['participations'] as List).first as Map<String, dynamic>;
          ticket['attendance'] = 'pending';
          ticket['checkedIn'] = false;
          store.value = jsonEncode(j);
        }
        final r = open(store);
        await r.initialize();
        expect(r.loadFailed, corrupt);
        if (!corrupt) {
          r.login(DemoSession.phone, DemoSession.password);
          expect(r.tournamentMatches('HD0001', start).single.secondScore, 15);
        } else {
          expect(r.user, isNull);
        }
      },
    );
  }
  for (final bad in [
    'link',
    'counter',
    'duplicate',
    'score',
    'time',
    'overlap',
  ]) {
    test('Corrupt $bad match restores atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final p = teams(s);
      s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      final matches = j['matches'] as List;
      final m = matches.single as Map<String, dynamic>;
      switch (bad) {
        case 'link':
          m['second'] = 'VE9999';
        case 'counter':
          j['nextMatch'] = 1;
        case 'duplicate':
          matches.add({...m});
        case 'score':
          m['firstScore'] = 21;
        case 'time':
          m['start'] = start
              .subtract(const Duration(hours: 1))
              .toIso8601String();
        case 'overlap':
          matches.add({...m, 'id': 'TD0002'});
          j['nextMatch'] = 3;
      }
      store.value = jsonEncode(j);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
    });
  }
}
