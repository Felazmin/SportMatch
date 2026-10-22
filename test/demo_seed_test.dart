import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/demo/demo_seed_data.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 10, 10);
  final proof = encodeProof(
    Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS1kAAAAASUVORK5CYII=',
      ),
    ),
  );
  DemoSession open(TestSessionStore store) => DemoSession(
    store: store,
    now: () => now,
    demoFixtureLoader: () async => (photo: proof, proof: proof),
  );
  Map<String, dynamic> data(TestSessionStore store) =>
      jsonDecode(store.value!) as Map<String, dynamic>;

  test('Fixture snapshot passes the persistence validator', () {
    final s = DemoSession(now: () => now);
    expect(s.installDemoFixtures(proof, proof: proof), isTrue);
    s.dispose();
  });

  test('Production-style initialization installs linked four-role scenarios and restores', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    expect(s.loadFailed, isFalse);
    expect(s.installedDemoSeedVersion, demoSeedVersion);
    expect(await s.flush(), isTrue);
    final d = data(store);
    expect((d['facilities'] as List).length, 5);
    expect((d['bookings'] as List).length, 25);
    expect((d['employeeAccess'] as Map).length, 2);
    expect((d['shifts'] as List).length, 8);
    expect((d['activities'] as List).length, 6);
    expect((d['courtTypes'] as List).length, 5);
    expect((d['playGroups'] as List).length, 5);
    expect((d['participations'] as List).length, 4);
    expect((d['matches'] as List).length, 1);
    s.dispose();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(data(store), equals(d));
    restored.dispose();
  });

  test(
    'Ready-made manager signs in directly with limited delegated authority',
    () async {
      final store = TestSessionStore();
      var clock = now;
      final s = DemoSession(
        store: store,
        now: () => clock,
        demoFixtureLoader: () async => (photo: proof, proof: proof),
      );
      await s.initialize();
      expect(s.loginEmployee(demoManagerPhone, demoSeedPassword), isTrue);
      expect(s.activeEmployee, isNotNull);
      expect(s.user, isNull);
      expect(s.employeeCan('schedule'), isTrue);
      expect(s.employeeCan('attendance'), isTrue);
      expect(s.employeeCan('onsite'), isTrue);
      expect(s.employeeSchedule, isNotEmpty);
      expect(s.ownEmployeeShifts.length, 4);
      expect(() => s.managedFacilities, throwsStateError);
      expect(() => s.managedUsers, throwsStateError);
      final paid = (data(store)['payments'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (p) => p['state'] == 'approved' && p['cancellation'] == 'none',
          );
      final record = s.employeeSchedule.firstWhere(
        (r) => r.id == paid['bookingId'],
      );
      clock = record.start;
      s.employeeSetAttendance(
        record.id,
        DemoAttendance.checkedIn,
        record.attendance,
      );
      expect(
        s.employeeSchedule.firstWhere((r) => r.id == record.id).attendance,
        DemoAttendance.checkedIn,
      );
      s.dispose();
    },
  );

  test('Read-only employee cannot check in or collect payment', () async {
    final s = open(TestSessionStore());
    await s.initialize();
    expect(s.loginEmployee(demoViewerPhone, demoSeedPassword), isTrue);
    expect(s.employeeCan('schedule'), isTrue);
    expect(s.employeeCan('attendance'), isFalse);
    final record = s.employeeSchedule.first;
    expect(
      () => s.employeeSetAttendance(
        record.id,
        DemoAttendance.checkedIn,
        record.attendance,
      ),
      throwsStateError,
    );
    expect(() => s.employeeConfirmPayment(record.id), throwsStateError);
    s.dispose();
  });

  test(
    'Owner and admin can process seeded queues and decisions survive restart',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final pendingBooking = s.managedBookings.firstWhere(
        (b) => s.paymentFor(b)?.state == DemoPaymentState.pending,
      );
      s.reviewPayment(pendingBooking, approve: true);
      expect(s.paymentFor(pendingBooking)!.state, DemoPaymentState.approved);
      expect(s.payoutBalance, greaterThan(0));
      final manual = s.managedBookings.lastWhere(
        (b) => s.paymentFor(b) == null && b.start.isAfter(now),
      );
      s.confirmVenuePayment(manual);
      expect(s.paymentFor(manual)!.atVenue, isTrue);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      final pendingFacility = s.managedFacilities.firstWhere(
        (f) => f.state == 'pending',
      );
      s.reviewFacility(
        pendingFacility,
        approve: true,
        expectedRevision: pendingFacility.revision,
      );
      final group = s.managedPlayGroups.firstWhere((g) => g.state == 'pending');
      s.transitionPlayGroup(group.id, 'approved', group.revision);
      final activity = s.managedActivities.firstWhere(
        (a) => a.state == 'pending',
      );
      s.transitionActivity(activity.id, 'approved', activity.revision);
      final courtType = s.managedCourtTypes.firstWhere(
        (t) => t.state == 'pending',
      );
      s.transitionCourtType(courtType.id, 'approved', courtType.revision);
      await s.flush();
      final snapshot = store.value;
      s.dispose();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(
        restored.managedFacilities
            .firstWhere((f) => f.id == pendingFacility.id)
            .state,
        'approved',
      );
      expect(store.value, snapshot);
      restored.dispose();
    },
  );

  test('Customer has isolated histories, payment/cancellation cases and blocked account', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    expect(s.login(DemoSession.phone, DemoSession.password), isTrue);
    expect(s.bookings.length, 17);
    expect(s.isFavorite('cong-thuong'), isTrue);
    expect(s.bookings.where((b) => b.cancelled).length, 2);
    final payments = (data(store)['payments'] as List)
        .cast<Map<String, dynamic>>();
    expect(
      payments.map((p) => p['state']).toSet(),
      containsAll(['awaitingProof', 'pending', 'rejected', 'approved']),
    );
    expect(
      payments.map((p) => p['refund']).toSet(),
      containsAll(['none', 'pending', 'recorded']),
    );
    s.logout();
    expect(s.login('0909000011', demoSeedPassword), isTrue);
    expect(s.bookings.length, 2);
    s.logout();
    expect(s.login('0909000013', demoSeedPassword), isFalse);
    s.dispose();
  });

  test('Existing profile, password, employee permissions and bookings survive migration', () async {
    final store = TestSessionStore();
    final original = DemoSession(store: store, now: () => now);
    await original.initialize();
    original.login(DemoSession.phone, DemoSession.password);
    original.updateName('Existing customer');
    original.changePassword(DemoSession.password, 'Changed1234');
    original.reserve(
      court: 2,
      start: DateTime(2026, 10, 11, 8),
      hours: 1,
      contact: 'Existing customer',
      contactPhone: DemoSession.phone,
    );
    await original.flush();
    final before = data(store);
    original.dispose();
    final migrated = open(store);
    await migrated.initialize();
    expect(migrated.loadFailed, isFalse);
    expect(migrated.user!.name, 'Existing customer');
    expect(data(store)['demoPassword'], 'Changed1234');
    final afterBookings = (data(store)['bookings'] as List)
        .cast<Map<String, dynamic>>();
    for (final b in before['bookings'] as List) {
      expect(afterBookings.singleWhere((a) => a['id'] == b['id']), equals(b));
    }
    expect(migrated.installDemoFixtures(proof, proof: proof), isFalse);
    migrated.dispose();
  });

  test('Disabled employee and administrator decisions are not resurrected on restart', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    final employee = s.employees.firstWhere((e) => e.phone == demoManagerPhone);
    s.saveEmployee(
      id: employee.id,
      name: employee.name,
      phone: employee.phone,
      job: employee.job,
      active: false,
    );
    await s.flush();
    final snapshot = store.value;
    s.dispose();
    final restored = open(store);
    await restored.initialize();
    expect(restored.loginEmployee(demoManagerPhone, demoSeedPassword), isFalse);
    // Failed login must not trigger a fixture reinstall.
    expect(store.value, snapshot);
    restored.dispose();
  });

  test(
    'Migration preserves an existing employee login and reserved phone access',
    () async {
      final store = TestSessionStore();
      final original = DemoSession(store: store, now: () => now);
      await original.initialize();
      original.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      original.saveEmployee(
        name: 'Existing worker',
        phone: demoManagerPhone,
        job: 'Lễ tân',
        active: true,
      );
      final employee = original.employees.single;
      original.configureEmployeeAccess(
        employee.id,
        {'schedule'},
        'Existing1234',
        expectedRevision: 0,
        managerPassword: DemoSession.password,
        facilityIds: {''},
      );
      original.loginEmployee(demoManagerPhone, 'Existing1234');
      await original.flush();
      final oldAccess = (data(store)['employeeAccess'] as Map)[employee.id];
      original.dispose();
      final migrated = open(store);
      await migrated.initialize();
      expect(migrated.loadFailed, isFalse);
      expect(migrated.activeEmployee!.id, employee.id);
      expect(migrated.employeeCan('attendance'), isFalse);
      expect((data(store)['employeeAccess'] as Map)[employee.id], oldAccess);
      migrated.logout();
      expect(
        migrated.loginEmployee(demoManagerPhone, demoSeedPassword),
        isFalse,
      );
      expect(migrated.loginEmployee(demoManagerPhone, 'Existing1234'), isTrue);
      migrated.dispose();
    },
  );

  test(
    'Migration does not block an existing customer with a sample phone',
    () async {
      final store = TestSessionStore();
      final original = DemoSession(store: store, now: () => now);
      await original.initialize();
      original.register('Existing player', '0909000013', 'Existing1234');
      await original.flush();
      original.dispose();
      final migrated = open(store);
      await migrated.initialize();
      expect(migrated.loadFailed, isFalse);
      expect(migrated.user!.name, 'Existing player');
      migrated.logout();
      expect(migrated.login('0909000013', 'Existing1234'), isTrue);
      migrated.dispose();
    },
  );

  test('Save failure is visible and retry persists one fixture set', () async {
    final store = TestSessionStore()..failWrite = true;
    final s = open(store);
    await s.initialize();
    expect(s.initialized, isTrue);
    expect(s.saveFailed, isTrue);
    expect(store.value, isNull);
    store.failWrite = false;
    await s.retrySave();
    expect(s.saveFailed, isFalse);
    expect((data(store)['facilities'] as List).length, 5);
    s.dispose();
  });

  test('Broken input leaves saved state intact and permits retry', () async {
    final store = TestSessionStore();
    final original = DemoSession(store: store, now: () => now);
    await original.initialize();
    final snapshot = store.value;
    original.dispose();
    final s = DemoSession(
      store: store,
      now: () => now,
      demoFixtureLoader: () async => (photo: 'not an image', proof: proof),
    );
    await s.initialize();
    expect(s.loadFailed, isTrue);
    expect(store.value, snapshot);
    expect(s.installedDemoSeedVersion, 0);
    s.dispose();
    final retry = open(store);
    await retry.initialize();
    expect(retry.loadFailed, isFalse);
    expect(retry.installedDemoSeedVersion, demoSeedVersion);
    retry.dispose();
  });
  test('Vietnamese names, real venue addresses and additional customer histories are coherent', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    expect(s.loadFailed, isFalse);
    final d = data(store);
    for (final scenario in demoFacilityScenarios) {
      final f = (d['facilities'] as List).singleWhere(
        (f) => f['draft']['name'] == scenario.name,
      );
      expect(f['draft']['address'], scenario.address);
      expect(f['draft']['district'], scenario.district);
      expect(f['draft']['description'], contains('dữ liệu mẫu'));
    }
    expect(
      (d['operations']['employees'] as List).map((e) => e['name']),
      containsAll(['Trần Minh Hoàng', 'Lê Thảo Linh']),
    );
    for (final phone in ['0909000014', '0909000015']) {
      expect(s.login(phone, demoSeedPassword), isTrue);
      expect(s.user!.name, demoAdditionalPlayers[phone]);
      expect(s.bookings.length, 2);
      expect(s.bookings.every((b) => b.contact == s.user!.name), isTrue);
      expect(s.reviewableBookings.length, 1);
      s.logout();
    }
    final postOwners = (d['posts'] as List).map((p) => p['owner']).toSet();
    expect(postOwners.length, 3);
    s.dispose();
  });

  test('v1 migration changes fixture labels only, preserves decisions and does not reseed collections', () async {
    final store = TestSessionStore();
    final first = open(store);
    await first.initialize();
    final old = data(store);
    first.dispose();
    old['demoSeedVersion'] = 1;
    (old['users'] as List).removeWhere(
      (u) => ['0909000014', '0909000015'].contains(u['identifier']),
    );
    final removedIds = (old['bookings'] as List)
        .where((b) => ['0909000014', '0909000015'].contains(b['owner']))
        .map((b) => b['id'])
        .toSet();
    (old['bookings'] as List).removeWhere((b) => removedIds.contains(b['id']));
    (old['payments'] as List).removeWhere(
      (p) => removedIds.contains(p['bookingId']),
    );
    final firstFacility = (old['facilities'] as List).first;
    for (final key in ['draft', 'published']) {
      firstFacility[key]['name'] = demoFacilityScenarios.first.legacyName;
      firstFacility[key]['address'] = '96 Che Lan Vien - du lieu kiem thu';
      firstFacility[key]['city'] = 'TP. Ho Chi Minh';
      firstFacility[key]['district'] = 'Tan Phu';
    }
    for (final b in old['bookings'] as List) {
      if (b['facilityId'] == firstFacility['id']) {
        b['venueName'] = demoFacilityScenarios.first.legacyName;
        b['venueAddress'] = '96 Che Lan Vien - du lieu kiem thu';
      }
    }
    old['users'][0]['name'] = 'Minh Anh demo';
    old['users'][0]['password'] = 'Changed5678';
    old['operations']['employees'][0]['name'] = 'Quan ly san DEMO';
    old['operations']['employees'][0]['active'] = false;
    store.value = jsonEncode(old);
    final s = open(store);
    await s.initialize();
    expect(s.loadFailed, isFalse);
    final migrated = data(store);
    expect(
      (migrated['facilities'] as List).length,
      (old['facilities'] as List).length,
    );
    expect(migrated['facilities'][0]['draft']['name'], 'Sân cầu lông Phú Thọ');
    expect(
      migrated['facilities'][0]['draft']['address'],
      demoFacilityScenarios.first.address,
    );
    expect(migrated['users'][0]['name'], 'Nguyễn Minh Anh');
    expect(migrated['users'][0]['password'], 'Changed5678');
    expect(migrated['operations']['employees'][0]['active'], isFalse);
    expect(migrated['employeeAccess'], old['employeeAccess']);
    expect(migrated['shifts'], old['shifts']);
    expect(
      migrated['payments'].take((old['payments'] as List).length).toList(),
      old['payments'],
    );
    expect(
      (migrated['bookings'] as List).length,
      (old['bookings'] as List).length + 4,
    );
    final snapshot = store.value;
    s.dispose();
    final reopened = open(store);
    await reopened.initialize();
    expect(reopened.loadFailed, isFalse);
    expect(store.value, snapshot);
    reopened.dispose();
  });
}
