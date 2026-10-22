import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/facilities_screen.dart';
import 'package:test_do_an/screens/shifts_screen.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/owner_management_views.dart';
import 'package:test_do_an/screens/employee_access_screen.dart';
import 'package:test_do_an/screens/payout_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late String photo;
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
    final data = await rootBundle.load('assets/figma/c0697.png');
    photo = encodeProof(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
  DemoSession owner() {
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    addTearDown(s.dispose);
    return s;
  }

  FacilityProfile profile() => FacilityProfile(
    name: 'Sân Cầu Lông K99',
    sport: 'Cầu lông',
    address: '96 Chế Lan Viên, Tây Thạnh',
    city: 'TP.HCM',
    district: 'Tân Phú',
    phone: DemoSession.phone,
    ownerName: 'Nguyễn Văn Hùng',
    courtCount: 6,
    openHour: 6,
    closeHour: 23,
    baseRate: 110000,
    description: 'Sân trong nhà, hệ thống chiếu sáng đạt chuẩn.',
    cancelPolicy: 'Hủy trước 2 giờ theo chính sách cơ sở.',
    photo: photo,
    legalProof: photo,
    amenities: {'Bãi xe', 'Nước uống', 'Wi-Fi'},
  );
  Future<GlobalKey> pump(
    WidgetTester t,
    Widget screen, {
    double width = 402,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(const MyApp());
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
    for (final e in find.byType(Image).evaluate().toList()) {
      await t.runAsync(() => precacheImage((e.widget as Image).image, e));
    }
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, Finder finder) async {
    await t.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  for (final layout in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final view in ['staff', 'matches', 'facilities', 'profile', 'form']) {
      testWidgets('Owner management $view fits ${layout.$1}/${layout.$2}', (
        t,
      ) async {
        final s = owner();
        s.saveEmployee(
          name: 'Trần Đức Nam',
          phone: '0908111222',
          job: 'Điều phối',
          active: true,
        );
        s.saveEmployee(
          name: 'Lê Thu Hà',
          phone: '0918222333',
          job: 'Lễ tân',
          active: true,
        );
        s.saveEmployee(
          name: 'Phạm Tuấn Anh',
          phone: '0938333444',
          job: 'Thu ngân',
          active: false,
        );
        s.scheduleEmployeeShift('NS0001', DateTime(2026, 10, 9, 11), 4);
        final facility = s.saveFacility(profile());
        s.submitFacility(facility);
        s.saveActivity(
          title: 'Social Pickleball buổi tối',
          kind: DemoEventKind.social,
          start: DateTime(2026, 10, 9, 18),
          durationMinutes: 120,
          capacity: 16,
          fee: 80000,
          description: 'Giao lưu dành cho người chơi tại sân.',
        );
        final screen = switch (view) {
          'staff' => EmployeeRosterScreen(session: s),
          'matches' => ActivitiesScreen(session: s),
          'facilities' => FacilitiesScreen(session: s),
          'profile' => OwnerProfileView(session: s),
          _ => FacilityFormScreen(session: s),
        };
        final key = await pump(t, screen, width: layout.$1, scale: layout.$2);
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'owner-management-$view-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
        for (var i = 0; i < 8; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -280));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'owner-management-$view-bottom-${layout.$1.toInt()}-${layout.$2}',
          t,
        );
      });
    }
  }
  testWidgets(
    'Employee add, edit, search, permissions and shift navigation stay functional',
    (t) async {
      final s = owner();
      await pump(t, EmployeeRosterScreen(session: s));
      await press(t, find.byKey(const Key('roster-edit')));
      await t.enterText(
        find.byKey(const Key('owner-employee-name')),
        'Nguyễn Minh Anh',
      );
      await t.enterText(
        find.byKey(const Key('owner-employee-phone')),
        '0909876543',
      );
      await t.tap(find.byKey(const Key('owner-employee-save')));
      await t.pumpAndSettle();
      expect(s.employees.length, 1);
      await press(t, find.byKey(const Key('roster-edit-NS0001')));
      await t.enterText(
        find.byKey(const Key('owner-employee-name')),
        'Nguyễn Minh An',
      );
      await t.tap(find.byKey(const Key('owner-employee-save')));
      await t.pumpAndSettle();
      expect(s.employees.single.name, 'Nguyễn Minh An');
      await t.tap(find.byTooltip('Tìm nhân viên'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('roster-search')), 'khong co');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('roster-NS0001')), findsNothing);
      await t.enterText(find.byKey(const Key('roster-search')), 'minh an');
      await t.pumpAndSettle();
      await press(t, find.text('Phân quyền'));
      await t.tap(find.text('Nguyễn Minh An').last);
      await t.pumpAndSettle();
      expect(find.byType(EmployeeAccessScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await press(t, find.byKey(const Key('roster-shift-NS0001')));
      expect(find.byType(EmployeeDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Match cancellation requires confirmation and moves it to ended',
    (t) async {
      final s = owner();
      final activity = s.saveActivity(
        title: 'Giao lưu cuối tuần',
        kind: DemoEventKind.social,
        start: DateTime(2026, 10, 10, 18),
        durationMinutes: 120,
        capacity: 12,
        fee: 80000,
        description: 'Giao lưu tại sân dành cho mọi người.',
      );
      s.transitionActivity(activity.id, 'pending', activity.revision);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      final pending = s.managedActivities.single;
      s.transitionActivity(pending.id, 'approved', pending.revision);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await pump(t, ActivitiesScreen(session: s));
      await press(t, find.byKey(Key('owner-match-cancel-${activity.id}')));
      await t.enterText(find.byType(TextField).last, 'Không đủ người tham gia');
      await t.tap(find.byKey(const Key('finance-text-confirm')));
      await t.pumpAndSettle();
      expect(s.managedActivities.single.state, 'approved');
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(s.managedActivities.single.state, 'cancelled');
      await press(t, find.byKey(const Key('owner-match-phase-2')));
      expect(find.byKey(Key('activity-${activity.id}')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Employee dialog rejects a changed account', (t) async {
    final s = owner();
    await pump(t, EmployeeRosterScreen(session: s));
    await press(t, find.byKey(const Key('roster-edit')));
    await t.enterText(
      find.byKey(const Key('owner-employee-name')),
      'Nguyễn Minh Anh',
    );
    await t.enterText(
      find.byKey(const Key('owner-employee-phone')),
      '0909876543',
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('owner-employee-save')));
    await t.pumpAndSettle();
    expect(s.employees, isEmpty);
    expect(find.textContaining('Tài khoản đã thay đổi'), findsOneWidget);
    await t.tap(find.text('Hủy'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('Profile payout route and logout preserve role privacy', (
    t,
  ) async {
    final s = owner();
    await pump(t, OwnerProfileView(session: s));
    await press(t, find.text('Tài khoản nhận thanh toán'));
    expect(find.byType(PayoutAccountScreen), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await press(t, find.byKey(const Key('account-logout')));
    await t.tap(find.text('Tiếp tục'));
    await t.pumpAndSettle();
    expect(s.user, isNull);
    expect(find.text('Tài khoản của tôi'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Add facility submits once and never publishes before approval', (
    t,
  ) async {
    final s = owner();
    final p = profile();
    s.saveFacilityFormDraft(
      FacilityFormDraft(
        fields: {
          'name': p.name,
          'address': p.address,
          'city': p.city,
          'district': p.district,
          'phone': p.phone,
          'ownerName': p.ownerName,
          'courtCount': '6',
          'baseRate': '110000',
          'description': p.description,
          'cancelPolicy': p.cancelPolicy,
        },
        sport: p.sport,
        openHour: 6,
        closeHour: 23,
        photo: photo,
        legalProof: photo,
        amenities: p.amenities,
      ),
    );
    await pump(t, FacilityFormScreen(session: s));
    await press(t, find.byKey(const Key('facility-submit-application')));
    expect(s.managedFacilities.length, 1);
    expect(s.managedFacilities.single.state, 'pending');
    expect(s.publicFacilities, isEmpty);
    expect(find.byType(FacilityDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Submit without proof creates no orphan facility and preserves form',
    (t) async {
      final s = owner();
      final p = profile();
      s.saveFacilityFormDraft(
        FacilityFormDraft(
          fields: {
            'name': p.name,
            'address': p.address,
            'city': p.city,
            'district': p.district,
            'phone': p.phone,
            'ownerName': p.ownerName,
            'courtCount': '6',
            'baseRate': '110000',
            'description': '',
            'cancelPolicy': '',
          },
          sport: p.sport,
          openHour: 6,
          closeHour: 23,
        ),
      );
      await pump(t, FacilityFormScreen(session: s));
      await press(t, find.byKey(const Key('facility-submit-application')));
      expect(s.managedFacilities, isEmpty);
      expect(find.byKey(const Key('facility-form-error')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
