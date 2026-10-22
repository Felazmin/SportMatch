import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
  void staff(DemoSession s, DemoRole role) => s.loginStaff(
    role,
    role == DemoRole.admin ? DemoSession.adminEmail : DemoSession.ownerEmail,
    DemoSession.password,
  );
  String complete(DemoSession s) {
    player(s);
    final b = s.reserve(
      court: 2,
      start: now.add(const Duration(days: 1)),
      hours: 1,
      contact: 'Test User',
      contactPhone: DemoSession.phone,
    );
    staff(s, DemoRole.owner);
    s.confirmVenuePayment(b);
    now = b.start;
    s.setAttendance(b.id, DemoAttendance.checkedIn);
    now = b.end;
    s.setAttendance(b.id, DemoAttendance.completed);
    player(s);
    return b.id;
  }

  test('Completed paid own booking accepts exactly one immutable review', () {
    final s = open();
    final id = complete(s);
    s.submitVenueReview(id, 4, 'Good court and service');
    expect(s.publicReviews.single.stars, 4);
    expect(s.venueRating, 4);
    expect(s.currentVenues.single.rating, 4);
    expect(
      () => s.submitVenueReview(id, 5, 'Another review'),
      throwsStateError,
    );
    expect(() => s.publicReviews.clear(), throwsUnsupportedError);
  });
  test(
    'Guest, staff, foreign accounts and unfinished bookings cannot submit',
    () {
      final s = open();
      player(s);
      final id = s.bookings.first.id;
      expect(
        () => s.submitVenueReview(id, 4, 'Test review content'),
        throwsStateError,
      );
      final finished = complete(s);
      staff(s, DemoRole.owner);
      expect(
        () => s.submitVenueReview(finished, 4, 'Test review content'),
        throwsStateError,
      );
      s.register('Other', 'other@example.com', 'Test1234');
      expect(
        () => s.submitVenueReview(finished, 4, 'Test review content'),
        throwsStateError,
      );
      s.logout();
      expect(
        () => s.submitVenueReview(finished, 4, 'Test review content'),
        throwsStateError,
      );
    },
  );
  test('Invalid stars/text do not consume one review allowance', () {
    final s = open();
    final id = complete(s);
    for (final stars in [0, 6]) {
      expect(
        () => s.submitVenueReview(id, stars, 'Test review content'),
        throwsStateError,
      );
    }
    for (final text in ['short', 'x' * 1001]) {
      expect(() => s.submitVenueReview(id, 4, text), throwsStateError);
    }
    expect(s.reviewableBookings.any((b) => b.id == id), isTrue);
    s.submitVenueReview(id, 1, 'Valid critical feedback');
  });
  test(
    'Only Admin hides/restores; author sees reason and public rating updates',
    () {
      final s = open();
      final id = complete(s);
      s.submitVenueReview(id, 2, 'Valid critical feedback');
      expect(() => s.managedReviews, throwsStateError);
      expect(
        () => s.moderateVenueReview(
          id,
          hidden: true,
          reason: 'Personal information',
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      staff(s, DemoRole.owner);
      expect(() => s.managedReviews, throwsStateError);
      staff(s, DemoRole.admin);
      expect(
        () => s.moderateVenueReview(
          id,
          hidden: true,
          reason: 'bad',
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      s.moderateVenueReview(
        id,
        hidden: true,
        reason: 'Personal information',
        expectedRevision: 0,
      );
      expect(s.publicReviews, isEmpty);
      expect(s.venueRating, 4.9);
      player(s);
      expect(s.ownReviews.single.reason, 'Personal information');
      s.register('Other', 'other@example.com', 'Test1234');
      expect(s.ownReviews, isEmpty);
      staff(s, DemoRole.admin);
      s.moderateVenueReview(
        id,
        hidden: false,
        reason: 'Reviewed and restored',
        expectedRevision: 1,
      );
      expect(s.venueRating, 2);
      expect(s.publicReviews.single.message, 'Valid critical feedback');
    },
  );
  test('Stale revision rejects replay after hide/restore cycle', () {
    final s = open();
    final id = complete(s);
    s.submitVenueReview(id, 3, 'Test review content');
    staff(s, DemoRole.admin);
    s.moderateVenueReview(
      id,
      hidden: true,
      reason: 'Personal information',
      expectedRevision: 0,
    );
    s.moderateVenueReview(
      id,
      hidden: false,
      reason: 'Reviewed and restored',
      expectedRevision: 1,
    );
    expect(
      () => s.moderateVenueReview(
        id,
        hidden: true,
        reason: 'Outdated request',
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    expect(s.publicReviews.single.revision, 2);
  });
  test(
    'Restart and failed write retry preserve review without repetition',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = complete(s);
      await s.flush();
      store.failWrite = true;
      s.submitVenueReview(id, 5, 'Test review content');
      expect(await s.flush(), isFalse);
      expect(
        () => s.submitVenueReview(id, 4, 'Duplicate content'),
        throwsStateError,
      );
      store.failWrite = false;
      await s.retrySave();
      final r = open(store);
      await r.initialize();
      expect(r.publicReviews.single.stars, 5);
      expect(r.ownReviews.single.bookingId, id);
    },
  );
  test('Legacy snapshot without reviews migrates', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    await s.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data.remove('reviews');
    store.value = jsonEncode(data);
    final r = open(store);
    await r.initialize();
    expect(r.loadFailed, isFalse);
    expect(r.publicReviews, isEmpty);
  });
  for (final corruption in ['owner', 'duplicate', 'moderation']) {
    test('Corrupt review $corruption fails restoration atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = complete(s);
      s.submitVenueReview(id, 4, 'Test review content');
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final list = data['reviews'] as List;
      final review = list.single as Map<String, dynamic>;
      if (corruption == 'owner') review['owner'] = '__admin__';
      if (corruption == 'duplicate') {
        list.add(Map<String, dynamic>.from(review));
      }
      if (corruption == 'moderation') review['hidden'] = true;
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.publicReviews, isEmpty);
      expect(r.user, isNull);
    });
  }
}
