import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show sampleFacilityProof;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
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
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  String event(DemoSession s, {bool tournament = false}) {
    owner(s);
    final a = s.saveActivity(
      title: 'Hoạt động cuối tuần',
      kind: tournament ? DemoEventKind.tournament : DemoEventKind.social,
      start: DateTime(2026, 10, 10, 18),
      durationMinutes: 120,
      capacity: 12,
      fee: 60000,
      description: 'Chơi cầu lông cuối tuần tại sân.',
    );
    s.transitionActivity(a.id, 'pending', 0);
    admin(s);
    s.transitionActivity(a.id, 'approved', 1);
    return a.id;
  }

  DemoParticipation join(DemoSession s, String id, {bool tournament = false}) =>
      s.joinEvent(
        eventId: id,
        start: DateTime(2026, 10, 10, 18),
        quantity: 1,
        contact: 'Người thử',
        contactPhone: DemoSession.phone,
        team: tournament ? 'Đội thử' : '',
        partner: tournament ? 'Bạn thử' : '',
      );
  void paid(DemoSession s, DemoParticipation p) {
    s.startTicketTransfer(p);
    s.saveTicketProof(p, base64Decode(sampleFacilityProof));
    s.submitTicketProof(p, 'REF-12345');
    owner(s);
    s.reviewTicketPayment(p, approve: true);
  }

  test('Paid and unpaid tickets cancel; full refund liability but no fake transfer', () {
    final s = open();
    final id = event(s);
    s.login(DemoSession.phone, DemoSession.password);
    final first = join(s, id);
    paid(s, first);
    s.register('Người khác', 'other@example.com', 'Demo1234');
    final second = join(s, id);
    expect(
      () => s.cancelActivity(id, 2, 'Không đủ người chơi'),
      throwsStateError,
    );
    owner(s);
    s.cancelActivity(id, 2, 'Không đủ người chơi');
    expect(first.cancelled, true);
    expect(second.cancelled, true);
    final p = s.workflowPayment(first.id)!;
    expect(p.refund, DemoRefundState.pending);
    expect(p.refundAmount, 60000);
    expect(p.refundReference, '');
    expect(p.refundRecordedAt, isNull);
    expect(s.workflowPayment(second.id)!.refund, DemoRefundState.none);
    expect(s.availableEvents.any((e) => e.id == id), false);
    expect(
      () => s.cancelActivity(id, 3, 'Không đủ người chơi'),
      throwsStateError,
    );
  });
  test('Tournament future fixtures cancel together with tickets', () {
    final s = open();
    final id = event(s, tournament: true);
    s.login(DemoSession.phone, DemoSession.password);
    final a = join(s, id, tournament: true);
    s.register('Đội khác', 'other@example.com', 'Demo1234');
    final b = join(s, id, tournament: true);
    owner(s);
    s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start,
      court: 1,
    );
    s.cancelActivity(id, 2, 'Không đủ đội tham dự');
    expect(s.tournamentMatches(id, a.start).single.state, 'cancelled');
    expect(s.tournamentMatches(id, a.start).single.revision, 1);
    expect(a.cancelled, true);
    expect(b.cancelled, true);
  });
  test(
    'Stale revision, short reason and started event fail without mutation',
    () {
      final s = open();
      final id = event(s);
      owner(s);
      expect(
        () => s.cancelActivity(id, 1, 'Không đủ người chơi'),
        throwsStateError,
      );
      expect(() => s.cancelActivity(id, 2, 'no'), throwsStateError);
      now = DateTime(2026, 10, 10, 18);
      expect(
        () => s.cancelActivity(id, 2, 'Không đủ người chơi'),
        throwsStateError,
      );
      expect(s.managedActivities.single.state, 'approved');
    },
  );
  test('Checked-in participant blocks whole event cancellation atomically', () {
    final s = open();
    final id = event(s);
    s.login(DemoSession.phone, DemoSession.password);
    final p = join(s, id);
    paid(s, p);
    now = DateTime(2026, 10, 10, 17, 50);
    s.setAttendance(p.id, DemoAttendance.checkedIn);
    expect(
      () => s.cancelActivity(id, 2, 'Thay đổi kế hoạch tổ chức'),
      throwsStateError,
    );
    expect(p.cancelled, false);
    expect(s.managedActivities.single.state, 'approved');
  });
  test(
    'Cancelled activity/refund/match history restore and failed save retries',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = event(s);
      s.login(DemoSession.phone, DemoSession.password);
      final p = join(s, id);
      paid(s, p);
      store.failWrite = true;
      s.cancelActivity(id, 2, 'Không đủ người chơi');
      expect(await s.flush(), false);
      store.failWrite = false;
      s.retrySave();
      expect(await s.flush(), true);
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, false);
      expect(next.managedActivities.single.state, 'cancelled');
      expect(next.workflowPayment(p.id)!.refundAmount, 60000);
      next.login(DemoSession.phone, DemoSession.password);
      expect(next.participations.single.cancelled, true);
    },
  );
  test('Cancelled registry with live ticket is rejected atomically', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final id = event(s);
    s.login(DemoSession.phone, DemoSession.password);
    join(s, id);
    owner(s);
    s.cancelActivity(id, 2, 'Không đủ người chơi');
    await s.flush();
    final j = jsonDecode(store.value!) as Map<String, dynamic>;
    j['participations'][0]['cancelled'] = false;
    store.value = jsonEncode(j);
    final next = open(store);
    await next.initialize();
    expect(next.loadFailed, true);
    expect(next.user, isNull);
  });
}
