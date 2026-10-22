import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_calendar.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  final day = DateTime(2026, 10, 8, 10);
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
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
  void buyer(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);
  test(
    'Court lock immediately blocks player inventory and unlock restores it',
    () {
      final s = open();
      owner(s);
      final b = s.blockCourt(
        court: 2,
        start: day,
        hours: 2,
        reason: 'Maintenance work',
      );
      expect(s.available(2, day, 1), isFalse);
      expect(
        s.available(2, day.subtract(const Duration(hours: 1)), 2),
        isFalse,
      );
      expect(s.available(2, day.add(const Duration(hours: 2)), 1), isTrue);
      buyer(s);
      expect(
        () => s.reserve(
          court: 2,
          start: day,
          hours: 1,
          contact: 'Test',
          contactPhone: DemoSession.phone,
        ),
        throwsStateError,
      );
      expect(() => s.unblockCourt(b), throwsStateError);
      owner(s);
      s.unblockCourt(b);
      expect(s.available(2, day, 1), isTrue);
      expect(() => s.unblockCourt(b), throwsStateError);
    },
  );
  test('Locks cannot cover existing booking or another lock', () {
    final s = open();
    owner(s);
    expect(
      () => s.blockCourt(
        court: 1,
        start: s.managedBookings.first.start,
        hours: 1,
        reason: 'Maintenance work',
      ),
      throwsStateError,
    );
    final b = s.blockCourt(
      court: 2,
      start: day,
      hours: 2,
      reason: 'Maintenance work',
    );
    expect(
      () => s.blockCourt(
        court: 2,
        start: day.add(const Duration(hours: 1)),
        hours: 2,
        reason: 'Another maintenance',
      ),
      throwsStateError,
    );
    s.blockCourt(court: 2, start: b.end, hours: 1, reason: 'After first block');
    expect(s.courtBlocks.length, 2);
  });
  test(
    'Invalid lock reason, horizon, duration and foreign block fail atomically',
    () {
      final s = open();
      owner(s);
      expect(
        () => s.blockCourt(court: 2, start: day, hours: 1, reason: 'x'),
        throwsStateError,
      );
      expect(
        () =>
            s.blockCourt(court: 4, start: day, hours: 1, reason: 'Maintenance'),
        throwsStateError,
      );
      expect(
        () =>
            s.blockCourt(court: 2, start: now, hours: 1, reason: 'Maintenance'),
        throwsStateError,
      );
      expect(
        () => s.blockCourt(
          court: 2,
          start: day.add(const Duration(days: 6)),
          hours: 1,
          reason: 'Maintenance',
        ),
        throwsStateError,
      );
      expect(
        () => s.blockCourt(
          court: 2,
          start: day,
          hours: 16,
          reason: 'Maintenance',
        ),
        throwsStateError,
      );
      expect(s.courtBlocks, isEmpty);
      final b = s.blockCourt(
        court: 2,
        start: day,
        hours: 1,
        reason: 'Maintenance',
      );
      expect(
        () => s.unblockCourt(DemoCourtBlock.fromJson(b.toJson())),
        throwsStateError,
      );
    },
  );
  test('Manual reservation belongs to selected existing player, not staff', () {
    final s = open();
    buyer(s);
    s.register('Other', 'other@example.com', 'Test1234');
    owner(s);
    final b = s.manualReservation(
      customer: 'other@example.com',
      court: 2,
      start: day,
      hours: 2,
      contact: 'Other Player',
      contactPhone: DemoSession.phone,
      quotedRate: s.courtRate(2),
    );
    expect(b.owner, 'other@example.com');
    expect(b.total, 240000);
    expect(s.available(2, day, 1), isFalse);
    s.login('other@example.com', 'Test1234');
    expect(s.bookings.single.id, b.id);
    buyer(s);
    expect(s.bookings.any((e) => e.id == b.id), isFalse);
  });
  test('Manual reservation rejects duplicate slot, bad customer, bad phone and stale price', () {
    final s = open();
    owner(s);
    for (final customer in ['missing@example.com', '__owner__']) {
      expect(
        () => s.manualReservation(
          customer: customer,
          court: 2,
          start: day,
          hours: 1,
          contact: 'Test',
          contactPhone: DemoSession.phone,
          quotedRate: 120000,
        ),
        throwsStateError,
      );
    }
    expect(
      () => s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: day,
        hours: 1,
        contact: 'Test',
        contactPhone: 'bad',
        quotedRate: 120000,
      ),
      throwsStateError,
    );
    expect(
      () => s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: day,
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        quotedRate: 130000,
      ),
      throwsStateError,
    );
    final b = s.manualReservation(
      customer: DemoSession.phone,
      court: 2,
      start: day,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
      quotedRate: 120000,
    );
    expect(
      () => s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: day,
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        quotedRate: 120000,
      ),
      throwsStateError,
    );
    expect(s.managedBookings.where((e) => e.id == b.id).length, 1);
  });
  test('Blocked player cannot be chosen for a new manual reservation', () {
    final s = open();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.setPlayerBlocked(
      DemoSession.phone,
      true,
      password: DemoSession.password,
      reason: 'Demo access review',
      expectedBlocked: false,
      expectedRevision: 0,
    );
    owner(s);
    expect(s.calendarCustomers, isEmpty);
    expect(
      () => s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: day,
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        quotedRate: 120000,
      ),
      throwsStateError,
    );
  });
  test('Reschedule preserves ID, voucher, price, duration and returns old inventory', () {
    final s = open();
    buyer(s);
    final b = s.reserve(
      court: 2,
      start: day,
      hours: 2,
      contact: 'Test',
      contactPhone: DemoSession.phone,
      voucherCode: 'DEMO10',
    );
    final total = b.total, id = b.id;
    owner(s);
    s.rescheduleBooking(
      b,
      court: 3,
      start: day.add(const Duration(hours: 1)),
      expectedRevision: 0,
    );
    expect(b.id, id);
    expect(b.hours, 2);
    expect(b.total, total);
    expect(b.voucherCode, 'DEMO10');
    expect(b.revision, 1);
    expect(s.available(2, day, 2), isTrue);
    expect(s.available(3, b.start, 2), isFalse);
    expect(s.workflowHistory(b.id).first.action, contains('Đổi lịch'));
  });
  test('Reschedule can overlap own old hours but rejects occupied/locked/stale drafts', () {
    final s = open();
    buyer(s);
    final b = s.reserve(
      court: 2,
      start: day,
      hours: 2,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    owner(s);
    s.rescheduleBooking(
      b,
      court: 2,
      start: day.add(const Duration(hours: 1)),
      expectedRevision: 0,
    );
    expect(
      () => s.rescheduleBooking(
        b,
        court: 2,
        start: day.add(const Duration(hours: 2)),
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    s.blockCourt(court: 3, start: day, hours: 2, reason: 'Maintenance work');
    expect(
      () => s.rescheduleBooking(b, court: 3, start: day, expectedRevision: 1),
      throwsStateError,
    );
    expect(
      () => s.rescheduleBooking(
        b,
        court: 1,
        start: s.managedBookings.first.start,
        expectedRevision: 1,
      ),
      throwsStateError,
    );
    expect(b.revision, 1);
  });
  test('Pending transfer, cancellation, checked-in and player reschedules are denied', () {
    final s = open();
    buyer(s);
    final b = s.bookings.last;
    expect(
      () => s.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0),
      throwsStateError,
    );
    s.startTransfer(b);
    owner(s);
    expect(
      () => s.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0),
      throwsStateError,
    );
    buyer(s);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'TEST-01');
    owner(s);
    s.reviewPayment(b, approve: true);
    buyer(s);
    s.requestCancellation(b, 'Cannot attend');
    owner(s);
    expect(
      () => s.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0),
      throwsStateError,
    );
    s.reviewCancellation(b, approve: false, note: 'Please keep booking');
    now = b.start.subtract(const Duration(minutes: 30));
    s.setAttendance(b.id, DemoAttendance.checkedIn);
    expect(
      () => s.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0),
      throwsStateError,
    );
  });
  test(
    'Onsite confirmation has no fake proof and enables staff check-in once',
    () {
      final s = open();
      owner(s);
      final b = s.managedBookings.first;
      buyer(s);
      expect(() => s.confirmVenuePayment(b), throwsStateError);
      owner(s);
      s.confirmVenuePayment(b);
      final p = s.paymentFor(b)!;
      expect(p.atVenue, isTrue);
      expect(p.proof, isEmpty);
      expect(p.state, DemoPaymentState.approved);
      expect(() => s.confirmVenuePayment(b), throwsStateError);
      now = b.start.subtract(const Duration(minutes: 30));
      s.setAttendance(b.id, DemoAttendance.checkedIn);
      expect(b.attendance, DemoAttendance.checkedIn);
    },
  );
  test('Existing transfer cannot be overwritten by onsite confirmation', () {
    final s = open();
    buyer(s);
    final b = s.bookings.first;
    s.startTransfer(b);
    owner(s);
    expect(() => s.confirmVenuePayment(b), throwsStateError);
    expect(s.paymentFor(b)!.atVenue, isFalse);
  });
  test(
    'Onsite, revised booking and locks survive restart with old price intact',
    () async {
      final store = TestSessionStore();
      final live = open(store);
      await live.initialize();
      owner(live);
      final b = live.managedBookings.first;
      live.confirmVenuePayment(b);
      live.rescheduleBooking(b, court: 2, start: day, expectedRevision: 0);
      live.blockCourt(
        court: 3,
        start: day,
        hours: 2,
        reason: 'Maintenance work',
      );
      await live.flush();
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.courtBlocks.single.hours, 2);
      expect(r.managedBookings.firstWhere((e) => e.id == b.id).revision, 1);
      expect(r.workflowPayment(b.id)!.atVenue, isTrue);
    },
  );
  test('Approved payment can reschedule before original proof deadline and restore', () async {
    now = DateTime(2026, 10, 7, 9, 45);
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    buyer(s);
    final b = s.bookings.last;
    s.startTransfer(b);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'TEST-MOVE');
    owner(s);
    s.reviewPayment(b, approve: true);
    final next = DateTime(2026, 10, 7, 10);
    s.rescheduleBooking(b, court: 2, start: next, expectedRevision: 0);
    await s.flush();
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    expect(r.workflowRecord(b.id).start, next);
  });
  test('Save retry does not duplicate a manual reservation or lock', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    owner(s);
    store.failWrite = true;
    s.manualReservation(
      customer: DemoSession.phone,
      court: 2,
      start: day,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
      quotedRate: 120000,
    );
    s.blockCourt(court: 3, start: day, hours: 1, reason: 'Maintenance work');
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    final r = open(store);
    await r.initialize();
    expect(r.managedBookings.length, 3);
    expect(r.courtBlocks.length, 1);
  });
  test(
    'Previous snapshots without blocks/revision/onsite fields migrate safely',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('courtBlocks');
      data.remove('nextBlock');
      for (final b in data['bookings'] as List) {
        b.remove('revision');
      }
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isFalse);
      expect(r.courtBlocks, isEmpty);
      expect(r.managedBookings.first.revision, 0);
    },
  );
  for (final defect in [
    'block-overlap',
    'booking-overlap',
    'block-reason',
    'counter',
    'onsite-state',
  ]) {
    test('Corrupt calendar $defect fails atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      final b = s.managedBookings.first;
      s.confirmVenuePayment(b);
      s.blockCourt(court: 2, start: day, hours: 2, reason: 'Maintenance work');
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      switch (defect) {
        case 'block-overlap':
          (data['courtBlocks'] as List).first['court'] = 1;
          (data['courtBlocks'] as List).first['start'] = b.start
              .toIso8601String();
        case 'booking-overlap':
          (data['bookings'] as List).last['start'] = b.start.toIso8601String();
        case 'block-reason':
          (data['courtBlocks'] as List).first['reason'] = '';
        case 'counter':
          data['nextBlock'] = 1;
        case 'onsite-state':
          (data['payments'] as List).first['state'] = 'pending';
      }
      store.value = jsonEncode(data);
      final before = store.value;
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(store.value, before);
    });
  }
}
