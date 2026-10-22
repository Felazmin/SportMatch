import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/admin_system_report_screen.dart';
import 'package:test_do_an/screens/dashboard_screen.dart';
import 'package:test_do_an/screens/cashflow_screen.dart';

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
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s,
    double scale, {
    bool dashboard = false,
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
          home: dashboard
              ? DashboardScreen(session: s)
              : AdminSystemReportScreen(session: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('System report fits at text scale $scale and changes period', (
      t,
    ) async {
      final s = open();
      s.confirmVenuePayment(s.managedBookings.first);
      final key = await pump(t, s, scale);
      await t.tap(find.byKey(const Key('system-report-period-30')));
      await t.pumpAndSettle();
      expect(find.text('01/10/2026 – 09/10/2026'), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureHome(key, 'admin-system-report-$scale', t);
      await t.scrollUntilVisible(
        find.byKey(const Key('system-report-export')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('system-report-export')), findsOneWidget);
      await captureHome(key, 'admin-system-report-bottom-$scale', t);
      expect(t.takeException(), isNull);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      expect(find.text('Chỉ Admin được xem báo cáo hệ thống.'), findsOneWidget);
    });
  }
  testWidgets('Dashboard opens system report', (t) async {
    final s = open();
    await pump(t, s, 1, dashboard: true);
    final button = find.byKey(const Key('dashboard-system-report'));
    await t.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(AdminSystemReportScreen), findsOneWidget);
    await t.scrollUntilVisible(
      find.byKey(const Key('system-report-empty')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('system-report-empty')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Cashflow drill-down preserves the selected report period', (
    t,
  ) async {
    final s = open();
    s.confirmVenuePayment(s.managedBookings.first);
    await pump(t, s, 1);
    await t.tap(find.byKey(const Key('system-report-period-30')));
    await t.pumpAndSettle();
    final button = find.byKey(const Key('system-report-cashflow'));
    await t.scrollUntilVisible(
      button,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(button);
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pumpAndSettle();
    final screen = t.widget<CashflowScreen>(find.byType(CashflowScreen));
    expect(screen.initialRange!.start, DateTime(2026, 10, 1));
    expect(screen.initialRange!.end, DateTime(2026, 10, 9));
    expect(find.text('01/10/2026 – 09/10/2026'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
