import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 7, 10);
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  void staff(DemoSession s, DemoRole role) => s.loginStaff(
    role,
    role == DemoRole.admin ? DemoSession.adminEmail : DemoSession.ownerEmail,
    DemoSession.password,
  );
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  DemoDispute fixture(DemoSession s, {bool paid = false}) {
    s.login(DemoSession.phone, DemoSession.password);
    final ticket = s.joinEvent(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(now),
      quantity: 1,
      contact: 'Test User',
      contactPhone: DemoSession.phone,
    );
    if (paid) {
      s.startTicketTransfer(ticket);
      s.saveTicketProof(ticket, proof);
      s.submitTicketProof(ticket, 'TEST-PAYMENT');
      staff(s, DemoRole.owner);
      s.reviewTicketPayment(ticket, approve: true);
      s.login(DemoSession.phone, DemoSession.password);
    }
    return s.createTicketDispute(
      ticket,
      'Refund review',
      'Please review this booking',
    );
  }

  test('Only Admin closes a decided case exactly once', () {
    final s = open();
    final d = fixture(s);
    expect(s.disputeReadyToClose(d), isFalse);
    expect(() => s.closeDispute(d), throwsStateError);
    staff(s, DemoRole.admin);
    expect(() => s.closeDispute(d), throwsStateError);
    s.decideDispute(d, DemoDisputeDecision.uphold, 'Keep original result');
    staff(s, DemoRole.owner);
    expect(() => s.closeDispute(d), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.closeDispute(d), throwsStateError);
    staff(s, DemoRole.admin);
    s.closeDispute(d);
    expect(d.closedAt, now);
    expect(d.label, contains('Đã đóng'));
    expect(s.disputeReadyToClose(d), isFalse);
    expect(() => s.closeDispute(d), throwsStateError);
    expect(
      () => s.decideDispute(d, DemoDisputeDecision.refund, 'Another decision'),
      throwsStateError,
    );
  });

  test('Refund closure requires a linked recorded receipt', () {
    final s = open();
    final d = fixture(s, paid: true);
    staff(s, DemoRole.admin);
    s.decideDispute(d, DemoDisputeDecision.refund, 'Approve demo refund');
    expect(() => s.closeDispute(d), throwsStateError);
    staff(s, DemoRole.owner);
    s.recordWorkflowRefund(d.bookingId, 'REF-TEST', proof);
    staff(s, DemoRole.admin);
    s.closeDispute(d);
    expect(s.workflowPayment(d.bookingId)!.refund, DemoRefundState.recorded);
    expect(d.closedAt, now);
    expect(s.workflowPayment(d.bookingId)!.refundReference, 'REF-TEST');
  });

  test('Foreign player cannot inspect readiness or close a case', () {
    final s = open();
    final d = fixture(s);
    s.register('Other', 'other@example.com', 'Test1234');
    expect(() => s.disputeReadyToClose(d), throwsStateError);
    expect(() => s.closeDispute(d), throwsStateError);
  });

  test(
    'Closure persists; old records remain open rather than auto-close',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final d = fixture(s);
      staff(s, DemoRole.admin);
      s.decideDispute(d, DemoDisputeDecision.uphold, 'Keep original result');
      s.closeDispute(d);
      expect(await s.flush(), isTrue);
      final restored = open(store);
      await restored.initialize();
      expect(restored.disputes.single.closedAt, now);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      (data['disputes'] as List).single.remove('closedAt');
      store.value = jsonEncode(data);
      final legacy = open(store);
      await legacy.initialize();
      expect(legacy.disputes.single.closedAt, isNull);
      expect(legacy.disputeReadyToClose(legacy.disputes.single), isTrue);
    },
  );

  test('Save retry does not repeat closure', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final d = fixture(s);
    staff(s, DemoRole.admin);
    s.decideDispute(d, DemoDisputeDecision.uphold, 'Keep original result');
    await s.flush();
    store.failWrite = true;
    s.closeDispute(d);
    expect(await s.flush(), isFalse);
    expect(() => s.closeDispute(d), throwsStateError);
    store.failWrite = false;
    await s.retrySave();
    expect(s.saveFailed, isFalse);
    final r = open(store);
    await r.initialize();
    expect(r.disputes.single.closedAt, now);
    expect(
      r
          .workflowHistory(d.bookingId)
          .where((e) => e.action.startsWith('Đóng khiếu nại'))
          .length,
      1,
    );
  });

  test('Legacy untyped resolution cannot be marked executed', () {
    final s = open();
    final d = fixture(s);
    staff(s, DemoRole.admin);
    s.respondToDispute(d, 'Legacy original result', resolve: true);
    expect(s.disputeReadyToClose(d), isFalse);
    expect(() => s.closeDispute(d), throwsStateError);
  });

  for (final corrupt in ['missingDecision', 'beforeCreated', 'pendingRefund']) {
    test('Corrupt closure $corrupt is rejected atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final d = fixture(s, paid: true);
      staff(s, DemoRole.admin);
      s.decideDispute(d, DemoDisputeDecision.refund, 'Approve demo refund');
      s.recordWorkflowRefund(d.bookingId, 'REF-TEST', proof);
      s.closeDispute(d);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final raw = (data['disputes'] as List).single as Map<String, dynamic>;
      if (corrupt == 'missingDecision') raw['decision'] = null;
      if (corrupt == 'beforeCreated') {
        raw['closedAt'] = now
            .subtract(const Duration(days: 1))
            .toIso8601String();
      }
      if (corrupt == 'pendingRefund') {
        final payment =
            (data['payments'] as List).single as Map<String, dynamic>;
        payment['refund'] = 'pending';
        payment['refundRecordedAt'] = null;
        payment['refundReference'] = '';
        payment['refundProof'] = '';
      }
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
      expect(r.disputes, isEmpty);
    });
  }
}
