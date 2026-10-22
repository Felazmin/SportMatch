import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/booking/demo_booking.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/admin_dashboard_screen.dart';
import 'package:test_do_an/screens/admin_management_screen.dart';
import 'package:test_do_an/screens/admin_system_report_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';
import 'package:test_do_an/screens/owner_verification_screen.dart';
import 'package:test_do_an/screens/venue_map_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/admin_players_screen.dart';
import 'package:test_do_an/screens/reviews_screen.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show sampleFacilityProof;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession admin() {
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
    bool standalone = false,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MyApp(session: s),
      ),
    );
    await t.pumpAndSettle();
    if (standalone) {
      final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: theme,
            home: AdminDashboardScreen(session: s),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await t.pumpAndSettle();
    }
    return key;
  }

  Future<void> press(WidgetTester t, Finder finder) async {
    await t.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    testWidgets('Admin dashboard fits ${layout.$1}/${layout.$2}', (t) async {
      final s = admin();
      s.confirmVenuePayment(s.managedBookings.first);
      final key = await pump(t, s, width: layout.$1, scale: layout.$2);
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.byType(VenueMapScreen), findsNothing);
      expect(t.takeException(), isNull);
      await captureHome(
        key,
        'admin-dashboard-${layout.$1.toInt()}-${layout.$2}',
        t,
      );
      for (var i = 0; i < 14; i++) {
        await t.drag(
          find.byKey(const Key('admin-dashboard-list')),
          const Offset(0, -300),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await captureHome(
        key,
        'admin-dashboard-bottom-${layout.$1.toInt()}-${layout.$2}',
        t,
      );
    });
  }
  testWidgets('Admin has separate five-tab navigation', (t) async {
    final s = admin();
    await pump(t, s);
    for (final label in adminTabLabels) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Bản đồ'), findsNothing);
    expect(find.text('Khám phá'), findsNothing);
    expect(find.text('Nổi bật'), findsNothing);
    for (final item in [
      (1, ManagementScreen),
      (2, ApprovalCenterScreen),
      (3, AdminSystemReportScreen),
    ]) {
      await t.tap(find.byKey(Key('admin-nav-${item.$1}')));
      await t.pumpAndSettle();
      expect(find.byType(item.$2), findsOneWidget);
      expect(t.takeException(), isNull);
    }
    await t.tap(find.byKey(const Key('admin-nav-4')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const Key('admin-nav-0')));
    await t.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });
  testWidgets('Admin header applies the system inset only once', (t) async {
    t.view.padding = const FakeViewPadding(top: 24);
    addTearDown(t.view.resetPadding);
    await pump(t, admin());
    expect(t.getTopLeft(find.text('Dashboard')).dy, lessThan(55));
    expect(t.getTopLeft(find.text('Dashboard')).dy, greaterThanOrEqualTo(24));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Periods use last calendar week and current month, with real receipts',
    (t) async {
      final s = admin();
      final booking = s.managedBookings.first;
      s.confirmVenuePayment(booking);
      await pump(t, s);
      expect(find.text('28/09/2026 – 04/10/2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('admin-metric-received')),
          matching: find.text(bookingMoney(0)),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('admin-period-0')));
      await t.pumpAndSettle();
      expect(find.text('09/10/2026 – 09/10/2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('admin-metric-received')),
          matching: find.text(bookingMoney(booking.total)),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('admin-period-2')));
      await t.pumpAndSettle();
      expect(find.text('01/10/2026 – 09/10/2026'), findsOneWidget);
      expect(find.text('12.480'), findsNothing);
    },
  );
  testWidgets(
    'Report link preserves the dashboard period and chart has real values',
    (t) async {
      final s = admin();
      final booking = s.managedBookings.first;
      s.confirmVenuePayment(booking);
      final boundary = await pump(t, s, standalone: true);
      await t.tap(find.byKey(const Key('admin-period-0')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byType(AdminTransactionChart),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(find.byType(AdminTransactionChart));
      await t.pumpAndSettle();
      expect(
        t
            .widget<AdminTransactionChart>(find.byType(AdminTransactionChart))
            .values
            .values
            .single,
        booking.total,
      );
      await captureHome(boundary, 'admin-dashboard-live-chart', t);
      await press(t, find.byKey(const Key('dashboard-system-report')));
      final screen = t.widget<AdminSystemReportScreen>(
        find.byType(AdminSystemReportScreen),
      );
      expect(screen.initialRange!.start, DateTime(2026, 10, 9));
      expect(screen.initialRange!.end, DateTime(2026, 10, 9));
      expect(t.takeException(), isNull);
    },
  );
  for (var index = 0; index < 6; index++) {
    testWidgets('Admin module $index opens the existing functional screen', (
      t,
    ) async {
      await pump(t, admin());
      await press(t, find.byKey(Key('admin-module-$index')));
      expect(
        find.byType(
          [
            FacilitiesScreen,
            OwnerVerificationScreen,
            AdminPlayersScreen,
            ReviewsScreen,
            ActivitiesScreen,
            PlayGroupsScreen,
          ][index],
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Owner verification appears in dashboard and approval center', (
    t,
  ) async {
    final s = admin();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.submitOwnerVerification(
      name: 'Nguyễn Minh Phát',
      phone: DemoSession.phone,
      proof: sampleFacilityProof,
      expectedRevision: 0,
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, s);
    await press(t, find.text('Trung tâm duyệt'));
    expect(find.text('Hồ sơ chủ sân chờ xác minh'), findsOneWidget);
    await t.tap(find.text('Nguyễn Minh Phát'));
    await t.pumpAndSettle();
    expect(find.byType(AdminManagementDetailScreen), findsOneWidget);
    final detail = t.widget<AdminManagementDetailScreen>(
      find.byType(AdminManagementDetailScreen),
    );
    expect(detail.kind, 1);
    expect(detail.id, '__owner__');
    expect(find.text('Nguyễn Minh Phát'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('Standalone dashboard loses access after account change', (
    t,
  ) async {
    final s = admin();
    await pump(t, s, standalone: true);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.text('Chỉ Admin được truy cập.'), findsOneWidget);
    expect(find.byKey(const Key('admin-metric-users')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Role change resets admin tabs', (t) async {
    final s = admin();
    await pump(t, s);
    await t.tap(find.byKey(const Key('admin-nav-3')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('admin-nav-3')), findsNothing);
    expect(find.byType(AdminSystemReportScreen), findsNothing);
    expect(find.text('Trang chủ'), findsWidgets);
    expect(t.takeException(), isNull);
  });
}
