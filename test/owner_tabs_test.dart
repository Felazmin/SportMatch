import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/customers_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/owner_tabs_screen.dart';
import 'package:test_do_an/screens/facility_calendar_screen.dart';
import 'package:test_do_an/screens/facility_tariffs_screen.dart';
import 'package:test_do_an/screens/shifts_screen.dart';
import 'package:test_do_an/screens/owner_facility_edit_list_screen.dart';
import 'package:test_do_an/screens/facility_pending_screen.dart';
import 'package:test_do_an/screens/workflow_screen.dart';
import 'package:test_do_an/venues/venue_map_service.dart';

import 'customer_tabs_test.dart' as map_test;
import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show publishTestFacility;

void main() {
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFFE9EFE8), BlendMode.src);
    final image = await recorder.endRecording().toImage(16, 16);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    map_test.testTileBytes = bytes!.buffer.asUint8List();
    image.dispose();
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  setUp(() => VenueMapService.instance = map_test.TestMapService());
  tearDown(() => VenueMapService.instance = VenueMapService());

  Future<(DemoSession, GlobalKey)> home(
    WidgetTester t, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    await s.initialize();
    final live = publishTestFacility(s, name: 'Cơ sở đang hoạt động');
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    final validProfile = FacilityProfile.fromJson({
      ...live.draft.toJson(),
      'photo': base64Encode(map_test.testTileBytes),
      'legalProof': base64Encode(map_test.testTileBytes),
    });
    s.saveFacility(validProfile, facility: live);
    s.submitFacility(live);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.reviewFacility(live, approve: true);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.saveFacility(live.draft);
    s.saveActivity(
      title: 'Giao lưu cuối tuần',
      kind: DemoEventKind.social,
      start: DateTime(2026, 10, 11, 18),
      durationMinutes: 120,
      capacity: 12,
      fee: 60000,
      description: 'Giao lưu cầu lông dành cho mọi trình độ.',
    );
    addTearDown(s.dispose);
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MyApp(session: s),
      ),
    );
    await t.pumpAndSettle();
    return (s, key);
  }

  Future<void> press(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  testWidgets('Owner tabs differ from customer and navigate to management', (
    t,
  ) async {
    await home(t);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('NVH ACADEMY'), findsNothing);
    await press(t, find.byKey(const Key('owner-action-customers')));
    expect(find.byType(CustomersScreen), findsOneWidget);
    await t.tap(find.byTooltip('Quay lại'));
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('owner-action-employees')));
    expect(find.byType(EmployeeRosterScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.text('Khám phá').last);
    expect(find.text('Quản lý trận đấu'), findsOneWidget);
    expect(find.text('Giao lưu cuối tuần'), findsOneWidget);
    await press(t, find.byKey(const Key('owner-create-activity')));
    expect(find.byType(ActivityFormScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.text('Nổi bật').last);
    expect(find.text('Sân của tôi'), findsOneWidget);
    await press(t, find.byKey(const Key('owner-venue-calendar-CS0001')));
    expect(find.byType(FacilityCalendarScreen), findsOneWidget);
    expect(
      t.widget<FacilityCalendarScreen>(find.byType(FacilityCalendarScreen)).id,
      'CS0001',
    );
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('owner-venue-prices-CS0001')));
    expect(
      t.widget<FacilityTariffsScreen>(find.byType(FacilityTariffsScreen)).id,
      'CS0001',
    );
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('owner-venue-CS0002')));
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Dashboard matches supplied actions and selected facility routes',
    (t) async {
      await home(t);
      final labels = [
        'Lịch sân',
        'Sân của tôi',
        'Thêm sân',
        'Chỉnh sửa sân',
        'Chờ duyệt',
        'Bảng giá',
        'Doanh thu',
        'Khách hàng',
        'Nhân viên',
        'Quản lý trận đấu',
        'Chi tiết đặt sân',
        'Hồ sơ',
      ];
      final actions = find.byWidgetPredicate(
        (w) =>
            w is InkWell &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('owner-action-'),
      );
      expect(actions, findsNWidgets(12));
      final actionLabels = actions
          .evaluate()
          .map(
            (e) => find
                .descendant(
                  of: find.byWidget(e.widget),
                  matching: find.byType(Text),
                )
                .evaluate()
                .map((t) => (t.widget as Text).data)
                .single,
          )
          .toList();
      expect(actionLabels, labels);
      expect(find.text('Giờ sân còn trống'), findsNothing);
      expect(find.text('Giá trị xác nhận'), findsNothing);
      expect(find.text('Sân hoạt động'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      await press(t, find.byKey(const Key('owner-action-add')));
      expect(find.byType(FacilityFormScreen), findsOneWidget);
      expect(
        t.widget<FacilityFormScreen>(find.byType(FacilityFormScreen)).facility,
        isNull,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('owner-action-edit')));
      expect(find.byType(OwnerFacilityEditListScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('owner-action-requests')));
      expect(find.byType(OwnerPendingFacilitiesScreen), findsOneWidget);
      expect(find.text('Chưa có hồ sơ sân đang chờ duyệt.'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await press(t, find.byKey(const ValueKey('owner-facility-')));
      await t.tap(find.text('Cơ sở đang hoạt động').last);
      await t.pumpAndSettle();
      expect(find.text('8/8'), findsOneWidget);
      await press(t, find.byKey(const Key('owner-action-edit')));
      expect(find.byType(OwnerFacilityEditListScreen), findsOneWidget);
      await press(t, find.byKey(const Key('owner-edit-facility-CS0001')));
      expect(
        t
            .widget<FacilityFormScreen>(find.byType(FacilityFormScreen))
            .facility!
            .id,
        'CS0001',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Owner map includes private facility, opens correct management, clears on player switch',
    (t) async {
      final (s, _) = await home(t);
      expect(s.ownerMapVenues.map((v) => v.id), contains('CS0002'));
      expect(s.currentVenues.map((v) => v.id), isNot(contains('CS0002')));
      await press(t, find.text('Bản đồ').last);
      expect(find.text('Bản đồ cơ sở'), findsOneWidget);
      expect(find.byKey(const Key('map-marker-CS0002')), findsOneWidget);
      await press(t, find.byTooltip('Danh sách sân'));
      await press(t, find.byKey(const Key('map-select-CS0002')));
      await press(t, find.text('Quản lý sân'));
      expect(
        t
            .widget<FacilityDetailScreen>(find.byType(FacilityDetailScreen))
            .facility
            .id,
        'CS0002',
      );
      await t.pageBack();
      await t.pumpAndSettle();
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      expect(find.byType(OwnerDashboardTab), findsNothing);
      await press(t, find.text('Bản đồ').last);
      expect(find.text('Bản đồ quanh bạn'), findsOneWidget);
      expect(find.byKey(const Key('map-marker-CS0002')), findsNothing);
      expect(() => s.ownerMapVenues, throwsStateError);
      expect(t.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Dashboard booking card and details at text scale $scale', (
      t,
    ) async {
      final (s, key) = await home(t, width: 320, scale: scale);
      s.login(DemoSession.phone, DemoSession.password);
      final start = DateTime(2026, 10, 9, 18);
      final booking = s.reserve(
        court: 2,
        start: start,
        hours: 1,
        contact: 'Nguyễn Minh Anh',
        contactPhone: DemoSession.phone,
        quotedRate: s.courtRate(2, start),
      );
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      expect(find.text('1 lịch cần xác nhận'), findsOneWidget);
      final card = find.byKey(Key('owner-booking-${booking.id}'));
      await t.ensureVisible(card);
      await t.pumpAndSettle();
      await captureHome(key, 'owner-dashboard-booking-320-$scale', t);
      expect(t.takeException(), isNull);
      await press(
        t,
        find.descendant(of: card, matching: find.text('Chi tiết đặt sân')),
      );
      expect(find.byType(WorkflowDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  for (final viewport in [(402.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    for (final tab in ['Trang chủ', 'Khám phá', 'Nổi bật', 'Bản đồ']) {
      testWidgets('Owner $tab renders ${viewport.$1}/${viewport.$2}', (
        t,
      ) async {
        final (_, key) = await home(t, width: viewport.$1, scale: viewport.$2);
        await press(t, find.text(tab).last);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await t.pumpAndSettle();
        await captureHome(
          key,
          'owner-${tab == 'Trang chủ'
              ? 'dashboard'
              : tab == 'Khám phá'
              ? 'activities'
              : tab == 'Nổi bật'
              ? 'facilities'
              : 'map-fixture'}-${viewport.$1.toInt()}-${viewport.$2}',
          t,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
