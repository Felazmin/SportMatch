import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_shifts.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
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
  void employee(DemoSession s, {bool active = true, String? id}) =>
      s.saveEmployee(
        id: id,
        name: 'Test Employee',
        phone: '0909876543',
        job: 'Lễ tân',
        active: active,
      );
  DateTime start() => DateTime(2026, 10, 8, 8);
  DemoShift seed(DemoSession s) {
    owner(s);
    employee(s);
    return s.scheduleEmployeeShift('NS0001', start(), 4);
  }

  test('Guests/players cannot view, schedule or record shifts; roster is not login', () {
    final s = open();
    expect(() => s.employeeShifts, throwsStateError);
    final shift = seed(s);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.employeeShifts, throwsStateError);
    expect(
      () => s.scheduleEmployeeShift('NS0001', start(), 4),
      throwsStateError,
    );
    expect(
      () => s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.cancelled,
        expectedRevision: 0,
        reason: 'Change schedule',
      ),
      throwsStateError,
    );
    expect(
      s.loginStaff(DemoRole.owner, '0909876543', DemoSession.password),
      isFalse,
    );
  });
  test('Overlap rejected; adjacent shifts allowed; collection immutable', () {
    final s = open();
    final first = seed(s);
    expect(
      () => s.scheduleEmployeeShift(
        'NS0001',
        first.start.add(const Duration(hours: 1)),
        2,
      ),
      throwsStateError,
    );
    s.scheduleEmployeeShift('NS0001', first.end, 2);
    expect(s.employeeShifts.length, 2);
    expect(() => s.employeeShifts.clear(), throwsUnsupportedError);
  });
  test(
    'Unknown/inactive, past, outside horizon, nonwhole hour and range rejected',
    () {
      final s = open();
      seed(s);
      expect(
        () => s.scheduleEmployeeShift('NS9999', start(), 1),
        throwsStateError,
      );
      for (final day in [
        now,
        now.add(const Duration(days: 31)),
        start().add(const Duration(minutes: 1)),
      ]) {
        expect(
          () => s.scheduleEmployeeShift('NS0001', day, 1),
          throwsStateError,
        );
      }
      for (final h in [0, 13]) {
        expect(
          () => s.scheduleEmployeeShift(
            'NS0001',
            start().add(const Duration(days: 1)),
            h,
          ),
          throwsStateError,
        );
      }
      expect(
        () => s.scheduleEmployeeShift('NS0001', DateTime(2026, 10, 9, 21), 2),
        throwsStateError,
      );
      employee(s, active: false, id: 'NS0001');
      expect(
        () => s.scheduleEmployeeShift(
          'NS0001',
          start().add(const Duration(days: 1)),
          4,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Check-in opens exactly 15 minutes early and completion only at end',
    () {
      final s = open();
      final shift = seed(s);
      now = shift.start.subtract(const Duration(minutes: 15, milliseconds: 1));
      expect(
        () => s.setEmployeeShiftState(
          shift.id,
          DemoShiftState.checkedIn,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      now = now.add(const Duration(milliseconds: 1));
      s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.checkedIn,
        expectedRevision: 0,
      );
      expect(
        () => s.setEmployeeShiftState(
          shift.id,
          DemoShiftState.completed,
          expectedRevision: 1,
        ),
        throwsStateError,
      );
      now = shift.end;
      s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.completed,
        expectedRevision: 1,
      );
      expect(s.employeeShifts.single.state, DemoShiftState.completed);
      expect(
        () => s.setEmployeeShiftState(
          shift.id,
          DemoShiftState.absent,
          expectedRevision: 2,
        ),
        throwsStateError,
      );
    },
  );
  test('Inactive worker cannot check in; absence at end is terminal', () {
    final s = open();
    final shift = seed(s);
    employee(s, active: false, id: 'NS0001');
    now = shift.start;
    expect(
      () => s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.checkedIn,
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    now = shift.end;
    s.setEmployeeShiftState(
      shift.id,
      DemoShiftState.absent,
      expectedRevision: 0,
    );
    expect(
      () => s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.checkedIn,
        expectedRevision: 1,
      ),
      throwsStateError,
    );
  });
  test('Cancellation requires reason, frees time; stale replay denied', () {
    final s = open();
    final shift = seed(s);
    expect(
      () => s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.cancelled,
        expectedRevision: 0,
        reason: 'bad',
      ),
      throwsStateError,
    );
    s.setEmployeeShiftState(
      shift.id,
      DemoShiftState.cancelled,
      expectedRevision: 0,
      reason: 'Change schedule',
    );
    expect(
      () => s.setEmployeeShiftState(
        shift.id,
        DemoShiftState.cancelled,
        expectedRevision: 0,
        reason: 'Change schedule',
      ),
      throwsStateError,
    );
    final next = s.scheduleEmployeeShift('NS0001', shift.start, 4);
    expect(next.id, 'CA0002');
  });
  test(
    'Failed save retry restores once and legacy snapshots migrate',
    () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      owner(s);
      employee(s);
      await s.flush();
      store.failWrite = true;
      s.scheduleEmployeeShift('NS0001', start(), 4);
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      final r = open(store);
      await r.initialize();
      expect(r.employeeShifts.length, 1);
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('shifts');
      data.remove('nextShift');
      store.value = jsonEncode(data);
      final legacy = open(store);
      await legacy.initialize();
      expect(legacy.loadFailed, isFalse);
      expect(legacy.employeeShifts, isEmpty);
    },
  );
  for (final corruption in ['employee', 'counter', 'overlap', 'state']) {
    test('Corrupt $corruption fails restoration atomically', () async {
      final store = TestSessionStore();
      final s = open(store);
      await s.initialize();
      seed(s);
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final list = data['shifts'] as List;
      final shift = list.single as Map<String, dynamic>;
      if (corruption == 'employee') shift['employeeId'] = 'NS9999';
      if (corruption == 'counter') data['nextShift'] = 1;
      if (corruption == 'state') shift['state'] = 'completed';
      if (corruption == 'overlap') {
        list.add({...shift, 'id': 'CA0002'});
        data['nextShift'] = 3;
      }
      store.value = jsonEncode(data);
      final r = open(store);
      await r.initialize();
      expect(r.loadFailed, isTrue);
      expect(r.user, isNull);
    });
  }
}
