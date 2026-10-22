import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

void main() {
  final today = DateTime(2026, 10, 9, 10);
  DemoSession open() {
    final s = DemoSession(now: () => today);
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    return s;
  }

  test('System report requires Admin, including after account changes', () {
    final s = open();
    expect(s.systemOverview(from: today, to: today).players, 1);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(() => s.systemOverview(from: today, to: today), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.systemOverview(from: today, to: today), throwsStateError);
    s.logout();
    expect(() => s.systemOverview(from: today, to: today), throwsStateError);
  });

  test('Service dates and receipt dates remain separate', () {
    final s = open();
    final booking = s.managedBookings.first;
    s.confirmVenuePayment(booking);
    final receipt = s.systemOverview(from: today, to: today);
    expect(receipt.cashflow.received, booking.total);
    expect(receipt.bookings, 0);
    expect(receipt.publicFacilities, 1);
    final service = s.systemOverview(from: booking.start, to: booking.start);
    expect(service.bookings, 2);
    expect(service.cashflow.received, 0);
    expect(() => receipt.cashflow.entries.clear(), throwsUnsupportedError);
  });

  test(
    'Cancellation updates service counts and current queue independently',
    () {
      final s = open();
      final booking = s.managedBookings.first;
      s.confirmVenuePayment(booking);
      s.login(DemoSession.phone, DemoSession.password);
      s.requestCancellation(booking, 'Cannot attend this booking');
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      expect(s.systemOverview(from: today, to: today).pendingCancellations, 1);
      s.reviewCancellation(booking, approve: true);
      final service = s.systemOverview(from: booking.start, to: booking.start);
      expect(service.bookings, 1);
      expect(service.cancelled, 1);
      expect(service.pendingCancellations, 0);
      expect(service.cashflow.pendingRefund, booking.total * 95 ~/ 100);
      expect(service.cashflow.refunded, 0);
    },
  );

  test(
    'Blocked account counts and date validation use authoritative state',
    () {
      final s = open();
      s.setPlayerBlocked(
        DemoSession.phone,
        true,
        password: DemoSession.password,
        reason: 'Repeated policy violations',
        expectedBlocked: false,
        expectedRevision: 0,
      );
      expect(s.systemOverview(from: today, to: today).blockedPlayers, 1);
      expect(
        () => s.systemOverview(
          from: today,
          to: today.subtract(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      expect(
        () => s.systemOverview(
          from: today,
          to: today.add(const Duration(days: 366)),
        ),
        throwsArgumentError,
      );
    },
  );
}
