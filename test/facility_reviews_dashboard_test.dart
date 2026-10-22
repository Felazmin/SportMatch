import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'multi_facility_test.dart' show publishTestFacility;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
  DemoSession open() {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  test(
    'Paid completed facility booking can be reviewed and ratings stay scoped',
    () {
      final s = open();
      publishTestFacility(s);
      publishTestFacility(s, name: 'Second facility');
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        facilityId: 'CS0001',
        court: 8,
        start: DateTime(2026, 10, 9, 12),
        hours: 1,
        contact: 'Test guest',
        contactPhone: DemoSession.phone,
      );
      owner(s);
      s.confirmVenuePayment(b);
      now = b.start;
      s.setAttendance(b.id, DemoAttendance.checkedIn);
      now = b.end;
      s.setAttendance(b.id, DemoAttendance.completed);
      s.login(DemoSession.phone, DemoSession.password);
      s.submitVenueReview(b.id, 4, 'Good venue and service');
      expect(s.publicReviews, isEmpty);
      expect(s.publicReviewsForFacility('CS0001').single.stars, 4);
      expect(s.facilityRating('CS0001'), 4);
      expect(s.facilityRating('CS0002'), 0);
      expect(s.currentVenues.singleWhere((v) => v.id == 'CS0001').rating, 4);
      expect(
        () => s.submitVenueReview(b.id, 5, 'Second venue review'),
        throwsStateError,
      );
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.moderateVenueReview(
        b.id,
        hidden: true,
        reason: 'Review needs moderation',
        expectedRevision: 0,
      );
      expect(s.facilityRating('CS0001'), 0);
      expect(s.allPublicReviews, isEmpty);
      expect(s.reviewVenueName(b.id), 'Cơ sở đa sân');
    },
  );
  test(
    'Facility day metrics and all-facility totals use their own hours/courts',
    () {
      final s = open();
      publishTestFacility(s);
      owner(s);
      final date = DateTime(2026, 10, 9);
      final b = s.manualReservation(
        facilityId: 'CS0001',
        customer: DemoSession.phone,
        court: 8,
        start: DateTime(2026, 10, 9, 5),
        hours: 2,
        contact: 'Test guest',
        contactPhone: DemoSession.phone,
        quotedRate: 150000,
      );
      s.confirmVenuePayment(b);
      s.blockCourt(
        facilityId: 'CS0001',
        court: 7,
        start: DateTime(2026, 10, 9, 6),
        hours: 3,
        reason: 'Maintenance test',
      );
      final primary = s.dayOverview(date),
          facility = s.dayOverview(date, facilityId: 'CS0001'),
          all = s.allFacilitiesOverview(date);
      expect(facility.capacity, 144);
      expect(facility.reserved, 2);
      expect(facility.blocked, 3);
      expect(facility.confirmedValue, 300000);
      expect(facility.bookings.single.id, b.id);
      expect(all.capacity, primary.capacity + 144);
      expect(all.blocked, primary.blocked + 3);
      expect(all.reserved, primary.reserved + 2);
      expect(all.confirmedValue, primary.confirmedValue + 300000);
    },
  );
  test('Suspended venue retains history/value but no active capacity and player denied', () {
    final s = open();
    final f = publishTestFacility(s);
    owner(s);
    final b = s.manualReservation(
      facilityId: 'CS0001',
      customer: DemoSession.phone,
      court: 8,
      start: DateTime(2026, 10, 9, 5),
      hours: 1,
      contact: 'Test guest',
      contactPhone: DemoSession.phone,
      quotedRate: 150000,
    );
    s.confirmVenuePayment(b);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.suspendFacility(f, true);
    final d = s.dayOverview(b.start, facilityId: f.id);
    expect(d.capacity, 0);
    expect(d.bookings.single.id, b.id);
    expect(d.confirmedValue, 150000);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.allFacilitiesOverview(b.start), throwsStateError);
  });
}
