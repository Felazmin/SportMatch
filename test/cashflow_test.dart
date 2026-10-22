import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show publishTestFacility, sampleFacilityProof;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2026, 10, 8, 10);
  DemoSession open({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(store: store, now: clock ?? () => date);
    addTearDown(s.dispose);
    return s;
  }

  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  DemoBooking book(DemoSession s, {String facility = '', int court = 2}) =>
      s.reserve(
        facilityId: facility,
        court: court,
        start: date.add(const Duration(days: 3, hours: 2)),
        hours: 1,
        contact: 'Guest',
        contactPhone: DemoSession.phone,
      );
  void pending(DemoSession s, DemoBooking b) {
    player(s);
    s.startTransfer(b);
    s.saveProofDraft(b, base64Decode(sampleFacilityProof));
    s.submitProof(b, 'TEST-${b.id}');
    owner(s);
  }

  test(
    'Receipt date differs from service date and period bounds are inclusive',
    () {
      final s = open();
      player(s);
      final b = book(s);
      pending(s, b);
      final received = DateTime(2026, 10, 7, 23, 59);
      s.reviewPayment(b, approve: true, receivedAt: received);
      final r = s.cashflowReport(
        from: DateTime(2026, 10, 7),
        to: DateTime(2026, 10, 8),
      );
      expect(r.received, b.total);
      expect(r.daily()[DateTime(2026, 10, 7)], b.total);
      expect(r.daily()[DateTime(2026, 10, 8)], 0);
      expect(
        s
            .cashflowReport(
              from: DateTime(2026, 10, 8),
              to: DateTime(2026, 10, 8),
            )
            .received,
        0,
      );
      expect(
        s
            .settlementReport(
              from: DateTime(2026, 10, 7),
              to: DateTime(2026, 10, 8),
            )
            .paid,
        0,
      );
      expect(() => r.entries.clear(), throwsUnsupportedError);
    },
  );
  test('Refunds use refund recording date and pending refunds are not cash outflows', () {
    var clock = date;
    final s = open(clock: () => clock);
    player(s);
    final b = book(s);
    pending(s, b);
    s.reviewPayment(b, approve: true);
    player(s);
    s.requestCancellation(b, 'Cannot attend');
    owner(s);
    s.reviewCancellation(b, approve: true);
    final first = s.cashflowReport(from: date, to: date);
    expect(first.received, b.total);
    expect(first.refunded, 0);
    expect(first.pendingRefund, b.total * 95 ~/ 100);
    clock = date.add(const Duration(days: 1));
    s.recordDemoRefund(b);
    final next = s.cashflowReport(from: clock, to: clock);
    expect(next.received, 0);
    expect(next.refunded, b.total * 95 ~/ 100);
    expect(next.balance, -next.refunded);
    expect(next.pendingRefund, 0);
    expect(s.cashflowReport(from: date, to: date).refunded, 0);
  });
  test('Venue and onsite filters do not mix different facilities', () {
    final s = open();
    final f = publishTestFacility(s);
    player(s);
    final primary = book(s), other = book(s, facility: f.id);
    pending(s, primary);
    s.reviewPayment(primary, approve: true);
    s.confirmVenuePayment(other);
    expect(
      s.cashflowReport(from: date, to: date, facilityId: '').received,
      primary.total,
    );
    expect(
      s.cashflowReport(from: date, to: date, facilityId: f.id).received,
      other.total,
    );
    expect(
      s.cashflowReport(from: date, to: date, onsite: true).received,
      other.total,
    );
    expect(
      s.cashflowReport(from: date, to: date, onsite: false).received,
      primary.total,
    );
    final r = s.cashflowReport(from: date, to: date);
    expect(r.byFacility[''], primary.total);
    expect(r.byFacility[f.id], other.total);
  });
  test('Ticket confirmations are reported separately instead of inventing a facility link', () {
    final s = open();
    player(s);
    final e = demoEvents.first;
    final ticket = s.joinEvent(
      eventId: e.id,
      start: e.start(date),
      quantity: 1,
      contact: 'Guest',
      contactPhone: DemoSession.phone,
    );
    s.startTicketTransfer(ticket);
    s.saveTicketProof(ticket, base64Decode(sampleFacilityProof));
    s.submitTicketProof(ticket, 'TICKET-TEST');
    owner(s);
    s.reviewTicketPayment(ticket, approve: true);
    expect(
      s.cashflowReport(from: date, to: date, facilityId: 'EVENTS').received,
      ticket.total,
    );
    expect(s.cashflowReport(from: date, to: date, facilityId: '').received, 0);
    expect(s.cashflowReport(from: date, to: date, tickets: false).received, 0);
  });
  test(
    'Invalid receipt date and repeat review cannot mutate approved data',
    () {
      final s = open();
      player(s);
      final b = book(s);
      pending(s, b);
      expect(
        () => s.reviewPayment(
          b,
          approve: true,
          receivedAt: date.add(const Duration(seconds: 1)),
        ),
        throwsStateError,
      );
      expect(s.paymentFor(b)!.state, DemoPaymentState.pending);
      expect(s.paymentFor(b)!.receivedAt, isNull);
      expect(
        () => s.reviewPayment(b, approve: true, receivedAt: DateTime(2019)),
        throwsStateError,
      );
      s.reviewPayment(b, approve: true);
      expect(s.paymentFor(b)!.receivedAt, date);
      expect(
        () => s.reviewPayment(b, approve: true, receivedAt: DateTime(2020)),
        throwsStateError,
      );
      expect(s.paymentFor(b)!.receivedAt, date);
    },
  );
  test(
    'Report guards permissions, unknown facilities and excessive date spans',
    () {
      final s = open();
      player(s);
      expect(() => s.cashflowReport(from: date, to: date), throwsStateError);
      owner(s);
      expect(
        () => s.cashflowReport(
          from: date,
          to: date.subtract(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      expect(
        () => s.cashflowReport(
          from: date,
          to: date.add(const Duration(days: 366)),
        ),
        throwsArgumentError,
      );
      expect(
        () => s.cashflowReport(from: date, to: date, facilityId: 'CS9999'),
        throwsArgumentError,
      );
    },
  );
  test(
    'Receipt timestamp survives restart; legacy data remains undated',
    () async {
      final store = TestSessionStore(), s = open(store: TestSessionStore());
      await s.initialize();
      final target = open(store: store);
      await target.initialize();
      player(target);
      final b = book(target);
      pending(target, b);
      target.reviewPayment(b, approve: true);
      await target.flush();
      final restored = open(store: store);
      await restored.initialize();
      owner(restored);
      expect(restored.cashflowReport(from: date, to: date).received, b.total);
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      for (final p in j['payments'] as List) {
        (p as Map).remove('receivedAt');
      }
      store.value = jsonEncode(j);
      final old = open(store: store);
      await old.initialize();
      owner(old);
      final legacy = old.cashflowReport(from: date, to: date);
      expect(legacy.received, 0);
      expect(legacy.undatedPayments, 1);
      expect(old.settlementReport().paid, b.total);
    },
  );
  test('CSV contains dated events without customer contacts or bank account details', () {
    final s = open();
    player(s);
    final b = book(s);
    pending(s, b);
    s.reviewPayment(b, approve: true);
    final csv = s.cashflowReport(from: date, to: date).csv();
    expect(csv, contains('recorded_date'));
    expect(csv, contains('payment'));
    expect(csv, contains(b.id));
    expect(csv, isNot(contains(DemoSession.phone)));
    expect(csv, isNot(contains('Guest')));
  });
}
