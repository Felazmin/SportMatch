import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/calendar_screen.dart';
import 'package:test_do_an/screens/facility_calendar_screen.dart';
import 'package:test_do_an/screens/facility_tariffs_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/dashboard_screen.dart';
import 'package:test_do_an/screens/reviews_screen.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';

import 'multi_facility_test.dart' show publishTestFacility;
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
    publishTestFacility(s);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    return s;
  }

  Future<GlobalKey> pump(WidgetTester t, Widget screen, double scale) async {
    t.view.physicalSize = Size(scale == 1 ? 402 : 320, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
    await t.pumpAndSettle();
    final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        key = GlobalKey();
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

  Future<void> press(WidgetTester t, String id) async {
    final f = find.byKey(Key(id));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Group cover picker save and approval render at $scale', (
      t,
    ) async {
      final s = open(), data = await rootBundle.load('assets/figma/c0697.png');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await pump(
        t,
        PlayGroupFormScreen(session: s, pickImage: () async => bytes),
        scale,
      );
      await t.enterText(
        find.byKey(const Key('play-group-name')),
        'Test cover group',
      );
      await t.enterText(
        find.byKey(const Key('play-group-description')),
        'A local test cover group',
      );
      await press(t, 'play-group-photo');
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(PlayGroupFormScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await press(t, 'play-group-save');
      final g = s.managedPlayGroups.single;
      expect(g.photo, isNotEmpty);
      s.transitionPlayGroup(g.id, 'pending', g.revision);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionPlayGroup(g.id, 'approved', 1);
      final key = await pump(
        t,
        PlayGroupDetailScreen(session: s, id: g.id),
        scale,
      );
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(PlayGroupDetailScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await captureHome(key, 'group-cover-approved-$scale', t);
      expect(t.takeException(), isNull);
    });
    testWidgets('Facility scoped dashboard fits $scale', (t) async {
      final s = open();
      final key = await pump(
        t,
        DashboardScreen(session: s, facilityId: 'CS0001'),
        scale,
      );
      expect(find.text('Cơ sở đa sân'), findsWidgets);
      expect(find.byKey(const Key('dashboard-occupancy')), findsOneWidget);
      await captureHome(key, 'facility-dashboard-$scale', t);
      expect(t.takeException(), isNull);
    });
    testWidgets('Facility public reviews and detail fit $scale', (t) async {
      var now = DateTime(2026, 10, 8, 10);
      final s = DemoSession(now: () => now);
      addTearDown(s.dispose);
      publishTestFacility(s);
      s.login(DemoSession.phone, DemoSession.password);
      final b = s.reserve(
        facilityId: 'CS0001',
        court: 8,
        start: DateTime(2026, 10, 9, 12),
        hours: 1,
        contact: 'Test guest',
        contactPhone: DemoSession.phone,
      );
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.confirmVenuePayment(b);
      now = b.start;
      s.setAttendance(b.id, DemoAttendance.checkedIn);
      now = b.end;
      s.setAttendance(b.id, DemoAttendance.completed);
      s.login(DemoSession.phone, DemoSession.password);
      s.submitVenueReview(b.id, 4, 'Good venue and service');
      s.logout();
      final key = await pump(
        t,
        ReviewsScreen(session: s, facilityId: 'CS0001'),
        scale,
      );
      expect(find.text('4.0 / 5 · 1 đánh giá công khai'), findsOneWidget);
      await captureHome(key, 'facility-reviews-$scale', t);
      await press(t, 'review-${b.id}');
      expect(find.byType(ReviewDetailScreen), findsOneWidget);
      expect(find.text('Cơ sở đa sân'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('Facility calendar lock and manual entry work at $scale', (
      t,
    ) async {
      final s = open();
      await pump(t, FacilityCalendarScreen(session: s, id: 'CS0001'), scale);
      await press(t, 'facility-calendar-lock');
      expect(find.byType(CalendarEditorScreen), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('calendar-reason')),
        'Maintenance test',
      );
      await press(t, 'calendar-save');
      await press(t, 'finance-confirm');
      expect(s.courtBlocks.single.facilityId, 'CS0001');
      await press(t, 'calendar-close');
      await press(t, 'facility-calendar-manual');
      await t.enterText(
        find.byKey(const Key('calendar-contact')),
        'Test guest',
      );
      await t.enterText(
        find.byKey(const Key('calendar-phone')),
        DemoSession.phone,
      );
      // Select another court because court one is locked at opening time.
      await press(t, 'calendar-court');
      await t.tap(find.text('Sân 2').last);
      await t.pumpAndSettle();
      await press(t, 'calendar-save');
      await press(t, 'finance-confirm');
      final created = s.managedBookings.singleWhere(
        (b) => b.facilityId == 'CS0001',
      );
      expect(created.court, 2);
      expect(created.total, 150000);
      expect(t.takeException(), isNull);
    });
    testWidgets('Facility tariff editor submit and Admin approval fit $scale', (
      t,
    ) async {
      final s = open(),
          key = await pump(
            t,
            FacilityTariffsScreen(session: s, id: 'CS0001'),
            scale,
          );
      await press(t, 'facility-tariff-add');
      await t.enterText(find.byKey(const Key('facility-band-rate')), '220000');
      await t.enterText(
        find.byKey(const Key('facility-band-surcharge')),
        '10000',
      );
      await press(t, 'facility-band-save');
      await press(t, 'facility-tariff-submit');
      await press(t, 'finance-confirm');
      expect(s.facilityTariffPlan('CS0001').state, 'pending');
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      await press(t, 'facility-tariff-approve');
      await press(t, 'finance-confirm');
      expect(s.facilityTariffPlan('CS0001').state, 'approved');
      expect(
        s.bookingRates(1, DateTime(2026, 10, 9, 18), 1, facilityId: 'CS0001'),
        [230000],
      );
      await captureHome(key, 'facility-tariff-approved-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'Facility tariff pending entry opens from Admin approval center',
    (t) async {
      final s = open();
      s.submitFacilityTariffs('CS0001', [], expectedRevision: 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      await pump(t, ApprovalCenterScreen(session: s), 1);
      await press(t, 'approval-facility-pricing-CS0001');
      expect(find.byType(FacilityTariffsScreen), findsOneWidget);
    },
  );
}
