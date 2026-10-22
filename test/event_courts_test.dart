import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 9, 10);
  final event = demoEvents.first, start = demoEvents.first.start(now);
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => now);
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  void assign(DemoSession s, List<int> courts, {List<String>? ids}) =>
      s.allocateEventCourts(
        event.id,
        start,
        courts,
        expectedBlockIds: ids ?? [],
      );
  test(
    'Event courts use real booking locks and release on whole cancellation',
    () {
      final s = open();
      owner(s);
      assign(s, [1, 2]);
      expect(s.available(1, start, 1), isFalse);
      expect(s.available(2, start.add(const Duration(hours: 1)), 1), isFalse);
      expect(s.available(3, start, 1), isTrue);
      expect(s.available(1, start.add(const Duration(hours: 2)), 1), isTrue);
      expect(
        () => s.unblockCourt(s.eventCourts(event.id, start).first),
        throwsStateError,
      );
      s.cancelEventOccurrence(event.id, start, 'Sân bảo trì');
      expect(s.eventCourts(event.id, start), isEmpty);
      expect(s.available(1, start, 1), isTrue);
    },
  );
  test(
    'Bookings and manual locks prevent partial allocation or ID consumption',
    () {
      final s = open();
      s.login(DemoSession.phone, DemoSession.password);
      s.reserve(
        court: 2,
        start: start,
        hours: 1,
        contact: 'Guest',
        contactPhone: DemoSession.phone,
      );
      owner(s);
      expect(() => assign(s, [1, 2]), throwsStateError);
      expect(s.eventCourts(event.id, start), isEmpty);
      assign(s, [1]);
      expect(s.eventCourts(event.id, start).single.id, 'KB0001');
    },
  );
  test('Revision guard prevents stale replacement and replacement releases old court', () {
    final s = open();
    owner(s);
    assign(s, [1]);
    expect(() => assign(s, [2]), throwsStateError);
    assign(s, [2], ids: ['KB0001']);
    expect(s.available(1, start, 1), isTrue);
    expect(s.available(2, start, 1), isFalse);
    assign(s, [], ids: ['KB0002']);
    expect(s.available(2, start, 1), isTrue);
  });
  test(
    'Player, unknown event, cancelled occurrence and duplicate courts rejected',
    () {
      final s = open();
      s.login(DemoSession.phone, DemoSession.password);
      expect(() => assign(s, [1]), throwsStateError);
      owner(s);
      expect(() => assign(s, [1, 1]), throwsStateError);
      expect(
        () =>
            s.allocateEventCourts('missing', start, [1], expectedBlockIds: []),
        throwsStateError,
      );
      s.cancelEventOccurrence(event.id, start, 'Sân bảo trì');
      expect(() => assign(s, [1]), throwsStateError);
    },
  );
  test(
    'Custom approved activity can allocate and cancellation releases locks',
    () {
      final s = open();
      owner(s);
      final a = s.saveActivity(
        title: 'Chơi cuối tuần',
        kind: DemoEventKind.social,
        start: start,
        durationMinutes: 120,
        capacity: 12,
        fee: 60000,
        description: 'Giao lưu cầu lông tại sân cuối tuần.',
      );
      expect(
        () => s.allocateEventCourts(a.id, start, [1], expectedBlockIds: []),
        throwsStateError,
      );
      s.transitionActivity(a.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionActivity(a.id, 'approved', 1);
      s.allocateEventCourts(a.id, start, [1], expectedBlockIds: []);
      expect(s.available(1, start, 1), isFalse);
      s.cancelActivity(a.id, 2, 'Sân bảo trì');
      expect(s.available(1, start, 1), isTrue);
    },
  );
  test(
    'Allocation constrains fixtures and cannot abandon a scheduled court',
    () {
      final s = open();
      final e = demoEvents.last, at = demoEvents.last.start(now);
      final tickets = <DemoParticipation>[];
      for (var i = 0; i < 2; i++) {
        if (i == 0) {
          s.login(DemoSession.phone, DemoSession.password);
        } else {
          s.register('Other Player', 'team@example.com', 'Test1234');
        }
        tickets.add(
          s.joinEvent(
            eventId: e.id,
            start: at,
            quantity: 1,
            contact: 'Player $i',
            contactPhone: DemoSession.phone,
            team: 'Team $i',
            partner: 'Partner $i',
          ),
        );
      }
      owner(s);
      s.allocateEventCourts(e.id, at, [1], expectedBlockIds: []);
      expect(
        () => s.scheduleTournamentMatch(
          first: tickets[0].id,
          second: tickets[1].id,
          start: at,
          court: 2,
        ),
        throwsStateError,
      );
      final m = s.scheduleTournamentMatch(
        first: tickets[0].id,
        second: tickets[1].id,
        start: at,
        court: 1,
      );
      expect(
        () => s.rescheduleTournamentMatch(m.id, 0, at, 2, 'Đổi sân đấu'),
        throwsStateError,
      );
      expect(
        () => s.allocateEventCourts(e.id, at, [], expectedBlockIds: ['KB0001']),
        throwsStateError,
      );
      s.cancelEventOccurrence(e.id, at, 'Sân bảo trì');
      expect(s.tournamentMatches(e.id, at).single.state, 'cancelled');
      expect(s.eventCourts(e.id, at), isEmpty);
    },
  );
  test(
    'Allocation persists and malformed event link fails atomic restore',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      assign(s, [1]);
      await s.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(restored.available(1, start, 1), isFalse);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      (data['courtBlocks'] as List).first['eventId'] = 'HD0999';
      final bad = open(TestSessionStore()..value = jsonEncode(data));
      await bad.initialize();
      expect(bad.loadFailed, isTrue);
      expect(bad.eventCourts(event.id, start), isEmpty);
    },
  );
}
