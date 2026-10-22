import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show sampleFacilityProof;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 9, 10));
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
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  DemoParticipation join(DemoSession s, [int index = 0]) {
    player(s);
    final e = demoEvents[index];
    return s.joinEvent(
      eventId: e.id,
      start: e.start(now),
      quantity: 1,
      contact: 'Test Player',
      contactPhone: DemoSession.phone,
      team: index == 2 ? 'Test Team' : '',
      partner: index == 2 ? 'Test Partner' : '',
    );
  }

  test('Whole occurrence cancels unpaid tickets and prevents registration', () {
    final s = open();
    final p = join(s);
    owner(s);
    s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
    expect(p.cancelled, isTrue);
    expect(s.workflowPayment(p.id)!.refund, DemoRefundState.none);
    expect(s.eventCancellation(p.eventId, p.start)!.reason, 'Sân bảo trì');
    expect(
      () => s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì'),
      throwsStateError,
    );
    player(s);
    expect(() => join(s), throwsStateError);
  });

  test('Paid ticket is pending full refund, not a completed cash transfer', () {
    final s = open();
    final p = join(s);
    s.startTicketTransfer(p);
    s.saveTicketProof(p, base64Decode(sampleFacilityProof));
    s.submitTicketProof(p, 'BANK-TEST');
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
    final payment = s.workflowPayment(p.id)!;
    expect(payment.cancellation, DemoCancellationState.accepted);
    expect(payment.refund, DemoRefundState.pending);
    expect(payment.refundAmount, p.total);
    expect(payment.refundRecordedAt, isNull);
  });

  test('Cancellation is limited to one date and event', () {
    final s = open();
    final p = join(s);
    final other = join(s, 1);
    owner(s);
    s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
    expect(other.cancelled, isFalse);
    now = now.add(const Duration(days: 1));
    final next = join(s);
    expect(next.start, isNot(p.start));
    expect(next.cancelled, isFalse);
  });

  test('Role, stale date and invalid reason reject without mutation', () {
    final s = open();
    final p = join(s);
    expect(
      () => s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì'),
      throwsStateError,
    );
    owner(s);
    expect(
      () => s.cancelEventOccurrence(p.eventId, p.start, 'No'),
      throwsStateError,
    );
    now = now.add(const Duration(days: 1));
    expect(
      () => s.cancelEventOccurrence(
        p.eventId,
        p.start.add(const Duration(days: 3)),
        'Sân bảo trì',
      ),
      throwsStateError,
    );
    expect(p.cancelled, isFalse);
    expect(s.eventCancellation(p.eventId, p.start), isNull);
  });

  test(
    'Cancellation survives reload and legacy absent ledger remains valid',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final p = join(s);
      owner(s);
      s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
      expect(await s.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      expect(restored.eventCancellation(p.eventId, p.start), isNotNull);
      expect(restored.managedParticipations.single.cancelled, isTrue);
      final legacy = jsonDecode(store.value!) as Map<String, dynamic>;
      legacy.remove('eventCancellations');
      final oldStore = TestSessionStore()..value = jsonEncode(legacy);
      final old = open(oldStore);
      await old.initialize();
      expect(old.loadFailed, isFalse);
    },
  );

  test(
    'Known ticket occurrence stays manageable after catalog rolls forward',
    () {
      final s = open();
      final p = join(s);
      now = now.add(const Duration(days: 1));
      owner(s);
      expect(s.eventOccurrenceExists(p.eventId, p.start), isTrue);
      s.allocateEventCourts(p.eventId, p.start, [2], expectedBlockIds: []);
      expect(s.available(2, p.start, 1), isFalse);
      s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
      expect(p.cancelled, isTrue);
      expect(s.eventCourts(p.eventId, p.start), isEmpty);
      final next = join(s);
      expect(next.start, isNot(p.start));
    },
  );

  test('Malformed cancellation records are rejected', () {
    final c = DemoEventCancellation(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(now),
      created: now,
      actor: '__owner__',
      reason: 'Sân bảo trì',
    );
    expect(DemoEventCancellation.fromJson(c.toJson()).key, c.key);
    expect(
      () => DemoEventCancellation.fromJson({...c.toJson(), 'actor': 'player'}),
      throwsFormatException,
    );
    expect(
      () => DemoEventCancellation.fromJson({
        ...c.toJson(),
        'start': now.toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test(
    'Duplicate ledger and active ticket conflict fail atomic restore',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final p = join(s);
      owner(s);
      s.cancelEventOccurrence(p.eventId, p.start, 'Sân bảo trì');
      await s.flush();
      for (final duplicate in [true, false]) {
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        if (duplicate) {
          final entries = data['eventCancellations'] as List;
          entries.add(entries.first);
        } else {
          (data['participations'] as List).first['cancelled'] = false;
        }
        final bad = open(TestSessionStore()..value = jsonEncode(data));
        await bad.initialize();
        expect(bad.loadFailed, isTrue);
        expect(bad.eventCancellation(p.eventId, p.start), isNull);
      }
    },
  );
}
