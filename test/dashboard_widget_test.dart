import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/dashboard_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';

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
  DemoSession open(bool admin) {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 10));
    addTearDown(s.dispose);
    s.loginStaff(
      admin ? DemoRole.admin : DemoRole.owner,
      admin ? DemoSession.adminEmail : DemoSession.ownerEmail,
      DemoSession.password,
    );
    return s;
  }

  Future<GlobalKey> pump(WidgetTester t, DemoSession s, double scale) async {
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
          home: DashboardScreen(session: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String id) async {
    final f = find.byKey(Key(id));
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Day selection and booking open linked workflow', (t) async {
    final s = open(false);
    await pump(t, s, 1);
    await t.tap(find.byKey(const Key('dashboard-next')));
    await t.pumpAndSettle();
    expect(find.text('4.2% giờ sân đã đặt'), findsOneWidget);
    await press(t, 'dashboard-booking-NVH0001');
    expect(find.byType(WorkflowDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Admin approval shortcut opens queue; role change hides overview',
    (t) async {
      final s = open(true);
      await pump(t, s, 1);
      await press(t, 'dashboard-approval');
      expect(find.byType(ApprovalCenterScreen), findsOneWidget);
      s.logout();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Cần tài khoản Chủ sân hoặc Admin.'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-occupancy')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final admin in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Overview role $admin fits scale $scale', (t) async {
        final key = await pump(t, open(admin), scale);
        await t.tap(find.byKey(const Key('dashboard-next')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final name =
            'dashboard-${admin ? 'admin' : 'owner'}-${scale == 1 ? 'normal' : 'large'}';
        await captureHome(key, name, t);
        for (var i = 0; i < 6; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(key, '$name-bottom', t);
      });
    }
  }
}
