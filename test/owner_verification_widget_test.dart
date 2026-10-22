import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/owner_verification_screen.dart';
import 'package:test_do_an/screens/employee_access_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'multi_facility_test.dart' show sampleFacilityProof, publishTestFacility;
import 'home_accessibility_test.dart' show captureHome;

void main() {
  late Uint8List proof;
  setUpAll(() async {
    final data = await rootBundle.load('assets/figma/c0697.png');
    proof = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Owner evidence submission and Admin approval fit $scale', (
      t,
    ) async {
      final s = open();
      final key = await pump(
        t,
        OwnerVerificationScreen(session: s, pickImage: () async => proof),
        scale: scale,
      );
      await t.enterText(
        find.byKey(const Key('owner-verification-name')),
        'Nguyễn Minh Phát',
      );
      await press(t, 'owner-verification-proof');
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(OwnerVerificationScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await press(t, 'owner-verification-submit');
      await press(t, 'finance-confirm');
      expect(s.ownerVerification!.state, 'pending');
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(OwnerVerificationScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await captureHome(key, 'owner-verification-pending-$scale', t);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      final detail = await pump(
        t,
        OwnerVerificationScreen(session: s),
        scale: scale,
      );
      await t.enterText(
        find.byKey(const Key('owner-verification-password')),
        DemoSession.password,
      );
      await press(t, 'owner-verification-approve');
      await press(t, 'finance-confirm');
      expect(s.ownerVerification!.state, 'verified');
      await t.runAsync(
        () => precacheImage(
          t.widget<Image>(find.byType(Image)).image,
          t.element(find.byType(OwnerVerificationScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(t.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      await captureHome(detail, 'owner-verification-approved-$scale', t);
      expect(t.takeException(), isNull);
    });
    testWidgets('Employee facility scope selection works at $scale', (t) async {
      final s = open();
      final f = publishTestFacility(s);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      s.saveEmployee(
        name: 'Nhân viên thử',
        phone: '0912345678',
        job: 'Lễ tân',
        active: true,
      );
      final key = await pump(
        t,
        EmployeeAccessScreen(session: s, id: 'NS0001'),
        scale: scale,
      );
      await press(t, 'employee-permission-schedule');
      await t.enterText(
        find.byKey(const Key('employee-new-password')),
        'Employee123',
      );
      await press(t, 'employee-scope-all');
      await press(t, 'employee-scope-primary');
      await press(t, 'employee-scope-${f.id}');
      await t.enterText(
        find.byKey(const Key('employee-manager-password')),
        DemoSession.password,
      );
      await press(t, 'employee-access-save');
      expect(s.employeeAccess('NS0001')!.facilityIds, {f.id});
      await captureHome(key, 'employee-scope-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Role switch during Admin confirmation blocks review', (t) async {
    final s = open();
    s.submitOwnerVerification(
      name: 'Nguyễn Minh Phát',
      phone: DemoSession.phone,
      proof: sampleFacilityProof,
      expectedRevision: 0,
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, OwnerVerificationScreen(session: s));
    await t.enterText(
      find.byKey(const Key('owner-verification-password')),
      DemoSession.password,
    );
    await press(t, 'owner-verification-approve');
    s.login(DemoSession.phone, DemoSession.password);
    await press(t, 'finance-confirm');
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    expect(s.ownerVerification!.state, 'pending');
    expect(t.takeException(), isNull);
  });
  testWidgets('Management entry opens actual owner profile', (t) async {
    final s = open();
    await pump(t, ManagementScreen(session: s));
    await press(t, 'management-owner-verification');
    expect(find.byType(OwnerVerificationScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Unreadable image shows explicit fallback without crashing', (
    t,
  ) async {
    final s = open();
    s.submitOwnerVerification(
      name: 'Nguyễn Minh Phát',
      phone: DemoSession.phone,
      proof: sampleFacilityProof,
      expectedRevision: 0,
    );
    await pump(t, OwnerVerificationScreen(session: s));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    expect(find.text('Không thể mở ảnh hồ sơ.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
