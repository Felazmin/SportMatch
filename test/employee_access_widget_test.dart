import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/employee_access_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession open() {
    final s = DemoSession(now: () => DateTime(2026, 10, 8, 10));
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.saveEmployee(
      name: 'Nhân viên thử',
      phone: '0912345678',
      job: 'Lễ tân',
      active: true,
    );
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
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

  Future<void> press(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  void grant(DemoSession s) => s.configureEmployeeAccess(
    'NS0001',
    {'schedule', 'onsite'},
    'Employee123',
    expectedRevision: 0,
    managerPassword: DemoSession.password,
  );
  testWidgets(
    'Manager assigns rights then employee logs in and collects onsite payment',
    (t) async {
      final s = open();
      await pump(t, EmployeeAccessScreen(session: s, id: 'NS0001'));
      await press(t, find.byKey(const Key('employee-permission-onsite')));
      await t.enterText(
        find.byKey(const Key('employee-new-password')),
        'Employee123',
      );
      await t.enterText(
        find.byKey(const Key('employee-manager-password')),
        DemoSession.password,
      );
      await press(t, find.byKey(const Key('employee-access-save')));
      expect(s.employeeAccess('NS0001')!.permissions, {'schedule', 'onsite'});
      s.logout();
      await pump(t, EmployeePortalScreen(session: s));
      await t.enterText(find.byKey(const Key('employee-login-id')), 'NS0001');
      await t.enterText(
        find.byKey(const Key('employee-login-password')),
        'Employee123',
      );
      await press(t, find.byKey(const Key('employee-login-submit')));
      await press(t, find.text('Thu tại sân').first);
      await press(t, find.byKey(const Key('employee-action-confirm')));
      expect(s.employeeRecordPaid('NVH0001'), isTrue);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Changing session during worker confirmation blocks mutation', (
    t,
  ) async {
    final s = open();
    grant(s);
    s.loginEmployee('NS0001', 'Employee123');
    await pump(t, EmployeePortalScreen(session: s));
    await press(t, find.text('Thu tại sân').first);
    s.logout();
    await press(t, find.byKey(const Key('employee-action-confirm')));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(s.paymentFor(s.managedBookings.first), isNull);
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Delegation and worker portal fit text scale $scale', (
      t,
    ) async {
      final s = open();
      final key = await pump(
        t,
        EmployeeAccessScreen(session: s, id: 'NS0001'),
        scale: scale,
      );
      await captureHome(key, 'employee-access-$scale', t);
      expect(t.takeException(), isNull);
      grant(s);
      s.loginEmployee('NS0001', 'Employee123');
      final portal = await pump(
        t,
        EmployeePortalScreen(session: s),
        scale: scale,
      );
      await captureHome(portal, 'employee-portal-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
}
