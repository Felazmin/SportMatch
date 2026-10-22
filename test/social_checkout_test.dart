import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 10, 10));
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
  DemoParticipation buy(
    DemoSession s, {
    int quantity = 1,
    bool checkout = true,
  }) => s.joinEvent(
    eventId: demoEvents.first.id,
    start: demoEvents.first.start(now),
    quantity: quantity,
    contact: 'Minh Phát',
    contactPhone: DemoSession.phone,
    socialCheckout: checkout,
    note: checkout ? 'Đi cùng bạn' : '',
  );
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  test('Checkout holds two tickets atomically, applies offer, stores note', () {
    final s = open();
    buyer(s);
    final t = buy(s, quantity: 2);
    expect(t.total, demoEvents.first.fee * 2 * 9 ~/ 10);
    expect(t.discount, demoEvents.first.fee ~/ 5);
    expect(t.note, 'Đi cùng bạn');
    expect(
      s.workflowPayment(t.id)!.deadline,
      now.add(const Duration(minutes: 15)),
    );
    expect(s.eventSeats(t.eventId, t.start), t.event.capacity - 2);
    expect(() => buy(s), throwsStateError);
    expect(() => s.cancelParticipation(t), returnsNormally);
    expect(t.cancelled, isFalse);
  });
  test(
    'At exact deadline releases seats once, cannot revive, can buy fresh',
    () {
      final s = open();
      buyer(s);
      final t = buy(s, quantity: 2);
      now = now.add(const Duration(minutes: 15));
      expect(s.eventSeats(t.eventId, t.start), t.event.capacity);
      expect(s.expireSocialTickets(), 1);
      expect(t.cancelled, isTrue);
      expect(s.expireSocialTickets(), 0);
      expect(() => s.startTicketTransfer(t), throwsStateError);
      expect(() => s.saveTicketProof(t, proof), throwsStateError);
      expect(s.workflowPayment(t.id)!.refund, DemoRefundState.none);
      final next = buy(s);
      expect(next.id, isNot(t.id));
      expect(next.cancelled, isFalse);
    },
  );
  test(
    'Draft is not submission; submitted proof remains held after deadline',
    () {
      final s = open();
      buyer(s);
      final t = buy(s);
      s.saveTicketProof(t, proof);
      now = now.add(const Duration(minutes: 14, seconds: 59));
      expect(s.expireSocialTickets(), 0);
      s.submitTicketProof(t, t.id);
      now = now.add(const Duration(minutes: 2));
      expect(s.expireSocialTickets(), 0);
      expect(t.cancelled, isFalse);
      expect(s.workflowPayment(t.id)!.state, DemoPaymentState.pending);
      expect(s.eventSeats(t.eventId, t.start), t.event.capacity - 1);
    },
  );
  test('Uploaded draft alone expires, even while logged out', () {
    final s = open();
    buyer(s);
    final t = buy(s);
    s.saveTicketProof(t, proof);
    s.logout();
    now = now.add(const Duration(minutes: 15));
    expect(s.expireSocialTickets(), 1);
    expect(t.cancelled, isTrue);
  });
  test(
    'Legacy social transfers retain 30-minute restart behavior and price',
    () {
      final s = open();
      buyer(s);
      final t = buy(s, quantity: 2, checkout: false);
      expect(t.total, t.event.fee * 2);
      final p = s.startTicketTransfer(t);
      expect(p.deadline, now.add(const Duration(minutes: 30)));
      now = p.deadline;
      expect(s.expireSocialTickets(), 0);
      expect(s.startTicketTransfer(t), isNot(same(p)));
      expect(t.cancelled, isFalse);
    },
  );
  test('Request cancellation holds seats until organizer approval', () {
    final s = open();
    buyer(s);
    final t = buy(s);
    s.saveTicketProof(t, proof);
    s.submitTicketProof(t, t.id);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.reviewTicketPayment(t, approve: true);
    buyer(s);
    now = t.start.subtract(const Duration(hours: 24));
    s.requestTicketCancellation(t, 'Không thể tham gia');
    expect(t.cancelled, isFalse);
    expect(s.eventSeats(t.eventId, t.start), t.event.capacity - 1);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.reviewTicketCancellation(t, approve: true);
    expect(t.cancelled, isTrue);
    expect(s.workflowPayment(t.id)!.refundAmount, t.total);
  });
  test(
    'Cancellation inside 24 hours is blocked; foreign account is denied',
    () {
      final s = open();
      buyer(s);
      final t = buy(s);
      s.saveTicketProof(t, proof);
      s.submitTicketProof(t, t.id);
      now = t.start.subtract(const Duration(hours: 23, minutes: 59));
      expect(
        () => s.requestTicketCancellation(t, 'Không thể tham gia'),
        throwsStateError,
      );
      s.register('Tấn Đạt', 'tandat@example.com', 'Test1234');
      expect(() => s.workflowPayment(t.id), throwsStateError);
      expect(() => s.submitTicketProof(t, t.id), throwsStateError);
    },
  );
  test('Restore expires unpaid checkout while retaining pending proof and legacy tickets', () async {
    final store = TestSessionStore();
    final first = open(store);
    await first.initialize();
    buyer(first);
    final unpaid = buy(first);
    await first.flush();
    first.logout();
    await first.flush();
    now = now.add(const Duration(minutes: 16));
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    buyer(restored);
    final t = restored.participations.singleWhere((t) => t.id == unpaid.id);
    expect(t.cancelled, isTrue);
    expect(
      restored.workflowPayment(t.id)!.cancellation,
      DemoCancellationState.accepted,
    );
    await restored.flush();
    final again = open(store);
    await again.initialize();
    expect(again.loadFailed, isFalse);
    expect(
      again.participations.singleWhere((t) => t.id == unpaid.id).cancelled,
      isTrue,
    );
  });
  test(
    'Ongoing social can sell until end; legacy and ended registration blocked',
    () {
      final s = open();
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final start = now.add(const Duration(hours: 1));
      final activity = s.saveActivity(
        title: 'Giao lưu sáng cuối tuần',
        kind: DemoEventKind.social,
        start: start,
        durationMinutes: 120,
        capacity: 8,
        fee: 60000,
        description: 'Ghép đôi giao lưu tại sân.',
      );
      s.transitionActivity(activity.id, 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionActivity(activity.id, 'approved', 1);
      buyer(s);
      now = start.subtract(const Duration(minutes: 5));
      final t = s.joinEvent(
        eventId: activity.id,
        start: start,
        quantity: 1,
        contact: 'Minh Phát',
        contactPhone: DemoSession.phone,
        socialCheckout: true,
      );
      expect(
        s.workflowPayment(t.id)!.deadline,
        now.add(const Duration(minutes: 15)),
      );
      now = start.add(const Duration(minutes: 20));
      s.expireSocialTickets();
      expect(t.cancelled, isTrue);
      expect(
        () => s.joinEvent(
          eventId: activity.id,
          start: start,
          quantity: 1,
          contact: 'Minh Phát',
          contactPhone: DemoSession.phone,
        ),
        throwsStateError,
      );
      final ongoing = s.joinEvent(
        eventId: activity.id,
        start: start,
        quantity: 1,
        contact: 'Minh Phát',
        contactPhone: DemoSession.phone,
        socialCheckout: true,
      );
      s.saveTicketProof(ongoing, proof);
      s.submitTicketProof(ongoing, ongoing.id);
      now = start.add(const Duration(hours: 2));
      s.register('Tấn Đạt', 'end@example.com', 'Test1234');
      expect(
        () => s.joinEvent(
          eventId: activity.id,
          start: start,
          quantity: 1,
          contact: 'Tấn Đạt',
          contactPhone: DemoSession.phone,
          socialCheckout: true,
        ),
        throwsStateError,
      );
    },
  );
  test('Cancellation request without submitted proof cannot bypass automatic expiry', () {
    final s = open();
    buyer(s);
    final t = buy(s);
    s.requestTicketCancellation(t, 'Không thể tham gia');
    now = now.add(const Duration(minutes: 15));
    expect(s.expireSocialTickets(), 1);
    expect(t.cancelled, isTrue);
    expect(s.eventSeats(t.eventId, t.start), t.event.capacity);
  });
  test('Submitted proof round trips and never auto-expires, including after rejection', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    buyer(s);
    final t = buy(s);
    s.saveTicketProof(t, proof);
    s.submitTicketProof(t, t.id);
    await s.flush();
    now = now.add(const Duration(minutes: 20));
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    final saved = restored.participations.singleWhere((p) => p.id == t.id);
    expect(saved.cancelled, isFalse);
    expect(restored.workflowPayment(t.id)!.state, DemoPaymentState.pending);
    restored.loginStaff(
      DemoRole.owner,
      DemoSession.ownerEmail,
      DemoSession.password,
    );
    restored.reviewTicketPayment(saved, approve: false, note: 'Cần ảnh rõ hơn');
    expect(restored.expireSocialTickets(), 0);
    expect(saved.cancelled, isFalse);
    buyer(restored);
    final retry = restored.startTicketTransfer(saved);
    expect(retry.deadline, now.add(const Duration(minutes: 15)));
    expect(retry.proof, isNotEmpty);
    restored.saveTicketProof(saved, proof);
    restored.submitTicketProof(saved, saved.id);
    expect(restored.workflowPayment(saved.id)!.state, DemoPaymentState.pending);
  });
  test('Old JSON defaults to legacy; invalid quantity and tournament checkout rejected', () {
    final s = open();
    buyer(s);
    final t = buy(s, checkout: false);
    final json = t.toJson()
      ..remove('socialCheckout')
      ..remove('note');
    expect(DemoParticipation.fromJson(json).socialCheckout, isFalse);
    final other = open();
    buyer(other);
    expect(() => buy(other, quantity: 3), throwsStateError);
    final e = demoEvents.last;
    expect(
      () => other.joinEvent(
        eventId: e.id,
        start: e.start(now),
        quantity: 1,
        contact: 'Minh Phát',
        contactPhone: DemoSession.phone,
        team: 'Đội A',
        partner: 'Tấn Đạt',
        socialCheckout: true,
      ),
      throwsStateError,
    );
  });
}
