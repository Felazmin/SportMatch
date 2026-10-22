import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_operations.dart';

void main() {
  final today = DateTime(2026, 10, 7, 10);
  final tomorrow = DateTime(2026, 10, 8);
  DemoSession open() {
    final s = DemoSession(now: () => today);
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    return s;
  }

  test('Overview rejects guests and players', () {
    final s = open();
    s.logout();
    expect(() => s.dayOverview(today), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.dayOverview(today), throwsStateError);
  });
  test('Seeded reservations occupy two of 48 cells, not confirmed money', () {
    final s = open();
    final d = s.dayOverview(tomorrow);
    expect(d.capacity, 48);
    expect(d.reserved, 2);
    expect(d.blocked, 0);
    expect(d.bookings.length, 2);
    expect(d.confirmedValue, 0);
    expect(() => d.bookings.clear(), throwsUnsupportedError);
    expect(s.dayOverview(today).reserved, 0);
  });
  test('Locks are disjoint hourly cells, unlock updates immediately', () {
    final s = open();
    final b = s.blockCourt(
      court: 2,
      start: tomorrow.add(const Duration(hours: 8)),
      hours: 3,
      reason: 'Maintenance work',
    );
    expect(s.dayOverview(tomorrow).blocked, 3);
    expect(s.dayOverview(tomorrow).reserved, 2);
    s.unblockCourt(b);
    expect(s.dayOverview(tomorrow).blocked, 0);
  });
  test('Disabled courts leave denominator; disabled historical bookings remain listed', () {
    final s = open();
    s.submitCourtSettings(
      CourtSettings(
        rates: [100000, 100000, 100000],
        enabled: [false, true, true],
      ),
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.reviewCourtSettings(approve: true);
    final d = s.dayOverview(tomorrow);
    expect(d.capacity, 32);
    expect(d.reserved, 0);
    expect(d.bookings.length, 2);
  });
  test('No enabled courts yields zero capacity', () {
    final s = open();
    s.submitCourtSettings(
      CourtSettings(
        rates: [100000, 100000, 100000],
        enabled: [false, false, false],
      ),
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.reviewCourtSettings(approve: true);
    expect(s.dayOverview(tomorrow).capacity, 0);
  });
  test(
    'Confirmed service value includes onsite payment, excludes cancellation',
    () {
      final s = open();
      final b = s.managedBookings.first;
      s.confirmVenuePayment(b);
      expect(s.dayOverview(tomorrow).confirmedValue, b.total);
      s.login(DemoSession.phone, DemoSession.password);
      s.requestCancellation(b, 'Cannot attend tomorrow');
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.reviewCancellation(b, approve: true);
      final d = s.dayOverview(tomorrow);
      expect(d.confirmedValue, 0);
      expect(d.reserved, 1);
      expect(d.bookings.length, 1);
    },
  );
  test('Local calendar horizon rejects past, far future and UTC', () {
    final s = open();
    for (final d in [
      today.subtract(const Duration(days: 1)),
      today.add(const Duration(days: 7)),
      DateTime.utc(2026, 10, 8),
    ]) {
      expect(() => s.dayOverview(d), throwsStateError);
    }
    expect(s.dayOverview(today.add(const Duration(days: 6))).capacity, 48);
  });
}
