import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/employee_access_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
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
  Future<DemoSession> session(
    TestSessionStore store, {
    bool grant = true,
    DateTime Function()? clock,
  }) async {
    final s = DemoSession(
      store: store,
      now: clock ?? () => DateTime(2026, 10, 8, 10),
    );
    addTearDown(s.dispose);
    await s.initialize();
    owner(s);
    s.saveEmployee(
      name: 'Nhân viên thử',
      phone: '0912345678',
      job: 'Lễ tân',
      active: true,
    );
    if (grant) {
      s.configureEmployeeAccess(
        'NS0001',
        {'schedule', 'onsite', 'attendance'},
        'Employee123',
        expectedRevision: 0,
        managerPassword: DemoSession.password,
      );
    }
    await s.flush();
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    bool large = false,
  }) async {
    t.view.physicalSize = Size(large ? 320 : 402, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key, {bool settle = true}) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
  }

  Future<void> credentials(WidgetTester t) async {
    await t.enterText(find.byKey(const Key('employee-login-id')), 'NS0001');
    await t.enterText(
      find.byKey(const Key('employee-login-password')),
      'Employee123',
    );
  }

  Future<void> configure(WidgetTester t) async {
    await press(t, 'employee-permission-onsite');
    await t.enterText(
      find.byKey(const Key('employee-new-password')),
      'Employee123',
    );
    final f = find.byKey(const Key('employee-manager-password'));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.enterText(f, DemoSession.password);
  }

  testWidgets(
    'Permission failed save locks edits and retry does not increment revision again',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store, grant: false);
      await pump(t, EmployeeAccessScreen(session: s, id: 'NS0001'));
      await configure(t);
      store.failWrite = true;
      await press(t, 'employee-access-save');
      expect(find.text('Đã lưu quyền nhân viên.'), findsNothing);
      expect(
        find.textContaining('Quyền đã cập nhật nhưng chưa lưu được'),
        findsOneWidget,
      );
      expect(s.employeeAccess('NS0001')!.revision, 1);
      expect(
        t
            .widget<TextField>(
              find.byKey(const Key('employee-manager-password')),
            )
            .enabled,
        isFalse,
      );
      await press(t, 'employee-access-save');
      expect(s.employeeAccess('NS0001')!.revision, 1);
      store.failWrite = false;
      await press(t, 'employee-access-save');
      expect(s.employeeAccess('NS0001')!.revision, 1);
      final restored = DemoSession(store: store);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.employeeAccess('NS0001')!.permissions, {
        'schedule',
        'onsite',
      });
      expect(restored.employeeAccess('NS0001')!.revision, 1);
    },
  );

  testWidgets('Manager switch cannot use or save old permission editor', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = await session(store, grant: false);
    await pump(t, EmployeeAccessScreen(session: s, id: 'NS0001'));
    await configure(t);
    admin(s);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('employee-access-save')), findsNothing);
    expect(find.textContaining('quản lý ban đầu'), findsOneWidget);
    expect(s.employeeAccess('NS0001'), isNull);
  });

  testWidgets(
    'Pending permission retry rejects a newer revision without replay',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store, grant: false);
      await pump(t, EmployeeAccessScreen(session: s, id: 'NS0001'));
      await configure(t);
      store.failWrite = true;
      await press(t, 'employee-access-save');
      s.configureEmployeeAccess(
        'NS0001',
        {'schedule'},
        '',
        expectedRevision: 1,
        managerPassword: DemoSession.password,
      );
      await s.flush();
      final writes = store.writes;
      store.failWrite = false;
      await press(t, 'employee-access-save');
      expect(store.writes, writes);
      expect(s.employeeAccess('NS0001')!.revision, 2);
      expect(s.employeeAccess('NS0001')!.permissions, {'schedule'});
      expect(
        find.textContaining('Quyền đã thay đổi ở màn khác'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Employee attendance retry persists check-in without applying it twice',
    (t) async {
      final store = TestSessionStore();
      var now = DateTime(2026, 10, 8, 10);
      final s = await session(store, clock: () => now);
      s.loginEmployee('NS0001', 'Employee123');
      s.employeeConfirmPayment('NVH0001');
      await s.flush();
      now = DateTime(2026, 10, 9, 8, 45);
      await pump(t, EmployeePortalScreen(session: s));
      store.failWrite = true;
      await press(t, 'employee-checkin-NVH0001');
      await press(t, 'employee-action-confirm');
      expect(
        s.employeeSchedule.singleWhere((r) => r.id == 'NVH0001').attendance,
        DemoAttendance.checkedIn,
      );
      store.failWrite = false;
      await press(t, 'employee-retry-save');
      final restored = DemoSession(store: store, now: () => now);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(
        restored.employeeSchedule
            .singleWhere((r) => r.id == 'NVH0001')
            .attendance,
        DemoAttendance.checkedIn,
      );
      expect(s.saveFailed, isFalse);
    },
  );

  testWidgets('Manager switch during permission save suppresses old success', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = await session(store, grant: false);
    await pump(t, EmployeeAccessScreen(session: s, id: 'NS0001'));
    await configure(t);
    final gate = Completer<void>();
    store.beforeWrite = () => gate.future;
    await press(t, 'employee-access-save', settle: false);
    admin(s);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('Đã lưu quyền nhân viên.'), findsNothing);
    expect(find.byKey(const Key('employee-access-save')), findsNothing);
  });

  testWidgets(
    'Employee login save failure disables actions until retry and restores session',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      s.logout();
      await s.flush();
      await pump(t, EmployeePortalScreen(session: s));
      await credentials(t);
      store.failWrite = true;
      await press(t, 'employee-login-submit');
      expect(find.byKey(const Key('employee-retry-save')), findsOneWidget);
      final before = store.writes;
      store.failWrite = false;
      await press(t, 'employee-retry-save');
      expect(store.writes, before + 1);
      final restored = DemoSession(store: store);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.activeEmployee?.id, 'NS0001');
    },
  );

  testWidgets(
    'Employee collection save retry preserves one receipt and its date',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      s.loginEmployee('NS0001', 'Employee123');
      await s.flush();
      await pump(t, EmployeePortalScreen(session: s));
      store.failWrite = true;
      await press(t, 'employee-pay-NVH0001');
      await press(t, 'employee-action-confirm');
      await press(t, 'employee-retry-save');
      store.failWrite = false;
      await press(t, 'employee-retry-save');
      expect(s.employeeRecordPaid('NVH0001'), isTrue);
      owner(s);
      final b = s.managedBookings.singleWhere((b) => b.id == 'NVH0001');
      final date = s.paymentFor(b)!.receivedAt;
      final restored = DemoSession(store: store);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.employeeRecordPaid('NVH0001'), isTrue);
      owner(restored);
      final rb = restored.managedBookings.singleWhere((b) => b.id == 'NVH0001');
      expect(restored.paymentFor(rb)!.receivedAt, date);
      expect(restored.paymentFor(rb)!.state, DemoPaymentState.approved);
    },
  );

  testWidgets('Changed employee session cannot retry old collection', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = await session(store);
    s.loginEmployee('NS0001', 'Employee123');
    await s.flush();
    await pump(t, EmployeePortalScreen(session: s));
    store.failWrite = true;
    await press(t, 'employee-pay-NVH0001');
    await press(t, 'employee-action-confirm');
    admin(s);
    await s.flush();
    final writes = store.writes;
    store.failWrite = false;
    await press(t, 'employee-retry-save');
    expect(store.writes, writes);
    expect(s.role, DemoRole.admin);
    expect(find.textContaining('Phiên đăng nhập đã thay đổi'), findsOneWidget);
  });

  testWidgets(
    'Failed employee logout remains guest and retry persists logout',
    (t) async {
      final store = TestSessionStore();
      final s = await session(store);
      s.loginEmployee('NS0001', 'Employee123');
      await s.flush();
      await pump(t, EmployeePortalScreen(session: s));
      store.failWrite = true;
      await press(t, 'employee-logout');
      expect(s.activeEmployee, isNull);
      expect(find.byKey(const Key('employee-retry-save')), findsOneWidget);
      store.failWrite = false;
      await press(t, 'employee-retry-save');
      final restored = DemoSession(store: store);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.activeEmployee, isNull);
      expect(restored.user, isNull);
    },
  );

  for (final manager in [false, true]) {
    testWidgets(
      '${manager ? 'Permission' : 'Employee'} save failure fits 320px 200 percent',
      (t) async {
        final store = TestSessionStore();
        final s = await session(store, grant: !manager);
        if (!manager) {
          s.logout();
          await s.flush();
        }
        final key = await pump(
          t,
          manager
              ? EmployeeAccessScreen(session: s, id: 'NS0001')
              : EmployeePortalScreen(session: s),
          large: true,
        );
        if (manager) {
          await configure(t);
        } else {
          await credentials(t);
        }
        store.failWrite = true;
        await press(
          t,
          manager ? 'employee-access-save' : 'employee-login-submit',
        );
        final retry = find.byKey(
          Key(manager ? 'employee-access-save' : 'employee-retry-save'),
        );
        if (retry.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            retry,
            150,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await t.ensureVisible(retry);
        await t.pumpAndSettle();
        await captureHome(
          key,
          'employee-save-${manager ? 'permission' : 'portal'}-2.0',
          t,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
