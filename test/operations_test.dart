import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_operations.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 6, 10);
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void player(DemoSession s) =>
      s.login(DemoSession.phone, DemoSession.password);
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
  DemoBooking reserve(
    DemoSession s, {
    int court = 2,
    int hour = 12,
    String? voucher,
  }) => s.reserve(
    court: court,
    start: DateTime(2026, 10, 7, hour),
    hours: 1,
    contact: 'Test',
    contactPhone: DemoSession.phone,
    voucherCode: voucher,
  );
  CourtSettings settings({bool open = true}) => CourtSettings(
    rates: [150000, 180000, 200000],
    enabled: [true, open, true],
  );
  test('Stale price quote is rejected without adding a booking', () {
    final s = make();
    owner(s);
    s.submitCourtSettings(settings());
    admin(s);
    s.reviewCourtSettings(approve: true);
    player(s);
    final before = s.bookings.length;
    expect(
      () => s.reserve(
        court: 2,
        start: DateTime(2026, 10, 7, 12),
        hours: 1,
        contact: 'Test',
        contactPhone: DemoSession.phone,
        quotedRate: 120000,
      ),
      throwsStateError,
    );
    expect(s.bookings.length, before);
  });
  test('Only owner submits and only admin approves; published price remains until approval', () {
    final s = make();
    player(s);
    expect(() => s.submitCourtSettings(settings()), throwsStateError);
    owner(s);
    s.submitCourtSettings(settings());
    expect(s.courtRate(2), 120000);
    expect(() => s.submitCourtSettings(settings()), throwsStateError);
    expect(() => s.reviewCourtSettings(approve: true), throwsStateError);
    admin(s);
    expect(() => s.submitCourtSettings(settings()), throwsStateError);
    s.reviewCourtSettings(approve: true);
    expect(s.courtRate(2), 180000);
    expect(s.draftCourts, isNull);
    expect(s.operationAudit.length, 2);
  });
  test('Rejected change keeps old prices and can be corrected', () {
    final s = make();
    owner(s);
    s.submitCourtSettings(settings());
    admin(s);
    expect(
      () => s.reviewCourtSettings(approve: false, note: 'No'),
      throwsStateError,
    );
    s.reviewCourtSettings(approve: false, note: 'Kiểm tra đơn giá');
    expect(s.courtRate(2), 120000);
    owner(s);
    s.submitCourtSettings(settings());
    admin(s);
    s.reviewCourtSettings(approve: true);
    expect(s.courtReviewState, 'approved');
  });
  test('Approved prices apply to new bookings, vouchers and catalog but not history', () {
    final s = make();
    player(s);
    final old = reserve(s);
    owner(s);
    s.submitCourtSettings(settings());
    admin(s);
    s.reviewCourtSettings(approve: true);
    player(s);
    final next = reserve(s, hour: 14, voucher: 'DEMO10');
    expect(old.total, 120000);
    expect(next.rate, 180000);
    expect(next.total, 162000);
    expect(s.currentVenues.single.price, 150000);
    expect(DemoBooking.fromJson(next.toJson()).total, next.total);
  });
  test(
    'Closed court denies new reservations without cancelling existing bookings',
    () {
      final s = make();
      player(s);
      final old = reserve(s);
      owner(s);
      s.submitCourtSettings(settings(open: false));
      admin(s);
      s.reviewCourtSettings(approve: true);
      expect(old.cancelled, isFalse);
      expect(s.available(2, DateTime(2026, 10, 7, 14), 1), isFalse);
      player(s);
      expect(() => reserve(s, hour: 14), throwsStateError);
      expect(s.available(0, DateTime(2026, 10, 7, 14), 1), isFalse);
    },
  );
  test(
    'Court rates reject invalid lengths, range and fractional increments',
    () {
      for (final rates in [
        [0, 120000, 120000],
        [12345, 120000, 120000],
        [1000001, 120000, 120000],
        [120000],
      ]) {
        expect(
          () => CourtSettings(rates: rates, enabled: [true, true, true]),
          throwsFormatException,
        );
      }
      expect(
        () => CourtSettings(rates: [120000, 120000, 120000], enabled: [true]),
        throwsFormatException,
      );
    },
  );
  test('Employee create edit and inactive state preserve stable identity', () {
    final s = make();
    player(s);
    expect(
      () => s.saveEmployee(
        name: 'Test',
        phone: DemoSession.phone,
        job: 'Lễ tân',
        active: true,
      ),
      throwsStateError,
    );
    owner(s);
    s.saveEmployee(
      name: 'Test',
      phone: '+84 901234567',
      job: 'Lễ tân',
      active: true,
    );
    final id = s.employees.single.id;
    s.saveEmployee(
      id: id,
      name: 'Updated',
      phone: DemoSession.phone,
      job: 'Thu ngân',
      active: false,
    );
    expect(s.employees.single.id, id);
    expect(s.employees.single.active, isFalse);
    expect(
      () => s.saveEmployee(
        name: 'Another',
        phone: DemoSession.phone,
        job: 'Lễ tân',
        active: true,
      ),
      throwsStateError,
    );
    expect(
      () => s.saveEmployee(name: '', phone: 'bad', job: 'X', active: true),
      throwsFormatException,
    );
    expect(s.employees.length, 1);
  });
  test('Admin blocks phone and email aliases without deleting history', () {
    final s = make();
    player(s);
    final old = reserve(s);
    owner(s);
    expect(
      () => s.setPlayerBlocked(
        DemoSession.phone,
        true,
        password: DemoSession.password,
        reason: 'Demo access review',
        expectedBlocked: false,
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    admin(s);
    s.setPlayerBlocked(
      DemoSession.phone,
      true,
      password: DemoSession.password,
      reason: 'Demo access review',
      expectedBlocked: false,
      expectedRevision: 0,
    );
    s.logout();
    expect(s.login(DemoSession.phone, DemoSession.password), isFalse);
    expect(s.login(DemoSession.email, DemoSession.password), isFalse);
    admin(s);
    s.setPlayerBlocked(
      DemoSession.phone,
      false,
      password: DemoSession.password,
      reason: 'Demo access review',
      expectedBlocked: true,
      expectedRevision: 1,
    );
    player(s);
    expect(s.bookings, contains(old));
  });
  test('Moderation hides and restores posts; deleting hidden post removes references', () {
    final s = make();
    player(s);
    final p = s.createPost('public', 'Test nội dung');
    owner(s);
    expect(() => s.setPostHidden(p.id, true), throwsStateError);
    admin(s);
    s.setPostHidden(p.id, true);
    expect(s.posts, isEmpty);
    expect(s.moderationPosts.single, p);
    s.setPostHidden(p.id, false);
    expect(s.posts.single, p);
    s.setPostHidden(p.id, true);
    player(s);
    expect(s.deletePost(p), isTrue);
    admin(s);
    expect(s.moderationPosts, isEmpty);
  });
  test(
    'Operations, price snapshots, blocked users and moderation survive restart',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      player(s);
      final old = reserve(s);
      final p = s.createPost('public', 'Test nội dung');
      owner(s);
      s.saveEmployee(
        name: 'Test',
        phone: DemoSession.phone,
        job: 'Lễ tân',
        active: true,
      );
      s.submitCourtSettings(settings());
      admin(s);
      s.reviewCourtSettings(approve: true);
      s.setPostHidden(p.id, true);
      s.setPlayerBlocked(
        DemoSession.phone,
        true,
        password: DemoSession.password,
        reason: 'Demo access review',
        expectedBlocked: false,
        expectedRevision: 0,
      );
      await s.flush();
      final restored = make(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(restored.courtRate(2), 180000);
      expect(restored.employees.length, 1);
      expect(
        restored.managedBookings.firstWhere((b) => b.id == old.id).total,
        120000,
      );
      expect(restored.isBlocked(DemoSession.phone), isTrue);
      expect(restored.posts, isEmpty);
      expect(restored.operationAudit.length, 5);
    },
  );
  test(
    'Failed save can retry without duplicating employee or audit entry',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      owner(s);
      await s.flush();
      store.failWrite = true;
      s.saveEmployee(
        name: 'Test',
        phone: DemoSession.phone,
        job: 'Lễ tân',
        active: true,
      );
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      final restored = make(store);
      await restored.initialize();
      expect(restored.employees.length, 1);
      expect(restored.operationAudit.length, 1);
    },
  );
  test('Old snapshots without operations and booking rate migrate', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    player(s);
    await s.flush();
    final data = jsonDecode(store.value!) as Map<String, dynamic>;
    data.remove('operations');
    for (final b in data['bookings'] as List) {
      (b as Map).remove('rate');
    }
    store.value = jsonEncode(data);
    final restored = make(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.courtRate(1), 120000);
  });
  for (final corrupt in ['rate', 'blocked', 'hidden', 'employee', 'state']) {
    test(
      'Corrupt $corrupt operations rejects entire snapshot atomically',
      () async {
        final store = TestSessionStore();
        final s = make(store);
        await s.initialize();
        owner(s);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        final o = data['operations'] as Map<String, dynamic>;
        switch (corrupt) {
          case 'rate':
            (o['published'] as Map)['rates'] = [1, 120000, 120000];
          case 'blocked':
            o['blocked'] = ['ghost@example.com'];
          case 'hidden':
            o['hiddenPosts'] = ['BD9999'];
          case 'employee':
            o['nextEmployee'] = 0;
          case 'state':
            o['reviewState'] = 'pending';
        }
        store.value = jsonEncode(data);
        final restored = make(store);
        await restored.initialize();
        expect(restored.loadFailed, isTrue);
        expect(restored.user, isNull);
        expect(restored.publishedCourts.rates, [120000, 120000, 120000]);
      },
    );
  }
}
