import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/admin_report_data.dart';

import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var now = DateTime(2026, 10, 9, 8);
  setUp(() => now = DateTime(2026, 10, 9, 8));
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  AdminReportData report(
    DemoSession s, {
    DateTime? day,
    String? sport,
    String? region,
  }) => AdminReportData.fromSession(
    s,
    from: day ?? now,
    to: day ?? now,
    sport: sport,
    region: region,
  );

  test('Admin-only reporting and date limits', () {
    final s = open();
    expect(() => report(s), throwsStateError);
    admin(s);
    expect(
      () => AdminReportData.fromSession(
        s,
        from: now,
        to: now.add(const Duration(days: 366)),
      ),
      throwsArgumentError,
    );
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(() => report(s), throwsStateError);
  });
  test('Cash dates and service dates do not mix, scopes apply to every transaction', () {
    final s = open();
    admin(s);
    final primary = s.managedBookings.first;
    s.confirmVenuePayment(primary);
    final f = publishTestFacility(s);
    final extra = s.manualReservation(
      customer: DemoSession.phone,
      court: 1,
      start: DateTime(2026, 10, 10, 14),
      hours: 1,
      contact: 'Khách thử',
      contactPhone: DemoSession.phone,
      facilityId: f.id,
      quotedRate: 150000,
    );
    s.confirmVenuePayment(extra);
    final received = report(s);
    expect(received.cashflow.received, primary.total + extra.total);
    expect(received.totalBookings, 0);
    final badminton = report(s, sport: 'Cầu lông');
    expect(badminton.cashflow.received, primary.total);
    expect(report(s, sport: 'Pickleball').cashflow.received, extra.total);
    expect(
      report(s, region: 'TP. Hồ Chí Minh').cashflow.received,
      received.cashflow.received,
    );
    expect(report(s, region: 'Hà Nội').cashflow.received, 0);
    final service = report(s, day: DateTime(2026, 10, 10));
    expect(service.cashflow.received, 0);
    expect(service.totalBookings, 3);
    expect(service.confirmed, 2);
    expect(service.unconfirmed, 1);
    expect(service.bySport, {'Cầu lông': 2, 'Pickleball': 1});
    expect(service.byRegion, {'TP. Hồ Chí Minh': 3});
    expect(() => service.bySport.clear(), throwsUnsupportedError);
  });
  test(
    'Refund requests, outstanding refunds and recorded dates stay separate',
    () {
      final s = open();
      admin(s);
      final b = s.managedBookings.first;
      s.confirmVenuePayment(b);
      s.login(DemoSession.phone, DemoSession.password);
      s.requestCancellation(b, 'Thay đổi lịch cá nhân');
      admin(s);
      s.reviewCancellation(b, approve: true);
      final pending = report(s);
      expect(pending.refundRequests, 1);
      expect(pending.pendingRefundCount, 1);
      expect(pending.cashflow.refunded, 0);
      expect(pending.pendingRefundAmount, b.total * 95 ~/ 100);
      now = DateTime(2026, 10, 10, 8);
      s.recordDemoRefund(b);
      final today = report(s);
      expect(today.refundRequests, 0);
      expect(today.recordedRefundCount, 1);
      expect(today.cashflow.refunded, b.total * 95 ~/ 100);
      expect(today.pendingRefundAmount, 0);
      expect(report(s, sport: 'Pickleball').cashflow.refunded, 0);
      final service = report(s);
      expect(service.cancelled, 1);
      expect(
        service.totalBookings,
        service.confirmed + service.cancelled + service.unconfirmed,
      );
    },
  );
  test(
    'Growth records real signup dates; returning means a prior active booking',
    () {
      final s = open();
      expect(
        s.register('Thành viên mới', 'new@example.com', 'password123'),
        isTrue,
      );
      admin(s);
      expect(report(s).newUserCount, 1);
      expect(report(s).totalUsers, 2);
      expect(report(s).undatedUsers, 1);
      final before = s.managedBookings.first;
      s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: DateTime(2026, 10, 11, 12),
        hours: 1,
        contact: 'Khách quay lại',
        contactPhone: DemoSession.phone,
        quotedRate: s.courtRate(2),
      );
      final subsequent = report(s, day: DateTime(2026, 10, 11));
      expect(subsequent.bookingUsers, 1);
      expect(subsequent.returningUsers, 1);
      expect(subsequent.newUserCount, 0);
      expect(before.owner, DemoSession.phone);
      expect(subsequent.percent(0, 0), '0%');
    },
  );
  test(
    'Registration date survives reload; legacy users stay undated',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      s.register('Thành viên mới', 'member@example.com', 'password123');
      await s.flush();
      final restored = open(store: store);
      await restored.initialize();
      admin(restored);
      expect(report(restored).newUserCount, 1);
      await restored.flush();
      final snapshot = jsonDecode(store.value!) as Map<String, dynamic>;
      for (final raw in snapshot['users'] as List) {
        (raw as Map).remove('registeredAt');
      }
      store.value = jsonEncode(snapshot);
      final legacy = open(store: store);
      await legacy.initialize();
      admin(legacy);
      expect(report(legacy).newUserCount, 0);
      expect(report(legacy).undatedUsers, 2);
      expect(legacy.saveFailed, isFalse);
    },
  );
  test('CSV includes filtered aggregates, UTF-8 and no sample totals', () {
    final s = open();
    admin(s);
    s.confirmVenuePayment(s.managedBookings.first);
    final csv = report(s, sport: 'Pickleball').csv();
    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('Pickleball'));
    expect(csv, contains('"Giá trị giao dịch","0"'));
    expect(csv, isNot(contains('486000000')));
    expect(csv, isNot(contains(DemoSession.password)));
  });
}
