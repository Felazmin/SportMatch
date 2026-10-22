import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/court_types_screen.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';

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
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
  }

  testWidgets('Owner submits via UI and Admin approves from queue', (t) async {
    final s = open();
    await pump(t, CourtTypesScreen(session: s));
    await press(t, find.byKey(const Key('court-type-add')));
    await t.enterText(find.byKey(const Key('court-type-name')), 'Cầu lông PVC');
    await t.enterText(
      find.byKey(const Key('court-type-description')),
      'Mặt thảm chống trượt',
    );
    await press(t, find.byKey(const Key('court-type-save')));
    await press(t, find.byKey(const Key('court-type-pending-LS0001')));
    await press(t, find.byKey(const Key('court-type-confirm')));
    expect(s.managedCourtTypes.single.state, 'pending');
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, ApprovalCenterScreen(session: s));
    await press(t, find.byKey(const Key('approval-court-type-LS0001')));
    await press(t, find.byKey(const Key('court-type-approved-LS0001')));
    await press(t, find.byKey(const Key('court-type-confirm')));
    expect(s.approvedCourtTypes.single.id, 'LS0001');
    expect(t.takeException(), isNull);
  });
  testWidgets('Role changes during confirmation cannot approve', (t) async {
    final s = open();
    s.saveCourtType(
      name: 'Cầu lông PVC',
      sport: 'Cầu lông',
      description: 'Mặt thảm chống trượt',
    );
    s.transitionCourtType('LS0001', 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, CourtTypesScreen(session: s));
    await press(t, find.byKey(const Key('court-type-approved-LS0001')));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await press(t, find.byKey(const Key('court-type-confirm')));
    expect(s.managedCourtTypes.single.state, 'pending');
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Registry and facility selection fit at scale $scale', (
      t,
    ) async {
      final s = open();
      s.saveCourtType(
        name: 'Cầu lông PVC chống trượt trong nhà',
        sport: 'Cầu lông',
        description: 'Mặt thảm thể thao chống trượt',
      );
      s.transitionCourtType('LS0001', 'pending', 0);
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      s.transitionCourtType('LS0001', 'approved', 1);
      final key = await pump(t, CourtTypesScreen(session: s), scale: scale);
      await captureHome(key, 'court-types-$scale', t);
      expect(t.takeException(), isNull);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final form = await pump(t, FacilityFormScreen(session: s), scale: scale);
      final dropdown = find.byKey(
        const ValueKey('facility-court-type-Cầu lông-'),
      );
      await press(t, dropdown);
      expect(find.text('Cầu lông PVC chống trượt trong nhà'), findsOneWidget);
      await press(t, find.text('Cầu lông PVC chống trượt trong nhà'));
      await captureHome(form, 'facility-court-type-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
}
