import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_settlement.dart';
import 'package:test_do_an/demo/demo_events.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final proof = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 8), store: store);
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
  DemoBooking book(DemoSession s, {String? voucher, int day = 8}) => s.reserve(
    court: 2,
    start: DateTime(2026, 10, day, 12),
    hours: 1,
    contact: 'Test',
    contactPhone: DemoSession.phone,
    voucherCode: voucher,
  );
  void transfer(DemoSession s, DemoBooking b) {
    player(s);
    s.startTransfer(b);
    s.saveProofDraft(b, proof);
    s.submitProof(b, 'TEST-${b.id}');
  }

  DemoSettlementRow row({
    String id = 'NVH0001',
    String title = 'Test',
    int pending = 0,
    int recorded = 0,
    bool onsite = false,
    bool held = false,
    int paid = 90000,
  }) => DemoSettlementRow(
    id: id,
    title: title,
    date: DateTime(2026, 10, 8, 12),
    gross: paid + 10000,
    discount: 10000,
    paid: paid,
    pendingRefund: pending,
    recordedRefund: recorded,
    onsite: onsite,
    held: held,
  );
  test('Empty report has zero totals and header-only CSV', () {
    final r = DemoSettlementReport([]);
    expect(r.net, 0);
    expect(r.fees, 0);
    expect(r.dailyNet, isEmpty);
    expect(r.csv().split('\r\n').length, 1);
  });
  test(
    'Subtotal minus discount equals confirmed; fee applies after refunds',
    () {
      final r = DemoSettlementReport([row(pending: 45000)]);
      expect(r.gross, 100000);
      expect(r.discount, 10000);
      expect(r.paid, 90000);
      expect(r.pendingRefund, 45000);
      expect(r.retained, 45000);
      expect(r.fees, 1350);
      expect(r.net, 43650);
      expect(r.rows.single.cashBalance, 90000);
    },
  );
  test('Recorded refund is never subtracted twice', () {
    final r = DemoSettlementReport([row(recorded: 45000)]);
    expect(r.pendingRefund, 0);
    expect(r.recordedRefund, 45000);
    expect(r.rows.single.cashBalance, 45000);
    expect(r.net, 43650);
  });
  test('Full refund produces zero estimated fee/net', () {
    final r = DemoSettlementReport([row(recorded: 90000)]);
    expect(r.net, 0);
    expect(r.fees, 0);
  });
  test('Onsite cash has no simulated platform fee', () {
    final r = DemoSettlementReport([row(onsite: true)]);
    expect(r.fees, 0);
    expect(r.onsite, 90000);
  });
  test('Fee rounds down per record and totals aggregate those fees', () {
    final r = DemoSettlementReport([
      row(paid: 10001),
      row(id: 'VE0001', paid: 10001),
    ]);
    expect(r.fees, 600);
    expect(r.net, 19402);
    expect(r.dailyNet.values.single, r.net);
  });
  test('Held net is included in estimate but separately identified', () {
    final r = DemoSettlementReport([row(held: true), row(id: 'VE0001')]);
    expect(r.held, 87300);
    expect(r.net, 174600);
  });
  test(
    'CSV quotes commas/newlines/quotes and neutralizes spreadsheet formulas',
    () {
      final r = DemoSettlementReport([row(title: '=SUM(1,2)\n"test"')]);
      expect(r.csv(), contains('"\'=SUM(1,2)\n""test"""'));
      expect(r.csv(), contains('"87300"'));
    },
  );
  test('Duplicate IDs, negative refund, overrefund and invalid fees fail', () {
    expect(() => DemoSettlementReport([row(), row()]), throwsFormatException);
    expect(
      () => DemoSettlementReport([row(pending: -1)]),
      throwsFormatException,
    );
    expect(
      () => DemoSettlementReport([row(pending: 50000, recorded: 50000)]),
      throwsFormatException,
    );
    expect(
      () => DemoSettlementReport([], basisPoints: -1),
      throwsFormatException,
    );
    expect(
      () => DemoSettlementReport([], basisPoints: 1001),
      throwsFormatException,
    );
  });
  test('Player and guest cannot read staff report', () {
    final s = make();
    expect(() => s.settlementReport(), throwsStateError);
    player(s);
    expect(() => s.settlementReport(), throwsStateError);
  });
  test('Unpaid, pending and rejected proofs are excluded', () {
    final s = make();
    player(s);
    final b = book(s);
    owner(s);
    expect(s.settlementReport().rows, isEmpty);
    transfer(s, b);
    owner(s);
    expect(s.settlementReport().rows, isEmpty);
    s.reviewPayment(b, approve: false, note: 'Sai minh chứng');
    expect(s.settlementReport().rows, isEmpty);
  });
  test('Confirmed transfer uses voucher total and gross contract', () {
    final s = make();
    player(s);
    final b = book(s, voucher: 'DEMO10');
    transfer(s, b);
    owner(s);
    s.reviewPayment(b, approve: true);
    final r = s.settlementReport();
    expect(r.gross, 120000);
    expect(r.discount, 12000);
    expect(r.paid, 108000);
    expect(r.net, 104760);
  });
  test('Cancellation request holds net; approval reserves refund; recording does not re-deduct', () {
    final s = make();
    player(s);
    final b = book(s);
    transfer(s, b);
    owner(s);
    s.reviewPayment(b, approve: true);
    player(s);
    s.requestCancellation(b, 'Cannot attend');
    owner(s);
    expect(s.settlementReport().held, 116400);
    s.reviewCancellation(b, approve: true);
    final before = s.settlementReport();
    expect(before.pendingRefund, 114000);
    expect(before.net, 5820);
    s.recordWorkflowRefund(b.id, 'REF-001', proof);
    final after = s.settlementReport();
    expect(after.pendingRefund, 0);
    expect(after.recordedRefund, 114000);
    expect(after.net, before.net);
  });
  test('Inclusive service-date and channel/type filters compose', () {
    final s = make();
    player(s);
    final a = book(s);
    transfer(s, a);
    owner(s);
    s.reviewPayment(a, approve: true);
    player(s);
    final b = book(s, day: 9);
    owner(s);
    s.confirmVenuePayment(b);
    expect(
      s
          .settlementReport(
            from: DateTime(2026, 10, 8),
            to: DateTime(2026, 10, 8, 23),
          )
          .rows
          .single
          .id,
      a.id,
    );
    expect(
      s.settlementReport(onsite: true, tickets: false).rows.single.id,
      b.id,
    );
    expect(s.settlementReport(tickets: true).rows, isEmpty);
    expect(
      s
          .settlementReport(
            from: DateTime(2026, 10, 10),
            to: DateTime(2026, 10, 11),
          )
          .rows,
      isEmpty,
    );
    expect(
      () => s.settlementReport(from: DateTime(2026, 10, 10)),
      throwsArgumentError,
    );
    expect(
      () => s.settlementReport(
        from: DateTime(2026, 10, 10),
        to: DateTime(2026, 10, 8),
      ),
      throwsArgumentError,
    );
  });
  test('Ticket payments join the same ledger exactly once', () {
    final s = make();
    player(s);
    final p = s.joinEvent(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(s.now),
      quantity: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    s.startTicketTransfer(p);
    s.saveTicketProof(p, proof);
    s.submitTicketProof(p, 'VE-TEST');
    owner(s);
    s.reviewTicketPayment(p, approve: true);
    expect(s.settlementReport(tickets: true).paid, p.total);
    expect(s.settlementReport().rows.length, 1);
  });
  test('Changing simulated fee never mutates financial history', () {
    final s = make();
    player(s);
    final b = book(s);
    transfer(s, b);
    owner(s);
    s.reviewPayment(b, approve: true);
    final history = s.operationAudit.length;
    expect(s.settlementReport(basisPoints: 500).net, 114000);
    expect(s.settlementReport(basisPoints: 0).net, 120000);
    expect(s.operationAudit.length, history);
    expect(b.total, 120000);
  });
  test(
    'Restart recomputes identical ledger without separate stale totals',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      player(s);
      final b = book(s);
      owner(s);
      s.confirmVenuePayment(b);
      final csv = s.settlementReport().csv();
      await s.flush();
      final restored = make(store);
      await restored.initialize();
      expect(restored.settlementReport().csv(), csv);
    },
  );
}
