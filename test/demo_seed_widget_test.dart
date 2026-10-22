import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/demo/demo_seed_assets.dart';
import 'package:test_do_an/demo/demo_seed_data.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/employee_access_screen.dart';
import 'package:test_do_an/screens/owner_facility_edit_list_screen.dart';

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
  for (final width in [402.0, 320.0]) {
    testWidgets('Seeded manager direct login at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 879);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = width == 320 ? 2 : 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final photo = encodeProof(
        (await rootBundle.load('assets/figma/c0697.png')).buffer.asUint8List(),
      );
      final proof = (await tester.runAsync(createDemoSeedProof))!;
      expect(decodeProof(proof).length, greaterThan(100));
      final s = DemoSession(now: () => DateTime(2026, 10, 10, 10));
      s.installDemoFixtures(photo, proof: proof);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: EmployeePortalScreen(session: s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('employee-login-id')),
        demoManagerPhone,
      );
      await tester.enterText(
        find.byKey(const Key('employee-login-password')),
        demoSeedPassword,
      );
      await tester.ensureVisible(
        find.byKey(const Key('employee-login-submit')),
      );
      await tester.tap(find.byKey(const Key('employee-login-submit')));
      await tester.pumpAndSettle();
      expect(s.activeEmployee?.phone, demoManagerPhone);
      expect(find.byKey(const Key('employee-logout')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureHome(capture, 'demo-manager-${width.toInt()}', tester);
      s.logout();
      s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, demoSeedPassword);
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: theme,
            debugShowCheckedModeBanner: false,
            home: OwnerFacilityEditListScreen(session: s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('owner-edit-search')),
        'Phú Thọ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sân cầu lông Phú Thọ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureHome(capture, 'natural-venues-${width.toInt()}', tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      s.dispose();
    });
  }
}
