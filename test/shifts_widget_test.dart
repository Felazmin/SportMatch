import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_shifts.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/shifts_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession open() {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 10));
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.saveEmployee(
      name: 'Nguyễn Minh Anh',
      phone: '0909876543',
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

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Roster/profile/form creates real shift once', (t) async {
    final s = open();
    await pump(t, EmployeeRosterScreen(session: s));
    await press(t, 'roster-NS0001');
    await press(t, 'shift-add');
    await press(t, 'shift-save');
    expect(s.employeeShifts.length, 1);
    await press(t, 'shift-CA0001');
    expect(find.byType(ShiftDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Role change during cancellation cannot mutate', (t) async {
    final s = open();
    final shift = s.scheduleEmployeeShift(
      'NS0001',
      DateTime(2026, 10, 8, 8),
      4,
    );
    await pump(t, ShiftDetailScreen(session: s, id: shift.id));
    await press(t, 'shift-cancelled');
    await t.enterText(find.byType(TextField).last, 'Change employee schedule');
    await t.tap(find.byKey(const Key('finance-text-confirm')));
    await t.pumpAndSettle();
    s.login(DemoSession.phone, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    expect(s.employeeShifts.single.state, DemoShiftState.scheduled);
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    for (final view in ['roster', 'employee', 'form', 'shift']) {
      testWidgets('Shift $view fits scale $scale', (t) async {
        final s = open();
        final shift = s.scheduleEmployeeShift(
          'NS0001',
          DateTime(2026, 10, 8, 8),
          4,
        );
        final screen = switch (view) {
          'roster' => EmployeeRosterScreen(session: s),
          'employee' => EmployeeDetailScreen(session: s, id: 'NS0001'),
          'form' => ShiftFormScreen(session: s, employeeId: 'NS0001'),
          _ => ShiftDetailScreen(session: s, id: shift.id),
        };
        final key = await pump(t, screen, scale: scale);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'shift-$view-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 5; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
