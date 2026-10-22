import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_cancellation_policy.dart';
import 'package:test_do_an/demo/demo_facilities.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/cancellation_policy_screen.dart';
import 'package:test_do_an/screens/facilities_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'multi_facility_test.dart' show publishTestFacility;

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
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s,
    double scale, {
    DemoFacility? facility,
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CancellationPolicyScreen(
                      session: s,
                      facility: facility,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    return key;
  }

  Future<void> reach(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    await reach(t, key);
    await t.enterText(find.byKey(Key(key)), text);
    await t.pump();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Admin policy edit and password confirmation fit $scale', (
      t,
    ) async {
      final s = open();
      s.loginStaff(
        DemoRole.admin,
        DemoSession.adminEmail,
        DemoSession.password,
      );
      final key = await pump(t, s, scale);
      await enter(t, 'policy-threshold', '6');
      await enter(t, 'policy-early', '90');
      await enter(t, 'policy-late', '25');
      await enter(t, 'policy-minimum', '1');
      await enter(t, 'policy-password', DemoSession.password);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      await reach(t, 'policy-save');
      await captureHome(key, 'cancellation-policy-$scale', t);
      await t.tap(find.byKey(const Key('policy-save')));
      await t.pumpAndSettle();
      expect(
        s.primaryCancellationPolicy,
        CancellationPolicy(
          thresholdHours: 6,
          earlyPercent: 90,
          latePercent: 25,
          minimumHours: 1,
        ),
      );
      expect(find.byType(CancellationPolicyScreen), findsNothing);
      expect(t.takeException(), isNull);
    });
    testWidgets('Owner policy saves only a draft before review at $scale', (
      t,
    ) async {
      final s = open(), f = publishTestFacility(open());
      final own = publishTestFacility(s);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await pump(t, s, scale, facility: own);
      await enter(t, 'policy-early', '80');
      await reach(t, 'policy-save');
      await t.tap(find.byKey(const Key('policy-save')));
      await t.pumpAndSettle();
      expect(own.draft.cancellationPolicy.earlyPercent, 80);
      expect(own.published!.cancellationPolicy.earlyPercent, 95);
      expect(own.state, 'draft');
      expect(f.published!.cancellationPolicy.earlyPercent, 95);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Stale primary editor reports conflict instead of overwriting', (
    t,
  ) async {
    final s = open();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await pump(t, s, 1);
    await enter(t, 'policy-password', DemoSession.password);
    s.setPrimaryCancellationPolicy(
      CancellationPolicy(thresholdHours: 4, earlyPercent: 75, latePercent: 25),
      expectedRevision: 0,
      password: DemoSession.password,
    );
    await reach(t, 'policy-save');
    await t.tap(find.byKey(const Key('policy-save')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('policy-error')), findsOneWidget);
    expect(s.primaryCancellationPolicy.earlyPercent, 75);
  });
  testWidgets('Player cannot configure policies', (t) async {
    final s = open();
    s.login(DemoSession.phone, DemoSession.password);
    await pump(t, s, 1);
    expect(find.byKey(const Key('policy-save')), findsNothing);
    expect(find.text('Chưa có quyền truy cập.'), findsOneWidget);
  });
  testWidgets('Owner can reach policy form from facility detail', (t) async {
    final s = open(), own = publishTestFacility(open());
    final f = publishTestFacility(s);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpWidget(
      MaterialApp(
        home: FacilityDetailScreen(session: s, facility: f),
      ),
    );
    await t.pumpAndSettle();
    await reach(t, 'facility-policy-edit');
    await t.tap(find.byKey(const Key('facility-policy-edit')));
    await t.pumpAndSettle();
    expect(find.byType(CancellationPolicyScreen), findsOneWidget);
    expect(own.id, f.id);
  });
}
