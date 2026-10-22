import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

import 'persistence_test.dart' show TestSessionStore;
import 'multi_facility_test.dart' show publishTestFacility;

void main() {
  DemoSession open([TestSessionStore? store]) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  String setup(DemoSession s) {
    final f = publishTestFacility(s);
    s.login(DemoSession.phone, DemoSession.password);
    final b = s.reserve(
      facilityId: f.id,
      court: 1,
      start: DateTime(2026, 10, 9, 12),
      hours: 1,
      contact: 'Người thử',
      contactPhone: DemoSession.phone,
      quotedRate: 150000,
    );
    owner(s);
    s.saveEmployee(
      name: 'Nhân viên thử',
      phone: '0912345678',
      job: 'Lễ tân',
      active: true,
    );
    return b.id;
  }

  void grant(DemoSession s, Set<String> ids, {int revision = 0}) =>
      s.configureEmployeeAccess(
        'NS0001',
        {'schedule', 'onsite', 'attendance'},
        'Employee123',
        expectedRevision: revision,
        managerPassword: DemoSession.password,
        facilityIds: ids,
      );
  test('Assigned worker sees and acts only on assigned facility', () {
    final s = open();
    final id = setup(s);
    grant(s, {'CS0001'});
    expect(s.loginEmployee('NS0001', 'Employee123'), true);
    expect(s.employeeSchedule.map((r) => r.id), [id]);
    expect(() => s.employeeConfirmPayment('NVH0001'), throwsStateError);
    expect(() => s.employeeRecordPaid('NVH0001'), throwsStateError);
    s.employeeConfirmPayment(id);
    expect(s.employeeRecordPaid(id), true);
    owner(s);
    grant(s, {''}, revision: 1);
    s.loginEmployee('NS0001', 'Employee123');
    expect(s.employeeSchedule.length, 2);
    expect(() => s.employeeRecordPaid(id), throwsStateError);
  });
  test('Empty, mixed wildcard and unknown scopes do not grant access', () {
    final s = open();
    setup(s);
    for (final ids in [
      <String>{},
      {'*', 'CS0001'},
      {'CS9999'},
      {'__admin__'},
    ]) {
      expect(() => grant(s, ids), throwsStateError);
      expect(s.employeeAccess('NS0001'), isNull);
    }
    grant(s, {'*'});
    expect(
      () => s.employeeAccess('NS0001')!.facilityIds.clear(),
      throwsUnsupportedError,
    );
  });
  test(
    'Scope persists through restart and unknown links reject atomically',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      final id = setup(s);
      grant(s, {'CS0001'});
      s.loginEmployee('NS0001', 'Employee123');
      await s.flush();
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, false);
      expect(next.employeeSchedule.single.id, id);
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      j['employeeAccess']['NS0001']['facilityIds'] = ['CS9999'];
      store.value = jsonEncode(j);
      final broken = open(store);
      await broken.initialize();
      expect(broken.loadFailed, true);
      expect(broken.user, isNull);
    },
  );
  test(
    'Legacy employee access migrates to prior all-facility behavior',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      setup(s);
      grant(s, {'*'});
      await s.flush();
      final j = jsonDecode(store.value!) as Map<String, dynamic>;
      j['employeeAccess']['NS0001'].remove('facilityIds');
      store.value = jsonEncode(j);
      final next = open(store);
      await next.initialize();
      expect(next.loadFailed, false);
      expect(next.employeeAccess('NS0001')!.facilityIds, {'*'});
    },
  );
}
