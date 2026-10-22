import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/demo/demo_cancellation_policy.dart';
import 'package:test_do_an/demo/demo_facilities.dart';

import 'multi_facility_test.dart' show publishTestFacility, sampleFacilityProof;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime(2026, 10, 8, 10);
  DemoSession open({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(store: store, now: clock ?? () => date);
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
  CancellationPolicy policy({int late = 25, int minimum = 1}) =>
      CancellationPolicy(
        thresholdHours: 6,
        earlyPercent: 90,
        latePercent: late,
        minimumHours: minimum,
      );
  DemoBooking book(DemoSession s, {String id = '', int court = 2}) => s.reserve(
    facilityId: id,
    court: court,
    start: date.add(const Duration(days: 1, hours: 2)),
    hours: 1,
    contact: 'Guest',
    contactPhone: DemoSession.phone,
  );
  void pay(DemoSession s, DemoBooking b) {
    player(s);
    s.startTransfer(b);
    s.saveProofDraft(b, base64Decode(sampleFacilityProof));
    s.submitProof(b, 'DEMO-${b.id}');
    owner(s);
    s.reviewPayment(b, approve: true);
  }

  test('Policy ranges, exact boundaries and integer rounding', () {
    final p = policy();
    final start = date.add(const Duration(hours: 6));
    expect(p.refundAmount(100001, start, date), 90000);
    expect(
      p.refundAmount(100001, start, date.add(const Duration(seconds: 1))),
      25000,
    );
    expect(
      p.canRequest(start, start.subtract(const Duration(hours: 1))),
      isTrue,
    );
    expect(
      p.canRequest(start, start.subtract(const Duration(minutes: 59))),
      isFalse,
    );
    expect(p.canRequest(start, start), isFalse);
    expect(
      () => CancellationPolicy(
        thresholdHours: 0,
        earlyPercent: 95,
        latePercent: 50,
      ),
      throwsFormatException,
    );
    expect(
      () => CancellationPolicy(
        thresholdHours: 2,
        earlyPercent: 40,
        latePercent: 50,
      ),
      throwsFormatException,
    );
    expect(
      () => CancellationPolicy(
        thresholdHours: 2,
        earlyPercent: 95,
        latePercent: 50,
        minimumHours: 3,
      ),
      throwsFormatException,
    );
    expect(CancellationPolicy.fromJson(p.toJson()), p);
  });
  test('Primary changes need admin password and current revision', () {
    final s = open();
    owner(s);
    expect(
      () => s.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: DemoSession.password,
      ),
      throwsStateError,
    );
    admin(s);
    expect(
      () => s.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: 'bad',
      ),
      throwsStateError,
    );
    expect(s.primaryCancellationRevision, 0);
    s.setPrimaryCancellationPolicy(
      policy(),
      expectedRevision: 0,
      password: DemoSession.password,
    );
    expect(s.primaryCancellationRevision, 1);
    expect(
      () => s.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: DemoSession.password,
      ),
      throwsStateError,
    );
  });
  test(
    'Existing primary contracts stay unchanged; stale quoted terms reject',
    () {
      final s = open();
      player(s);
      final old = book(s);
      admin(s);
      s.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: DemoSession.password,
      );
      player(s);
      final fresh = book(s, court: 3);
      expect(old.cancellationPolicy, const CancellationPolicy.standard());
      expect(fresh.cancellationPolicy, policy());
      expect(
        () => s.reserve(
          court: 1,
          start: fresh.start,
          hours: 1,
          contact: 'Guest',
          contactPhone: DemoSession.phone,
          quotedCancellationPolicy: const CancellationPolicy.standard(),
        ),
        throwsStateError,
      );
    },
  );
  test('Facility changes need review and do not affect primary or old facility contracts', () {
    final s = open(), f = publishTestFacility(open());
    final own = publishTestFacility(s);
    player(s);
    final old = book(s, id: own.id);
    owner(s);
    s.saveFacility(
      FacilityProfile.fromJson({
        ...own.draft.toJson(),
        'cancellationPolicy': policy().toJson(),
      }),
      facility: own,
      expectedRevision: own.revision,
    );
    expect(
      s.publicFacilities.single.profile.cancellationPolicy,
      const CancellationPolicy.standard(),
    );
    s.submitFacility(own);
    admin(s);
    s.reviewFacility(own, approve: true);
    player(s);
    final fresh = book(s, id: own.id, court: 3);
    expect(old.cancellationPolicy, const CancellationPolicy.standard());
    expect(fresh.cancellationPolicy, policy());
    expect(book(s).cancellationPolicy, const CancellationPolicy.standard());
    expect(f.draft.cancellationPolicy, const CancellationPolicy.standard());
  });
  test('Refund uses request time and agreed policy, not review time or latest settings', () {
    var clock = date;
    final s = open(clock: () => clock);
    admin(s);
    s.setPrimaryCancellationPolicy(
      policy(),
      expectedRevision: 0,
      password: DemoSession.password,
    );
    player(s);
    final b = book(s);
    pay(s, b);
    clock = b.start.subtract(const Duration(hours: 6));
    player(s);
    s.requestCancellation(b, 'Cannot attend');
    admin(s);
    s.setPrimaryCancellationPolicy(
      policy(late: 10),
      expectedRevision: 1,
      password: DemoSession.password,
    );
    clock = b.start.subtract(const Duration(minutes: 30));
    s.reviewCancellation(b, approve: true);
    expect(s.paymentFor(b)!.refundAmount, b.total * 90 ~/ 100);
  });
  test(
    'Minimum notice guards unpaid direct cancel and paid cancellation requests',
    () {
      var clock = date;
      final s = open(clock: () => clock);
      admin(s);
      s.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: DemoSession.password,
      );
      player(s);
      final unpaid = book(s), paid = book(s, court: 3);
      pay(s, paid);
      player(s);
      clock = paid.start.subtract(const Duration(minutes: 59));
      expect(s.cancel(unpaid), isFalse);
      expect(
        () => s.requestCancellation(paid, 'Cannot attend'),
        throwsStateError,
      );
      clock = paid.start.subtract(const Duration(hours: 1));
      expect(s.cancel(unpaid), isTrue);
      s.requestCancellation(paid, 'Cannot attend');
    },
  );
  test('Manual reservations capture facility terms', () {
    final s = open();
    final own = publishTestFacility(s);
    owner(s);
    s.saveFacility(
      FacilityProfile.fromJson({
        ...own.draft.toJson(),
        'cancellationPolicy': policy().toJson(),
      }),
      facility: own,
    );
    s.submitFacility(own);
    admin(s);
    s.reviewFacility(own, approve: true);
    final b = s.manualReservation(
      customer: DemoSession.phone,
      facilityId: own.id,
      court: 7,
      start: date.add(const Duration(days: 1, hours: 2)),
      hours: 1,
      contact: 'Guest',
      contactPhone: DemoSession.phone,
      quotedRate: 150000,
    );
    expect(b.cancellationPolicy, policy());
  });
  test(
    'Policy snapshots survive retry/restart and legacy contracts migrate',
    () async {
      final store = TestSessionStore(), s = open(store: TestSessionStore());
      await s.initialize();
      final target = open(store: store);
      await target.initialize();
      admin(target);
      target.setPrimaryCancellationPolicy(
        policy(),
        expectedRevision: 0,
        password: DemoSession.password,
      );
      player(target);
      final b = book(target);
      await target.flush();
      final restored = open(store: store);
      await restored.initialize();
      expect(restored.primaryCancellationPolicy, policy());
      expect(
        restored.bookings.singleWhere((v) => v.id == b.id).cancellationPolicy,
        policy(),
      );
      final old = b.toJson()..remove('cancellationPolicy');
      expect(
        DemoBooking.fromJson(old).cancellationPolicy,
        const CancellationPolicy.standard(),
      );
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      (j['primaryCancellationPolicy'] as Map)['earlyPercent'] = 101;
      store.value = jsonEncode(j);
      final corrupt = open(store: store);
      await corrupt.initialize();
      expect(corrupt.loadFailed, isTrue);
      expect(corrupt.initialized, isFalse);
    },
  );
}
