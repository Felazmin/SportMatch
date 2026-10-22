import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/approval_center_screen.dart';
import 'package:test_do_an/screens/finance_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 7, 10);
  DemoSession open() {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    return s;
  }

  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  DemoDispute caseFor(DemoSession s) {
    s.login(DemoSession.phone, DemoSession.password);
    return s.createDispute(
      s.bookings.first,
      'Review booking result',
      'Please review the original booking result',
    );
  }

  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
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

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
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

  testWidgets('Only Admin sees case queue; logout removes data', (t) async {
    final s = open();
    final d = caseFor(s);
    await pump(t, ApprovalCenterScreen(session: s));
    expect(find.byKey(Key('approval-dispute-${d.id}')), findsNothing);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('approval-count')), findsNothing);
    admin(s);
    await t.pumpAndSettle();
    expect(find.text('1 công việc đang chờ'), findsOneWidget);
    s.logout();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('approval-count')), findsNothing);
  });
  testWidgets(
    'Search/filter and actual case navigation; closure removes pending item',
    (t) async {
      final s = open();
      final d = caseFor(s);
      admin(s);
      await pump(t, ApprovalCenterScreen(session: s));
      await t.enterText(find.byKey(const Key('approval-search')), 'no match');
      await t.pumpAndSettle();
      expect(find.text('Không có công việc phù hợp.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('approval-search')), d.id);
      await t.pumpAndSettle();
      await press(t, 'approval-filter-dispute');
      await press(t, 'approval-dispute-${d.id}');
      expect(find.byType(DisputeDetailScreen), findsOneWidget);
      s.decideDispute(
        d,
        DemoDisputeDecision.uphold,
        'Keep original booking result',
      );
      s.closeDispute(d);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('0 công việc đang chờ'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Management entry opens center', (t) async {
    final s = open();
    admin(s);
    await pump(t, ManagementScreen(session: s));
    await press(t, 'management-approval-center');
    expect(find.byType(ApprovalCenterScreen), findsOneWidget);
  });
  for (final scale in [1.0, 2.0]) {
    for (final populated in [false, true]) {
      testWidgets('Approval center populated=$populated fits $scale', (
        t,
      ) async {
        final s = open();
        if (populated) caseFor(s);
        admin(s);
        final key = await pump(
          t,
          ApprovalCenterScreen(session: s),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        await captureHome(
          key,
          'approval-${populated ? 'cases' : 'empty'}-${scale == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 5; i++) {
          await t.drag(find.byType(ListView), const Offset(0, -250));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
      });
    }
  }
}
