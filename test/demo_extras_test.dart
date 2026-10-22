import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_extras.dart';
import 'package:test_do_an/screens/venue_map_screen.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 3, 10);
  DemoSession open([TestSessionStore? store]) =>
      DemoSession(now: () => now, store: store);
  DemoBooking reserve(
    DemoSession session, {
    String? code,
    int hours = 1,
    int court = 2,
  }) => session.reserve(
    court: court,
    start: DateTime(2026, 10, 4, 12),
    hours: hours,
    contact: 'Test',
    contactPhone: '0912345678',
    voucherCode: code,
  );
  test('Voucher calculations respect minimum and never exceed subtotal', () {
    expect(demoVouchers[0].discount(120000), 12000);
    expect(demoVouchers[1].discount(100000), 0);
    expect(demoVouchers[2].discount(240000), 30000);
    expect(
      const DemoVoucher('TEST', 'Test', amount: 200000).discount(120000),
      120000,
    );
  });
  test(
    'Voucher is consumed once; cancellation restores voucher and points',
    () {
      final s = open()..login(DemoSession.phone, DemoSession.password);
      addTearDown(s.dispose);
      expect(s.points, 1280);
      final b = reserve(s, code: 'DEMO10');
      expect(b.subtotal, 120000);
      expect(b.total, 108000);
      expect(s.vouchers.length, 2);
      expect(s.points, 1388);
      expect(() => reserve(s, code: 'DEMO10', court: 3), throwsStateError);
      expect(s.bookings.length, 3);
      expect(s.cancel(b), isTrue);
      expect(s.points, 1280);
      expect(s.vouchers.length, 3);
      expect(s.cancel(b), isFalse);
      expect(reserve(s, code: 'DEMO10').total, 108000);
    },
  );
  test('Ineligible and unknown vouchers do not create a booking', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    expect(() => reserve(s, code: 'DEMO30'), throwsStateError);
    expect(() => reserve(s, code: 'UNKNOWN'), throwsStateError);
    expect(s.available(2, DateTime(2026, 10, 4, 12), 1), isTrue);
    expect(reserve(s, code: 'DEMO30', hours: 2).total, 210000);
  });
  test('Another account has separate wallet, points, contact and tickets', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    reserve(s, code: 'DEMO10');
    s.updateContactPhone('0912345678');
    s.createTicket('Demo', 'Nội dung hỗ trợ thử nghiệm');
    s.register('New', 'new@example.com', 'Test1234');
    expect(s.vouchers.length, 3);
    expect(s.points, 0);
    expect(s.contactPhone, '');
    expect(s.tickets, isEmpty);
    expect(reserve(s, code: 'DEMO10', court: 3).total, 108000);
    expect(s.points, 108);
    s.login(DemoSession.email, DemoSession.password);
    expect(s.points, 1388);
    expect(s.contactPhone, '0912345678');
    expect(s.tickets.length, 1);
  });
  test(
    'Passwords require current secret, valid replacement and logged in user',
    () {
      final s = open();
      addTearDown(s.dispose);
      expect(s.changePassword('Demo1234', 'New12345'), isFalse);
      s.login(DemoSession.email, DemoSession.password);
      expect(s.changePassword('wrong', 'New12345'), isFalse);
      expect(s.changePassword('Demo1234', 'short'), isFalse);
      expect(s.changePassword('Demo1234', 'abcdefgh'), isFalse);
      expect(s.changePassword('Demo1234', 'New12345'), isTrue);
      s.logout();
      expect(s.login(DemoSession.email, DemoSession.password), isFalse);
      expect(s.login(DemoSession.phone, 'New12345'), isTrue);
      s.register('New', 'new@example.com', 'Test1234');
      expect(s.changePassword('Test1234', 'Other1234'), isTrue);
      s.logout();
      expect(s.login('new@example.com', 'Test1234'), isFalse);
      expect(s.login('new@example.com', 'Other1234'), isTrue);
    },
  );
  test(
    'Enrollment duplicates rejected; cancellation returns capacity once',
    () {
      final s = open()..login(DemoSession.phone, DemoSession.password);
      addTearDown(s.dispose);
      final start = demoCourses.first.start(now);
      final e = s.enroll('basic', start);
      expect(s.courseSeats('basic', start), 11);
      expect(() => s.enroll('basic', start), throwsStateError);
      expect(s.cancelEnrollment(e), isTrue);
      expect(s.cancelEnrollment(e), isFalse);
      expect(s.courseSeats('basic', start), 12);
      expect(s.enroll('basic', start).id, 'HL0002');
    },
  );
  test('Enrollment capacity is shared by accounts and not exceeded', () {
    final s = open();
    addTearDown(s.dispose);
    final start = demoCourses.first.start(now);
    for (var i = 0; i < 12; i++) {
      expect(s.register('User $i', 'user$i@example.com', 'Test1234'), isTrue);
      s.enroll('basic', start);
    }
    s.register('Extra', 'extra@example.com', 'Test1234');
    expect(s.courseSeats('basic', start), 0);
    expect(() => s.enroll('basic', start), throwsStateError);
  });
  test('Enrollment rejects guest, unknown class, invalid date and cross-account cancellation', () {
    final s = open();
    addTearDown(s.dispose);
    final start = demoCourses.first.start(now);
    expect(() => s.enroll('basic', start), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.enroll('unknown', start), throwsStateError);
    expect(() => s.enroll('basic', now), throwsStateError);
    final e = s.enroll('basic', start);
    s.register('Other', 'other@example.com', 'Test1234');
    expect(s.cancelEnrollment(e), isFalse);
    expect(s.enrollments, isEmpty);
  });
  test('Tickets validate fields and isolate closure by owner', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    addTearDown(s.dispose);
    expect(() => s.createTicket('', 'long enough'), throwsStateError);
    expect(() => s.createTicket('Title', 'short'), throwsStateError);
    final t = s.createTicket('  Title  ', '  Message is long enough  ');
    expect(t.subject, 'Title');
    s.register('Other', 'other@example.com', 'Test1234');
    expect(s.closeTicket(t), isFalse);
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.closeTicket(t), isTrue);
    expect(s.closeTicket(t), isFalse);
  });
  test(
    'All added fields survive restart without resetting old booking data',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      reserve(s, code: 'DEMO10');
      s.updateContactPhone('+84 912345678');
      s.changePassword(DemoSession.password, 'Changed123');
      s.enroll('basic', demoCourses.first.start(now));
      final ticket = s.createTicket('Support', 'Nội dung yêu cầu demo');
      s.closeTicket(ticket);
      await s.flush();
      s.dispose();
      final restored = open(store);
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.initialized, isTrue);
      expect(restored.points, 1388);
      expect(restored.vouchers.length, 2);
      expect(restored.enrollments.length, 1);
      expect(restored.tickets.single.closed, isTrue);
      expect(restored.contactPhone, '0912345678');
      restored.logout();
      expect(restored.login(DemoSession.email, 'Changed123'), isTrue);
      restored.cancel(
        restored.bookings.firstWhere((b) => b.voucherCode != null),
      );
      await restored.flush();
      expect(restored.vouchers.length, 3);
    },
  );
  test(
    'Previous APK snapshots without additive fields still restore',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      await s.flush();
      s.dispose();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      for (final key in [
        'demoPassword',
        'contactPhones',
        'enrollments',
        'tickets',
      ]) {
        data.remove(key);
      }
      for (final b in data['bookings'] as List) {
        (b as Map).remove('discount');
        b.remove('voucherCode');
      }
      store.value = jsonEncode(data);
      final restored = open(store);
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.initialized, isTrue);
      expect(restored.bookings.length, 2);
      expect(restored.points, 1280);
      expect(restored.vouchers.length, 3);
    },
  );
  test('Corrupt discount or extras owner reject whole snapshot without overwriting', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    reserve(s, code: 'DEMO10');
    s.createTicket('Title', 'Message sufficiently long');
    await s.flush();
    s.dispose();
    final original = store.value!;
    for (final corruptOwner in [true, false]) {
      final data = jsonDecode(original) as Map<String, dynamic>;
      if (corruptOwner) {
        (data['tickets'] as List).first['owner'] = 'unknown';
      } else {
        (data['bookings'] as List).last['discount'] = 999999;
      }
      final invalid = TestSessionStore()..value = jsonEncode(data);
      final restored = open(invalid);
      await restored.initialize();
      expect(restored.loadFailed, isTrue);
      expect(restored.bookings, isEmpty);
      expect(invalid.writes, 0);
      restored.dispose();
    }
  });
  test('Contact and name validation protect storage integrity', () {
    final s = open();
    addTearDown(s.dispose);
    expect(s.register('', 'new@example.com', 'Test1234'), isFalse);
    expect(s.register('New', 'invalid', 'Test1234'), isFalse);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.updateContactPhone('invalid'), throwsStateError);
    s.updateName('x' * 61);
    expect(s.user!.name, 'Văn Hùng');
  });
  test('Map URLs preserve Vietnamese address and required API flag', () {
    final search = venueMapUrl(DemoBooking.address);
    final directions = venueMapUrl(DemoBooking.address, directions: true);
    expect(search.scheme, 'https');
    expect(search.host, 'www.google.com');
    expect(search.queryParameters['api'], '1');
    expect(search.queryParameters['query'], DemoBooking.address);
    expect(directions.path, '/maps/dir/');
    expect(directions.queryParameters['destination'], DemoBooking.address);
    expect(directions.queryParameters.containsKey('origin'), isFalse);
  });
}
