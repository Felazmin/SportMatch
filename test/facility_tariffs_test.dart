import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facility_tariffs.dart';

import 'multi_facility_test.dart' show publishTestFacility;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 8, 10), start = DateTime(2026, 10, 9, 18);
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
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  FacilityTariffBand band({
    int court = 8,
    int from = 18,
    int to = 19,
    int rate = 200000,
    DateTime? until,
  }) => FacilityTariffBand(
    court: court,
    weekend: false,
    fromHour: from,
    toHour: to,
    rate: rate,
    surcharge: 10000,
    effectiveFrom: DateTime(2026, 10, 8),
    effectiveUntil: until,
  );
  test('Facility proposal approval affects each hour, not older prices or other venues', () {
    final s = open();
    publishTestFacility(s);
    publishTestFacility(s, name: 'Second facility');
    s.login(DemoSession.phone, DemoSession.password);
    final old = s.reserve(
      facilityId: 'CS0001',
      court: 7,
      start: start,
      hours: 1,
      contact: 'Test guest',
      contactPhone: DemoSession.phone,
    );
    owner(s);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    expect(s.bookingRates(8, start, 2, facilityId: 'CS0001'), [150000, 150000]);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    expect(s.bookingRates(8, start, 2, facilityId: 'CS0001'), [210000, 150000]);
    expect(s.bookingRates(8, start, 1, facilityId: 'CS0002'), [150000]);
    expect(old.total, 150000);
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      facilityId: 'CS0001',
      court: 8,
      start: start,
      hours: 2,
      contact: 'Test guest',
      contactPhone: DemoSession.phone,
      quotedRates: [210000, 150000],
    );
    expect(b.total, 360000);
  });
  test('Inclusive expiry and weekday/weekend boundaries use base fallback', () {
    final s = open();
    publishTestFacility(s);
    owner(s);
    s.submitFacilityTariffs('CS0001', [
      band(until: DateTime(2026, 10, 9)),
    ], expectedRevision: 0);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    expect(s.bookingRates(8, start, 1, facilityId: 'CS0001'), [210000]);
    expect(
      s.bookingRates(
        8,
        start.add(const Duration(days: 1)),
        1,
        facilityId: 'CS0001',
      ),
      [150000],
    );
    expect(
      s.bookingRates(
        8,
        start.add(const Duration(days: 7)),
        1,
        facilityId: 'CS0001',
      ),
      [150000],
    );
  });
  test('Overlaps, bounds, stale and player submissions fail atomically', () {
    final s = open();
    publishTestFacility(s);
    owner(s);
    for (final bs in [
      [band(), band()],
      [band(court: 9)],
      [band(from: 4, to: 5)],
      [band(rate: 12345)],
    ]) {
      expect(
        () => s.submitFacilityTariffs('CS0001', bs, expectedRevision: 0),
        throwsStateError,
      );
    }
    expect(s.facilityTariffPlan('CS0001').revision, 0);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    expect(
      () => s.submitFacilityTariffs('CS0001', [], expectedRevision: 1),
      throwsStateError,
    );
    admin(s);
    expect(
      () =>
          s.reviewFacilityTariffs('CS0001', expectedRevision: 0, approve: true),
      throwsStateError,
    );
    s.login(DemoSession.phone, DemoSession.password);
    expect(
      () => s.submitFacilityTariffs('CS0001', [], expectedRevision: 1),
      throwsStateError,
    );
  });
  test('Rejection preserves published prices and corrected proposal can clear bands', () {
    final s = open();
    publishTestFacility(s);
    owner(s);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    owner(s);
    s.submitFacilityTariffs('CS0001', [
      band(rate: 300000),
    ], expectedRevision: 2);
    admin(s);
    s.reviewFacilityTariffs(
      'CS0001',
      expectedRevision: 3,
      approve: false,
      note: 'Price needs correction',
    );
    expect(s.bookingRates(8, start, 1, facilityId: 'CS0001'), [210000]);
    owner(s);
    s.submitFacilityTariffs('CS0001', [], expectedRevision: 4);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 5, approve: true);
    expect(s.bookingRates(8, start, 1, facilityId: 'CS0001'), [150000]);
  });
  test('Facility revision change blocks approval but permits rejection', () {
    final s = open();
    final f = publishTestFacility(s);
    owner(s);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    admin(s);
    s.suspendFacility(f, true);
    s.suspendFacility(f, false);
    expect(
      () =>
          s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true),
      throwsStateError,
    );
    s.reviewFacilityTariffs(
      'CS0001',
      expectedRevision: 1,
      approve: false,
      note: 'Facility contract changed',
    );
  });
  test('Manual reservation detects stale facility hourly quotes', () {
    final s = open();
    publishTestFacility(s);
    owner(s);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    expect(
      () => s.manualReservation(
        facilityId: 'CS0001',
        customer: DemoSession.phone,
        court: 8,
        start: start,
        hours: 2,
        contact: 'Test guest',
        contactPhone: DemoSession.phone,
        quotedRate: 210000,
        quotedRates: [210000, 210000],
      ),
      throwsStateError,
    );
    final b = s.manualReservation(
      facilityId: 'CS0001',
      customer: DemoSession.phone,
      court: 8,
      start: start,
      hours: 2,
      contact: 'Test guest',
      contactPhone: DemoSession.phone,
      quotedRate: 210000,
      quotedRates: [210000, 150000],
    );
    expect(b.total, 360000);
  });
  test('Persisted plans restore and corrupt links reject', () async {
    final store = TestSessionStore(), s = open();
    publishTestFacility(s);
    owner(s);
    s.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    admin(s);
    s.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    // The store-backed session builds the same fixture and saves its own snapshot.
    final saved = open(store);
    await saved.initialize();
    publishTestFacility(saved);
    owner(saved);
    saved.submitFacilityTariffs('CS0001', [band()], expectedRevision: 0);
    admin(saved);
    saved.reviewFacilityTariffs('CS0001', expectedRevision: 1, approve: true);
    await saved.flush();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    admin(restored);
    expect(restored.bookingRates(8, start, 1, facilityId: 'CS0001'), [210000]);
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    (data['facilityTariffs'] as List).first['facilityId'] = 'CS9999';
    store.value = jsonEncode(data);
    final bad = open(store);
    await bad.initialize();
    expect(bad.loadFailed, isTrue);
  });
}
