import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

void main() {
  late DemoSession session;
  final now = DateTime(2026, 10, 3, 10, 15);
  final start = DateTime(2026, 10, 4, 12);
  setUp(() => session = DemoSession(now: () => now));
  tearDown(() => session.dispose());
  test('Availability rejects past, closed, invalid and out-of-range slots', () {
    expect(session.available(1, DateTime(2026, 10, 3, 10), 1), isFalse);
    expect(session.available(1, DateTime(2026, 10, 4, 5), 1), isFalse);
    expect(session.available(1, DateTime(2026, 10, 4, 21), 2), isFalse);
    expect(session.available(0, start, 1), isFalse);
    expect(session.available(4, start, 1), isFalse);
    expect(session.available(1, start, 0), isFalse);
    expect(session.available(1, start, 4), isFalse);
    expect(
      session.available(1, start.add(const Duration(minutes: 30)), 1),
      isFalse,
    );
    expect(session.available(1, DateTime(2026, 10, 10, 12), 1), isFalse);
    expect(session.available(1, start, 1), isTrue);
  });
  test('Reservation requires login and valid contact', () {
    expect(
      () => session.reserve(
        court: 1,
        start: start,
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
      ),
      throwsStateError,
    );
    session.login(DemoSession.phone, DemoSession.password);
    expect(
      () => session.reserve(
        court: 1,
        start: start,
        hours: 1,
        contact: '',
        contactPhone: DemoSession.phone,
      ),
      throwsStateError,
    );
    expect(
      () => session.reserve(
        court: 1,
        start: start,
        hours: 1,
        contact: 'Test',
        contactPhone: '123',
      ),
      throwsStateError,
    );
    expect(session.bookings.length, 2);
  });
  test('Totals and overlap protection include full duration but allow adjacent slots', () {
    session.login(DemoSession.phone, DemoSession.password);
    final booking = session.reserve(
      court: 1,
      start: start,
      hours: 2,
      contact: 'Test',
      contactPhone: '+84 901234567',
    );
    expect(booking.total, 240000);
    expect(booking.phone, DemoSession.phone);
    expect(session.upcomingCount, 3);
    expect(
      session.available(1, start.add(const Duration(hours: 1)), 1),
      isFalse,
    );
    expect(
      session.available(1, start.subtract(const Duration(hours: 1)), 2),
      isFalse,
    );
    expect(
      session.available(1, start.add(const Duration(hours: 2)), 1),
      isTrue,
    );
    expect(session.available(2, start, 2), isTrue);
    expect(
      () => session.reserve(
        court: 1,
        start: start,
        hours: 2,
        contact: 'Test',
        contactPhone: DemoSession.phone,
      ),
      throwsStateError,
    );
    expect(session.bookings.length, 3);
  });
  test(
    'Histories are private, aliases share history, cancellation releases slot',
    () {
      session.login(DemoSession.phone, DemoSession.password);
      final booking = session.reserve(
        court: 1,
        start: start,
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
      );
      session.logout();
      expect(session.bookings, isEmpty);
      session.register('Other', '0912345678', 'Other123');
      expect(session.bookings, isEmpty);
      expect(session.cancel(booking), isFalse);
      expect(session.available(1, start, 1), isFalse);
      session.login(DemoSession.email, DemoSession.password);
      expect(session.bookings.length, 3);
      expect(session.cancel(booking), isTrue);
      expect(session.cancel(booking), isFalse);
      expect(session.available(1, start, 1), isTrue);
      expect(session.upcomingCount, 2);
      expect(
        session.bookings.singleWhere((b) => b.id == booking.id).cancelled,
        isTrue,
      );
    },
  );
  test('Cannot cancel started bookings and data resets with app instance', () {
    var clock = now;
    final timed = DemoSession(now: () => clock);
    timed.login(DemoSession.phone, DemoSession.password);
    final booking = timed.reserve(
      court: 1,
      start: start,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    clock = start;
    expect(timed.cancel(booking), isFalse);
    timed.dispose();
    session.login(DemoSession.phone, DemoSession.password);
    expect(session.bookings.length, 2);
  });
}
