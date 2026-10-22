import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_activities.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  final start = DateTime(2026, 10, 9, 18);
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
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
  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  DemoActivity draft(
    DemoSession s, {
    DemoEventKind kind = DemoEventKind.social,
    int capacity = 12,
  }) => s.saveActivity(
    title: 'Giao lưu cuối tuần',
    kind: kind,
    start: start,
    durationMinutes: 120,
    capacity: capacity,
    fee: 65000,
    description: 'Chơi cầu lông và giao lưu thân thiện tại sân.',
  );
  DemoActivity publish(
    DemoSession s, {
    DemoEventKind kind = DemoEventKind.social,
    int capacity = 12,
  }) {
    owner(s);
    final a = draft(s, kind: kind, capacity: capacity);
    s.transitionActivity(a.id, 'pending', 0);
    admin(s);
    s.transitionActivity(a.id, 'approved', 1);
    return a;
  }

  DemoParticipation join(
    DemoSession s, {
    int quantity = 1,
    bool tournament = false,
  }) => s.joinEvent(
    eventId: 'HD0001',
    start: start,
    quantity: quantity,
    contact: 'Minh Phat',
    contactPhone: DemoSession.phone,
    team: tournament ? 'Weekend Team' : '',
    partner: tournament ? 'Minh Anh' : '',
  );
  test('Owner authors, Admin reviews, private drafts cannot be joined', () {
    final s = open();
    expect(() => draft(s), throwsStateError);
    player(s);
    expect(() => draft(s), throwsStateError);
    admin(s);
    expect(() => draft(s), throwsStateError);
    owner(s);
    final a = draft(s);
    expect(() => s.transitionActivity(a.id, 'approved', 0), throwsStateError);
    player(s);
    expect(() => join(s), throwsStateError);
    expect(() => s.managedActivities, throwsStateError);
    owner(s);
    s.transitionActivity(a.id, 'pending', 0);
    admin(s);
    s.transitionActivity(a.id, 'approved', 1);
    player(s);
    expect(join(s).total, 65000);
    expect(() => s.availableEvents.clear(), throwsUnsupportedError);
  });
  test('Invalid fields and duplicate schedules do not consume IDs', () {
    final s = open();
    owner(s);
    for (final time in [
      now,
      start.add(const Duration(days: 40)),
      start.add(const Duration(minutes: 1)),
    ]) {
      expect(
        () => s.saveActivity(
          title: 'A valid title',
          kind: DemoEventKind.social,
          start: time,
          durationMinutes: 120,
          capacity: 12,
          fee: 65000,
          description: 'A valid description',
        ),
        throwsStateError,
      );
    }
    for (final fee in [0, 1000001, 65501]) {
      expect(
        () => s.saveActivity(
          title: 'A valid title',
          kind: DemoEventKind.social,
          start: start,
          durationMinutes: 120,
          capacity: 12,
          fee: fee,
          description: 'A valid description',
        ),
        throwsStateError,
      );
    }
    expect(() => draft(s, capacity: 65), throwsStateError);
    final a = draft(s);
    expect(a.id, 'HD0001');
    expect(() => draft(s), throwsStateError);
  });
  test('Rejection/edit/resubmission keeps ID and rejects stale forms', () {
    final s = open();
    owner(s);
    final a = draft(s);
    s.transitionActivity(a.id, 'pending', 0);
    admin(s);
    expect(
      () => s.transitionActivity(a.id, 'rejected', 1, note: 'no'),
      throwsStateError,
    );
    s.transitionActivity(
      a.id,
      'rejected',
      1,
      note: 'Please update playing rules',
    );
    owner(s);
    final edit = s.saveActivity(
      id: a.id,
      expectedRevision: 2,
      title: a.event.title,
      kind: a.event.kind,
      start: start,
      durationMinutes: 120,
      capacity: 16,
      fee: 70000,
      description: 'Updated playing rules and schedule',
    );
    expect(edit.id, a.id);
    expect(edit.note, '');
    expect(() => s.transitionActivity(a.id, 'pending', 2), throwsStateError);
    s.transitionActivity(a.id, 'pending', 3);
    admin(s);
    s.transitionActivity(a.id, 'approved', 4);
    expect(s.availableEvents.last.fee, 70000);
    owner(s);
    expect(
      () => s.saveActivity(
        id: a.id,
        expectedRevision: 5,
        title: a.event.title,
        kind: a.event.kind,
        start: start,
        durationMinutes: 120,
        capacity: 12,
        fee: 65000,
        description: a.event.description,
      ),
      throwsStateError,
    );
  });
  test('Capacity and duplicate account registration stay enforced', () {
    final s = open();
    publish(s, capacity: 2);
    player(s);
    join(s, quantity: 2);
    expect(s.eventSeats('HD0001', start), 0);
    expect(() => join(s), throwsStateError);
    s.register('Other player', 'other@example.com', 'Other1234');
    expect(() => join(s), throwsStateError);
  });
  test('Tournament definitions require a team and partner, count teams', () {
    final s = open();
    publish(s, kind: DemoEventKind.tournament, capacity: 4);
    player(s);
    expect(() => join(s), throwsStateError);
    final p = join(s, tournament: true);
    expect(p.team, 'Weekend Team');
    expect(p.total, 65000);
    expect(s.eventSeats('HD0001', start), 3);
  });
  test(
    'Suspension blocks new joins, preserves ticket terms and can reopen',
    () {
      final s = open();
      publish(s);
      player(s);
      final p = join(s);
      final payload = p.qrPayload;
      admin(s);
      s.transitionActivity(
        'HD0001',
        'suspended',
        2,
        note: 'Checking organizer schedule',
      );
      expect(s.availableEvents.any((e) => e.id == 'HD0001'), isFalse);
      s.register('Other player', 'other@example.com', 'Other1234');
      expect(() => join(s), throwsStateError);
      expect(p.cancelled, isFalse);
      expect(p.total, 65000);
      expect(p.qrPayload, payload);
      admin(s);
      s.transitionActivity('HD0001', 'approved', 3);
      expect(s.availableEvents.any((e) => e.id == 'HD0001'), isTrue);
    },
  );
  test('Started activities cannot be sent/approved/joined; expired hidden from catalog', () {
    final s = open();
    owner(s);
    final a = draft(s);
    s.transitionActivity(a.id, 'pending', 0);
    now = start;
    admin(s);
    expect(() => s.transitionActivity(a.id, 'approved', 1), throwsStateError);
    s.transitionActivity(
      a.id,
      'rejected',
      1,
      note: 'Scheduled start is already past',
    );
    final r = open();
    now = DateTime(2026, 10, 7, 10);
    publish(r);
    player(r);
    now = start;
    expect(() => join(r), throwsStateError);
    now = start.add(const Duration(hours: 2));
    expect(r.availableEvents.any((e) => e.id == 'HD0001'), isFalse);
  });
  test('Custom ticket payment/cancellation/refund survives suspended registry and restart', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    publish(s);
    player(s);
    final p = join(s);
    final proof = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    s.startTicketTransfer(p);
    s.saveTicketProof(p, proof);
    s.submitTicketProof(p, 'CUSTOM-PAYMENT');
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    player(s);
    s.requestTicketCancellation(p, 'Cannot play this weekend');
    owner(s);
    s.reviewTicketCancellation(p, approve: true);
    expect(s.workflowPayment(p.id)!.refundAmount, 65000);
    s.recordWorkflowRefund(p.id, 'CUSTOM-REFUND', proof);
    admin(s);
    s.transitionActivity(
      'HD0001',
      'suspended',
      2,
      note: 'Checking organizer details',
    );
    await s.flush();
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    expect(r.managedParticipations.single.total, 65000);
    expect(r.workflowPayment(p.id)!.refund, DemoRefundState.recorded);
    expect(r.workflowRecord(p.id).title, 'Giao lưu cuối tuần');
  });
  test(
    'Failed save retry and legacy migration do not duplicate registry',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      store.failWrite = true;
      draft(s);
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      final r = open(store);
      await r.initialize();
      expect(r.managedActivities.length, 1);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('activities');
      data.remove('nextActivity');
      store.value = jsonEncode(data);
      final legacy = open(store);
      await legacy.initialize();
      expect(legacy.loadFailed, isFalse);
      expect(legacy.availableEvents.length, 3);
    },
  );
  for (final bad in [
    'owner',
    'counter',
    'duplicate',
    'state',
    'ticket-fee',
    'ticket-link',
  ]) {
    test('Corrupt activity $bad fails atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      publish(s);
      player(s);
      join(s);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final list = data['activities'] as List;
      final a = list.single as Map<String, dynamic>;
      switch (bad) {
        case 'owner':
          a['owner'] = DemoSession.phone;
        case 'counter':
          data['nextActivity'] = 1;
        case 'duplicate':
          list.add({...a});
        case 'state':
          a['state'] = 'draft';
        case 'ticket-fee':
          (data['participations'] as List).single['eventSnapshot']['fee'] =
              70000;
        case 'ticket-link':
          data['activities'] = [];
      }
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
    });
  }
}
