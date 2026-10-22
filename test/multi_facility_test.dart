import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_facilities.dart';

import 'persistence_test.dart' show TestSessionStore;

const sampleFacilityProof =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
DemoFacility publishTestFacility(
  DemoSession s, {
  String name = 'Cơ sở đa sân',
  int rate = 150000,
}) {
  s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
  final f = s.saveFacility(
    FacilityProfile(
      name: name,
      sport: 'Pickleball',
      address: '12 Đường thử nghiệm',
      city: 'TP.HCM',
      district: 'Tân Phú',
      phone: DemoSession.phone,
      ownerName: 'Chủ sân',
      courtCount: 8,
      openHour: 5,
      closeHour: 23,
      baseRate: rate,
      photo: sampleFacilityProof,
      legalProof: sampleFacilityProof,
    ),
  );
  s.submitFacility(f);
  s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
  s.reviewFacility(f, approve: true);
  return f;
}

void main() {
  final now = DateTime(2026, 10, 8, 10), start = DateTime(2026, 10, 9, 9);
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  DemoBooking book(
    DemoSession s, {
    String id = 'CS0001',
    int court = 1,
    DateTime? time,
    int quote = 150000,
  }) => s.reserve(
    facilityId: id,
    court: court,
    start: time ?? start,
    hours: 1,
    contact: 'Khách thử',
    contactPhone: DemoSession.phone,
    quotedRate: quote,
  );
  test(
    'Approved facilities are independent from each other and primary calendar',
    () {
      final s = open();
      publishTestFacility(s);
      publishTestFacility(s, name: 'Cơ sở thứ hai');
      player(s);
      final a = book(s);
      final b = book(s, id: 'CS0002');
      expect(a.total, 150000);
      expect(a.venueName, 'Cơ sở đa sân');
      expect(b.facilityId, 'CS0002');
      expect(
        s.available(1, start, 1),
        isFalse,
      ); // Seeded primary booking, not either facility.
      expect(s.available(1, start, 1, facilityId: 'CS0001'), isFalse);
      expect(s.available(2, start, 1, facilityId: 'CS0001'), isTrue);
      expect(() => book(s), throwsStateError);
      expect(book(s, court: 8).court, 8);
    },
  );
  test(
    'Facility open hours, court count, quote and unpublished IDs are checked',
    () {
      final s = open();
      publishTestFacility(s);
      player(s);
      expect(() => book(s, id: 'CS9999'), throwsStateError);
      expect(() => book(s, court: 9), throwsStateError);
      expect(() => book(s, quote: 120000), throwsStateError);
      expect(book(s, time: DateTime(2026, 10, 9, 5)).start.hour, 5);
      expect(() => book(s, time: DateTime(2026, 10, 9, 23)), throwsStateError);
    },
  );
  test(
    'Suspension stops new bookings but keeps history and payment contract',
    () {
      final s = open();
      final f = publishTestFacility(s);
      player(s);
      final b = book(s);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.suspendFacility(f, true);
      player(s);
      expect(s.bookings.any((r) => r.id == b.id), isTrue);
      expect(() => book(s, court: 2), throwsStateError);
      expect(s.startTransfer(b).bookingId, b.id);
      expect(b.total, 150000);
    },
  );
  test('Primary holds do not block new facilities and dashboard excludes their bookings', () {
    final s = open();
    publishTestFacility(s);
    s.blockCourt(court: 2, start: start, hours: 1, reason: 'Bảo trì sân mẫu');
    player(s);
    book(s, court: 2);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(s.dayOverview(start).reserved, 2);
    expect(s.dayOverview(start).blocked, 1);
  });
  test('Cancellation and manager reschedule use the right venue without changing price', () {
    final s = open();
    publishTestFacility(s);
    player(s);
    final b = book(s);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.rescheduleBooking(
      b,
      court: 8,
      start: start.add(const Duration(hours: 1)),
      expectedRevision: 0,
    );
    expect(b.total, 150000);
    expect(b.court, 8);
    player(s);
    expect(s.cancel(b), isTrue);
    expect(s.available(8, b.start, 1, facilityId: 'CS0001'), isTrue);
  });
  test(
    'Durable snapshots preserve independent overlap, venue metadata and links',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      publishTestFacility(s);
      player(s);
      final b = book(s);
      await s.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      final r = restored.bookings.firstWhere((r) => r.id == b.id);
      expect(r.facilityId, 'CS0001');
      expect(r.venueName, 'Cơ sở đa sân');
      expect(r.venueCourtCount, 8);
      expect(r.total, 150000);
    },
  );
  test('Discovery, map sources and facility favorites restore without private proof', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    final f = publishTestFacility(s);
    player(s);
    expect(s.currentVenues.firstWhere((v) => v.id == f.id).localPhoto, isTrue);
    s.toggleFavorite(f.id);
    await s.flush();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.favoriteVenueIds, contains(f.id));
    expect(restored.publicFacilities.single.profile.legalProof, isEmpty);
  });
  test('Legacy booking fields migrate to primary venue', () {
    final s = open();
    player(s);
    final j = s.bookings.first.toJson();
    for (final key in [
      'facilityId',
      'venueName',
      'venueAddress',
      'sport',
      'venueCourtCount',
      'venueOpenHour',
      'venueCloseHour',
    ]) {
      j.remove(key);
    }
    final b = DemoBooking.fromJson(j);
    expect(b.facilityId, isEmpty);
    expect(b.venueName, DemoBooking.venue);
  });
  for (final invalid in ['link', 'count', 'overlap']) {
    test('Corrupt facility $invalid snapshot rejects atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      publishTestFacility(s);
      player(s);
      book(s);
      if (invalid == 'overlap') book(s, court: 2);
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      switch (invalid) {
        case 'link':
          j['bookings'].last['facilityId'] = 'CS9999';
        case 'count':
          j['bookings'].last['court'] = 9;
        case 'overlap':
          j['bookings'].last['court'] = 1;
      }
      store.value = jsonEncode(j);
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isTrue);
      expect(restored.user, isNull);
    });
  }
}
