import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_operations.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 7, 8);
  CourtTariff band({
    bool weekend = false,
    int from = 12,
    int to = 14,
    int rate = 180000,
    DateTime? date,
  }) => CourtTariff(
    court: 2,
    weekend: weekend,
    fromHour: from,
    toHour: to,
    rate: rate,
    effectiveFrom: date ?? bookingDay(now),
  );
  CourtSettings settings(List<CourtTariff> tariffs) => CourtSettings(
    rates: [120000, 120000, 120000],
    enabled: [true, true, true],
    tariffs: tariffs,
  );
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

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
  void publish(DemoSession s, List<CourtTariff> tariffs) {
    owner(s);
    s.submitCourtSettings(settings(tariffs));
    admin(s);
    s.reviewCourtSettings(approve: true);
  }

  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  DemoBooking reserve(DemoSession s, {String? voucher, List<int>? quote}) =>
      s.reserve(
        court: 2,
        start: DateTime(2026, 10, 8, 11),
        hours: 3,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        voucherCode: voucher,
        quotedRates: quote,
      );

  test('Weekday/weekend and start/end boundaries use base fallback', () {
    final c = settings([band(), band(weekend: true, rate: 200000)]);
    expect(c.rateAt(2, DateTime(2026, 10, 8, 11)), 120000);
    expect(c.rateAt(2, DateTime(2026, 10, 8, 12)), 180000);
    expect(c.rateAt(2, DateTime(2026, 10, 8, 14)), 120000);
    expect(c.rateAt(2, DateTime(2026, 10, 10, 12)), 200000);
    expect(c.rateAt(1, DateTime(2026, 10, 8, 12)), 120000);
  });
  test('Future effective day does not affect earlier reservations', () {
    final c = settings([band(date: DateTime(2026, 10, 9))]);
    expect(c.rateAt(2, DateTime(2026, 10, 8, 12)), 120000);
    expect(c.rateAt(2, DateTime(2026, 10, 9, 12)), 180000);
  });
  test('Pending/rejected tariffs do not publish and roles are guarded', () {
    final s = make();
    player(s);
    expect(() => s.submitCourtSettings(settings([band()])), throwsStateError);
    owner(s);
    s.submitCourtSettings(settings([band()]));
    expect(s.courtRate(2, DateTime(2026, 10, 8, 12)), 120000);
    expect(() => s.reviewCourtSettings(approve: true), throwsStateError);
    admin(s);
    s.reviewCourtSettings(approve: false, note: 'Sai khung giờ');
    expect(s.courtRate(2, DateTime(2026, 10, 8, 12)), 120000);
  });
  test('Discovery minimum excludes tariffs beyond the booking horizon', () {
    final s = make();
    publish(s, [band(rate: 10000, date: DateTime(2026, 11, 1))]);
    expect(s.minimumCourtRate, 120000);
    publish(s, [band(rate: 10000)]);
    expect(s.minimumCourtRate, 10000);
  });
  test('Failed save retry keeps one pricing proposal', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    owner(s);
    store.failWrite = true;
    s.submitCourtSettings(settings([band()]));
    expect(await s.flush(), isFalse);
    expect(s.draftCourts!.tariffs.length, 1);
    store.failWrite = false;
    await s.retrySave();
    final restored = make(store);
    await restored.initialize();
    owner(restored);
    expect(restored.courtReviewState, 'pending');
    expect(restored.draftCourts!.tariffs.length, 1);
  });
  test('Cross-band price and voucher use the summed hourly quote', () {
    final s = make();
    publish(s, [band()]);
    player(s);
    final b = reserve(s, voucher: 'DEMO10');
    expect(b.hourlyRates, [120000, 180000, 180000]);
    expect(b.subtotal, 480000);
    expect(b.discount, 48000);
    expect(b.total, 432000);
  });
  test('Changes in later hours reject stale quote even when first hour is unchanged', () {
    final s = make();
    final quote = s.bookingRates(2, DateTime(2026, 10, 8, 11), 3);
    publish(s, [band()]);
    player(s);
    expect(() => reserve(s, quote: quote), throwsStateError);
    expect(() => reserve(s, quote: [120000]), throwsStateError);
  });
  test('Existing booking and rescheduling preserve hourly price contract', () {
    final s = make();
    publish(s, [band()]);
    player(s);
    final b = reserve(s);
    publish(s, [band(rate: 200000)]);
    expect(b.total, 480000);
    s.rescheduleBooking(
      b,
      court: 3,
      start: DateTime(2026, 10, 9, 15),
      expectedRevision: 0,
    );
    expect(b.hourlyRates, [120000, 180000, 180000]);
    expect(b.total, 480000);
  });
  test('Manual reservation applies tariffs and checks all quoted hours', () {
    final s = make();
    publish(s, [band()]);
    owner(s);
    expect(
      () => s.manualReservation(
        customer: DemoSession.phone,
        court: 2,
        start: DateTime(2026, 10, 8, 11),
        hours: 3,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        quotedRate: 120000,
        quotedRates: [120000, 120000, 120000],
      ),
      throwsStateError,
    );
    final b = s.manualReservation(
      customer: DemoSession.phone,
      court: 2,
      start: DateTime(2026, 10, 8, 11),
      hours: 3,
      contact: 'Test',
      contactPhone: DemoSession.phone,
      quotedRate: 120000,
      quotedRates: [120000, 180000, 180000],
    );
    expect(b.total, 480000);
  });
  test('Overlapping periods reject; adjacent periods and different day groups pass', () {
    expect(
      () => settings([band(), band(from: 13, to: 15)]),
      throwsFormatException,
    );
    expect(
      settings([band(), band(from: 14, to: 16), band(weekend: true)])
          .tariffs
          .length,
      3,
    );
    expect(
      () => settings(List.generate(37, (_) => band())),
      throwsFormatException,
    );
  });
  for (final args in [
    (5, 12, 120000),
    (12, 12, 120000),
    (12, 23, 120000),
    (12, 14, 9000),
    (12, 14, 10001),
  ]) {
    test('Invalid range/rate $args is rejected', () {
      expect(
        () => band(from: args.$1, to: args.$2, rate: args.$3),
        throwsFormatException,
      );
    });
  }
  test('Tariffs and immutable hourly prices survive restart', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    publish(s, [band()]);
    player(s);
    final b = reserve(s);
    await s.flush();
    final restored = make(store);
    await restored.initialize();
    expect(restored.bookings.singleWhere((r) => r.id == b.id).total, 480000);
    expect(restored.courtRate(2, DateTime(2026, 10, 8, 12)), 180000);
  });
  test('Legacy settings/bookings restore with flat prices', () {
    final c = CourtSettings.fromJson({
      'rates': [120000, 120000, 120000],
      'enabled': [true, true, true],
    });
    expect(c.tariffs, isEmpty);
    final b = DemoBooking(
      id: 'NVH0009',
      owner: DemoSession.phone,
      court: 2,
      start: DateTime(2026, 10, 8, 11),
      hours: 2,
      contact: 'Test',
      phone: DemoSession.phone,
    );
    final j = b.toJson()..remove('hourlyRates');
    expect(DemoBooking.fromJson(j).total, 240000);
  });
  test('Invalid tariff snapshot is rejected atomically', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    publish(s, [band()]);
    await s.flush();
    final j = jsonDecode(store.value!) as Map<String, dynamic>;
    j['operations']['published']['tariffs'][0]['toHour'] = 5;
    store.value = jsonEncode(j);
    final restored = make(store);
    await restored.initialize();
    expect(restored.loadFailed, isTrue);
    expect(restored.publishedCourts.tariffs, isEmpty);
  });
  test('Invalid hourly arrays cannot restore', () {
    final b = DemoBooking(
      id: 'NVH0009',
      owner: DemoSession.phone,
      court: 2,
      start: DateTime(2026, 10, 8, 11),
      hours: 2,
      contact: 'Test',
      phone: DemoSession.phone,
    );
    for (final rates in [
      <int>[],
      [120000],
      [180000, 120000],
      [120000, 10001],
    ]) {
      expect(
        () => DemoBooking.fromJson(b.toJson()..['hourlyRates'] = rates),
        throwsFormatException,
      );
    }
  });
}
