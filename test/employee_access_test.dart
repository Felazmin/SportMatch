import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
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
  void employee(DemoSession s) =>
      expect(s.loginEmployee('NS0001', 'Employee123'), isTrue);
  void grant(DemoSession s, Set<String> permissions, {int revision = 0}) =>
      s.configureEmployeeAccess(
        'NS0001',
        permissions,
        'Employee123',
        expectedRevision: revision,
        managerPassword: DemoSession.password,
      );
  void roster(DemoSession s) {
    owner(s);
    s.saveEmployee(
      name: 'Nhân viên thử',
      phone: '0912345678',
      job: 'Lễ tân',
      active: true,
    );
  }

  test('Managers configure accounts; workers never gain manager APIs', () {
    final s = open();
    roster(s);
    grant(s, {'schedule'});
    employee(s);
    expect(s.user, isNull);
    expect(s.activeEmployee!.id, 'NS0001');
    expect(s.employeeSchedule.length, 2);
    expect(() => s.managedBookings, throwsStateError);
    expect(() => s.managedUsers, throwsStateError);
    expect(() => s.managedFacilities, throwsStateError);
    expect(() => s.managedAttendance, throwsStateError);
    expect(() => s.employeeAccess('NS0001'), throwsStateError);
    expect(
      () => grant(s, {'schedule', 'onsite'}, revision: 1),
      throwsStateError,
    );
    expect(() => s.workflowRecord('NVH0001'), throwsStateError);
    expect(() => s.employeeSchedule.clear(), throwsUnsupportedError);
    s.logout();
    expect(s.activeEmployee, isNull);
    expect(() => s.employeeSchedule, throwsStateError);
  });
  test('Credential, permission and stale revision validation is atomic', () {
    final s = open();
    roster(s);
    expect(
      () => s.configureEmployeeAccess(
        'NS0001',
        {'schedule'},
        'short',
        expectedRevision: 0,
        managerPassword: DemoSession.password,
      ),
      throwsStateError,
    );
    expect(() => grant(s, {'onsite'}), throwsStateError);
    expect(() => grant(s, {'admin'}), throwsStateError);
    grant(s, {'schedule'});
    expect(() => grant(s, {'schedule'}), throwsStateError);
    expect(
      () => s.configureEmployeeAccess(
        'NS0001',
        {'schedule'},
        '',
        expectedRevision: 1,
        managerPassword: 'wrong',
      ),
      throwsStateError,
    );
    expect(s.employeeAccess('NS0001')!.revision, 1);
  });
  test('Onsite collection and attendance require explicit capabilities and preserve guards', () {
    final s = open();
    roster(s);
    grant(s, {'schedule'});
    employee(s);
    expect(() => s.employeeConfirmPayment('NVH0001'), throwsStateError);
    expect(
      () => s.employeeSetAttendance(
        'NVH0001',
        DemoAttendance.checkedIn,
        DemoAttendance.pending,
      ),
      throwsStateError,
    );
    owner(s);
    grant(s, {'schedule', 'onsite', 'attendance'}, revision: 1);
    employee(s);
    s.employeeConfirmPayment('NVH0001');
    expect(s.employeeRecordPaid('NVH0001'), isTrue);
    expect(() => s.employeeConfirmPayment('NVH0001'), throwsStateError);
    expect(
      () => s.employeeSetAttendance(
        'NVH0001',
        DemoAttendance.checkedIn,
        DemoAttendance.pending,
      ),
      throwsStateError,
    );
    now = DateTime(2026, 10, 9, 8, 45);
    s.employeeSetAttendance(
      'NVH0001',
      DemoAttendance.checkedIn,
      DemoAttendance.pending,
    );
    expect(
      () => s.employeeSetAttendance(
        'NVH0001',
        DemoAttendance.completed,
        DemoAttendance.pending,
      ),
      throwsStateError,
    );
    now = DateTime(2026, 10, 9, 10);
    s.employeeSetAttendance(
      'NVH0001',
      DemoAttendance.completed,
      DemoAttendance.checkedIn,
    );
    expect(s.employeeSchedule.first.attendance, DemoAttendance.completed);
    owner(s);
    expect(s.operationAudit.any((e) => e.actor == 'NS0001'), isTrue);
  });
  test('Revocation and inactive roster prevent login', () {
    final s = open();
    roster(s);
    grant(s, {'schedule'});
    employee(s);
    owner(s);
    s.configureEmployeeAccess(
      'NS0001',
      {},
      '',
      expectedRevision: 1,
      managerPassword: DemoSession.password,
    );
    expect(s.loginEmployee('0912345678', 'Employee123'), isFalse);
    grant(s, {'schedule'}, revision: 2);
    s.saveEmployee(
      id: 'NS0001',
      name: 'Nhân viên thử',
      phone: '0912345678',
      job: 'Lễ tân',
      active: false,
    );
    expect(s.loginEmployee('NS0001', 'Employee123'), isFalse);
  });
  test('Login lockout expires and aliases work without switching manager on failure', () {
    final s = open();
    roster(s);
    grant(s, {'schedule'});
    for (var i = 0; i < 5; i++) {
      expect(s.loginEmployee('NS0001', 'wrong'), isFalse);
    }
    expect(s.loginEmployee('NS0001', 'Employee123'), isFalse);
    expect(s.role, DemoRole.owner);
    now = now.add(const Duration(minutes: 1));
    expect(s.loginEmployee('+84 912 345 678', 'Employee123'), isTrue);
    expect(s.activeEmployee!.id, 'NS0001');
    expect(
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      ),
      isTrue,
    );
    expect(s.activeEmployee, isNull);
  });
  test(
    'Own shifts exclude other employees and worker cannot allocate shifts',
    () {
      final s = open();
      roster(s);
      grant(s, {'schedule'});
      s.saveEmployee(
        name: 'Nhân viên khác',
        phone: '0923456789',
        job: 'Thu ngân',
        active: true,
      );
      s.scheduleEmployeeShift('NS0001', DateTime(2026, 10, 9, 8), 4);
      s.scheduleEmployeeShift('NS0002', DateTime(2026, 10, 9, 8), 4);
      employee(s);
      expect(s.ownEmployeeShifts.single.employeeId, 'NS0001');
      expect(
        () => s.scheduleEmployeeShift('NS0001', DateTime(2026, 10, 10, 8), 4),
        throwsStateError,
      );
    },
  );
  test(
    'Employee login, capabilities, audit and payments survive restart',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      roster(s);
      grant(s, {'schedule', 'onsite'});
      employee(s);
      s.employeeConfirmPayment('NVH0001');
      await s.flush();
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(restored.user, isNull);
      expect(restored.activeEmployee!.id, 'NS0001');
      expect(restored.employeeCan('onsite'), isTrue);
      expect(restored.employeeRecordPaid('NVH0001'), isTrue);
    },
  );
  test('Legacy snapshots migrate with no employee accounts', () async {
    final store = TestSessionStore();
    final s = open(store);
    await s.initialize();
    await s.flush();
    final j = jsonDecode(store.value!) as Map<String, dynamic>;
    j.remove('employeeAccess');
    j.remove('activeEmployee');
    store.value = jsonEncode(j);
    final restored = open(store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.activeEmployee, isNull);
  });
  for (final invalid in ['permission', 'reference', 'active', 'actor']) {
    test('Corrupt $invalid employee snapshot is rejected atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      roster(s);
      grant(s, {'schedule', 'onsite'});
      employee(s);
      s.employeeConfirmPayment('NVH0001');
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      switch (invalid) {
        case 'permission':
          j['employeeAccess']['NS0001']['permissions'] = ['admin'];
        case 'reference':
          j['employeeAccess']['NS9999'] = j['employeeAccess']['NS0001'];
        case 'active':
          j['activeEmployee'] = 'NS9999';
        case 'actor':
          j['operations']['audit'].last['actor'] = 'NS9999';
      }
      store.value = jsonEncode(j);
      final restored = open(store);
      await restored.initialize();
      expect(restored.loadFailed, isTrue);
      expect(restored.user, isNull);
    });
  }
}
