import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  setUp(() => now = DateTime(2026, 10, 7, 10));
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
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
  DemoParticipation ticket(DemoSession s) => s.joinEvent(
    eventId: demoEvents.first.id,
    start: demoEvents.first.start(now),
    quantity: 1,
    contact: 'Test',
    contactPhone: DemoSession.phone,
  );
  void submit(DemoSession s, DemoParticipation p) {
    s.startTicketTransfer(p);
    s.saveTicketProof(p, proof);
    s.submitTicketProof(p, 'TEST-001');
  }

  void approve(DemoSession s, DemoParticipation p) {
    submit(s, p);
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    buyer(s);
  }

  test('Ticket proof reject, resend, confirm and foreign-user isolation', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    submit(s, p);
    expect(() => s.reviewTicketPayment(p, approve: true), throwsStateError);
    s.register('Other', 'other@example.com', 'Test1234');
    expect(() => s.workflowRecord(p.id), throwsStateError);
    expect(() => s.saveTicketProof(p, proof), throwsStateError);
    owner(s);
    s.reviewTicketPayment(p, approve: false, note: 'Wrong sample');
    buyer(s);
    expect(s.workflowPayment(p.id)!.state, DemoPaymentState.rejected);
    s.saveTicketProof(p, proof);
    s.submitTicketProof(p, 'TEST-002');
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    expect(s.workflowPayment(p.id)!.state, DemoPaymentState.approved);
    expect(() => s.reviewTicketPayment(p, approve: true), throwsStateError);
  });
  test('Expired proof attempt restarts without changing reservation', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    final first = s.startTicketTransfer(p);
    now = first.deadline;
    expect(() => s.saveTicketProof(p, proof), throwsStateError);
    final next = s.startTicketTransfer(p);
    expect(identical(first, next), isFalse);
    expect(s.participations.length, 1);
    expect(s.eventSeats(p.eventId, p.start), p.event.capacity - 1);
  });
  test(
    'Cancellation holds capacity until approved and refunds exactly once',
    () {
      final s = open();
      buyer(s);
      final p = ticket(s);
      approve(s, p);
      final seats = s.eventSeats(p.eventId, p.start);
      expect(s.cancelParticipation(p), isFalse);
      s.requestTicketCancellation(p, 'Cannot attend');
      expect(s.eventSeats(p.eventId, p.start), seats);
      owner(s);
      s.reviewTicketCancellation(p, approve: true);
      expect(s.eventSeats(p.eventId, p.start), seats + 1);
      expect(s.workflowPayment(p.id)!.refundAmount, p.total);
      expect(() => s.recordWorkflowRefund(p.id, 'x', proof), throwsStateError);
      s.recordWorkflowRefund(p.id, 'REF-001', proof);
      expect(s.workflowPayment(p.id)!.refund, DemoRefundState.recorded);
      expect(
        () => s.recordWorkflowRefund(p.id, 'REF-001', proof),
        throwsStateError,
      );
    },
  );
  test('Rejected cancellation retains seats; 24-hour boundary enforced', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    approve(s, p);
    s.requestTicketCancellation(p, 'Cannot attend');
    owner(s);
    s.reviewTicketCancellation(p, approve: false, note: 'Please keep slot');
    expect(p.cancelled, isFalse);
    buyer(s);
    now = p.start.subtract(const Duration(hours: 24));
    s.requestTicketCancellation(p, 'At boundary');
    owner(s);
    s.reviewTicketCancellation(p, approve: false, note: 'Please keep slot');
    buyer(s);
    now = now.add(const Duration(milliseconds: 1));
    expect(
      () => s.requestTicketCancellation(p, 'Too late now'),
      throwsStateError,
    );
  });
  test('QR validation, check-in window, completion and replay protection', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    approve(s, p);
    owner(s);
    expect(s.checkAttendanceCode(p.qrPayload).id, p.id);
    expect(
      () => s.checkAttendanceCode('${p.qrPayload}&bad=1'),
      throwsStateError,
    );
    expect(
      () => s.setAttendance(p.id, DemoAttendance.checkedIn),
      throwsStateError,
    );
    now = p.start.subtract(const Duration(minutes: 30));
    s.setAttendance(p.id, DemoAttendance.checkedIn);
    expect(
      () => s.setAttendance(p.id, DemoAttendance.checkedIn),
      throwsStateError,
    );
    expect(
      () => s.setAttendance(p.id, DemoAttendance.absent),
      throwsStateError,
    );
    expect(
      () => s.setAttendance(p.id, DemoAttendance.completed),
      throwsStateError,
    );
    now = p.event.end(p.start);
    s.setAttendance(p.id, DemoAttendance.completed);
    expect(p.checkedIn, isTrue);
    expect(p.state(now), 'Đã hoàn thành');
    expect(
      () => s.setAttendance(p.id, DemoAttendance.completed),
      throwsStateError,
    );
  });
  test('No-show cannot be recorded early or before payment confirmation', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    submit(s, p);
    owner(s);
    expect(
      () => s.setAttendance(p.id, DemoAttendance.absent),
      throwsStateError,
    );
    now = p.event.end(p.start);
    expect(
      () => s.setAttendance(p.id, DemoAttendance.absent),
      throwsStateError,
    );
    s.reviewTicketPayment(p, approve: true);
    s.setAttendance(p.id, DemoAttendance.absent);
    expect(p.state(now), 'Vắng mặt');
    expect(
      () => s.setAttendance(p.id, DemoAttendance.checkedIn),
      throwsStateError,
    );
  });
  test(
    'Pending cancellation blocks check-in and player cannot mark attendance',
    () {
      final s = open();
      buyer(s);
      final p = ticket(s);
      approve(s, p);
      s.requestTicketCancellation(p, 'Cannot attend');
      now = p.start;
      expect(s.demoCheckIn(p), isFalse);
      expect(
        () => s.setAttendance(p.id, DemoAttendance.checkedIn),
        throwsStateError,
      );
      owner(s);
      expect(
        () => s.setAttendance(p.id, DemoAttendance.checkedIn),
        throwsStateError,
      );
    },
  );
  test('Admin refund decision creates linked refund; owner cannot decide', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    approve(s, p);
    final d = s.createTicketDispute(
      p,
      'Refund dispute',
      'Please review the cancellation decision',
    );
    s.attachDisputeEvidence(d, proof);
    expect(
      () => s.createTicketDispute(
        p,
        'Duplicate',
        'Another dispute about the same ticket',
      ),
      throwsStateError,
    );
    owner(s);
    expect(
      () => s.decideDispute(
        d,
        DemoDisputeDecision.refund,
        'Approved the request',
      ),
      throwsStateError,
    );
    admin(s);
    s.decideDispute(d, DemoDisputeDecision.refund, 'Approved the request');
    expect(p.cancelled, isTrue);
    expect(s.workflowPayment(p.id)!.refundAmount, p.total);
    expect(
      () => s.decideDispute(
        d,
        DemoDisputeDecision.uphold,
        'Change previous decision',
      ),
      throwsStateError,
    );
    owner(s);
    s.recordWorkflowRefund(p.id, 'REF-002', proof);
  });
  test(
    'Unpaid dispute refund is rejected atomically; uphold leaves reservation',
    () {
      final s = open();
      buyer(s);
      final p = ticket(s);
      final d = s.createTicketDispute(
        p,
        'Unpaid',
        'Please review the unpaid ticket',
      );
      admin(s);
      expect(
        () => s.decideDispute(
          d,
          DemoDisputeDecision.refund,
          'Approved the request',
        ),
        throwsStateError,
      );
      expect(d.resolution, isEmpty);
      expect(p.cancelled, isFalse);
      s.decideDispute(
        d,
        DemoDisputeDecision.uphold,
        'The reservation remains unchanged',
      );
      expect(p.cancelled, isFalse);
    },
  );
  test(
    'Bookings check in only after confirmed payment; refund follows policy',
    () {
      final s = open();
      buyer(s);
      final b = s.bookings.first;
      s.startTransfer(b);
      s.saveProofDraft(b, proof);
      s.submitProof(b, 'TEST-BOOK');
      owner(s);
      s.reviewPayment(b, approve: true);
      buyer(s);
      s.requestCancellation(b, 'Cannot attend');
      owner(s);
      s.reviewCancellation(b, approve: true);
      expect(s.workflowPayment(b.id)!.refundAmount, b.total * 95 ~/ 100);
    },
  );
  test(
    'Persistence restores ticket ledger, evidence, refund and decisions',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      buyer(s);
      final p = ticket(s);
      approve(s, p);
      final d = s.createTicketDispute(
        p,
        'Refund',
        'Please review this refund decision',
      );
      s.attachDisputeEvidence(d, proof);
      admin(s);
      s.decideDispute(
        d,
        DemoDisputeDecision.refund,
        'The refund request is approved',
      );
      s.recordWorkflowRefund(p.id, 'REF-003', proof);
      await s.flush();
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.workflowPayment(p.id)!.refund, DemoRefundState.recorded);
      expect(r.disputes.single.evidence, isNotEmpty);
      expect(r.disputes.single.decision, DemoDisputeDecision.refund);
    },
  );
  test('Failed save retry does not double refund', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    buyer(s);
    final p = ticket(s);
    approve(s, p);
    s.requestTicketCancellation(p, 'Cannot attend');
    owner(s);
    s.reviewTicketCancellation(p, approve: true);
    await s.flush();
    store.failWrite = true;
    s.recordWorkflowRefund(p.id, 'REF-004', proof);
    expect(await s.flush(), isFalse);
    expect(
      () => s.recordWorkflowRefund(p.id, 'REF-005', proof),
      throwsStateError,
    );
    store.failWrite = false;
    await s.retrySave();
    final r = open(store);
    await r.initialize();
    expect(r.workflowPayment(p.id)!.refundReference, 'REF-004');
  });
  test('Oversized/corrupt evidence leaves previous state unchanged', () {
    final s = open();
    buyer(s);
    final p = ticket(s);
    s.startTicketTransfer(p);
    expect(
      () => s.saveTicketProof(p, base64Decode('AAAA')),
      throwsFormatException,
    );
    expect(s.workflowPayment(p.id)!.draft, isEmpty);
  });
  test('Booking refund policy uses request time rather than delayed staff approval', () {
    final s = open();
    buyer(s);
    final b = s.bookings.first;
    s.startTransfer(b);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'POLICY-01');
    owner(s);
    s.reviewPayment(b, approve: true);
    buyer(s);
    now = b.start.subtract(const Duration(hours: 3));
    s.requestCancellation(b, 'Cannot attend');
    now = b.start.subtract(const Duration(minutes: 30));
    owner(s);
    s.reviewCancellation(b, approve: true);
    expect(s.workflowPayment(b.id)!.refundAmount, b.total * 95 ~/ 100);
  });
  test(
    'Late booking cancellation queues 50 percent, without money movement',
    () {
      final s = open();
      buyer(s);
      final b = s.bookings.first;
      s.startTransfer(b);
      s.saveProofDraft(b, proof);
      s.submitProof(b, 'POLICY-02');
      owner(s);
      s.reviewPayment(b, approve: true);
      buyer(s);
      now = b.start.subtract(const Duration(minutes: 119));
      s.requestCancellation(b, 'Cannot attend');
      owner(s);
      s.reviewCancellation(b, approve: true);
      expect(s.workflowPayment(b.id)!.refundAmount, b.total ~/ 2);
      s.recordWorkflowRefund(b.id, 'REF-POLICY', proof);
      expect(s.workflowPayment(b.id)!.refundRecordedAt, now);
    },
  );
  for (final defect in ['amount', 'evidence', 'attendance', 'actor']) {
    test(
      'Corrupt workflow $defect rejects whole snapshot without writing over it',
      () async {
        final store = TestSessionStore();
        final s = open(store);
        await s.initialize();
        buyer(s);
        final p = ticket(s);
        approve(s, p);
        s.requestTicketCancellation(p, 'Cannot attend');
        owner(s);
        s.reviewTicketCancellation(p, approve: true);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        switch (defect) {
          case 'amount':
            (data['payments'] as List).single['refundAmount'] = p.total + 1;
          case 'evidence':
            (data['payments'] as List).single['refundProof'] = 'not-an-image';
          case 'attendance':
            (data['participations'] as List).single['attendance'] = 'completed';
          case 'actor':
            ((data['operations'] as Map)['audit'] as List).first['actor'] =
                'unknown@example.com';
        }
        store.value = jsonEncode(data);
        final snapshot = store.value;
        final r = open(store);
        await r.initialize();
        expect(r.loadFailed, isTrue);
        expect(store.value, snapshot);
      },
    );
  }
}
