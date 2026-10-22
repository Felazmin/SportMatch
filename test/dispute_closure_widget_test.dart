import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/demo/demo_finance.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/finance_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  final now = DateTime(2026, 10, 7, 10);
  (DemoSession, DemoDispute) fixture({bool refund = false}) {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    s.login(DemoSession.phone, DemoSession.password);
    final ticket = s.joinEvent(
      eventId: demoEvents.first.id,
      start: demoEvents.first.start(now),
      quantity: 1,
      contact: 'Test User',
      contactPhone: DemoSession.phone,
    );
    final d = s.createTicketDispute(
      ticket,
      'Review cancellation',
      'Please review the original decision',
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.decideDispute(d, DemoDisputeDecision.uphold, 'Keep the original result');
    return (s, d);
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s,
    DemoDispute d, {
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
          home: DisputeDetailScreen(session: s, dispute: d),
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
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('Admin confirmation closes once and player sees closed result', (
    t,
  ) async {
    final (s, d) = fixture();
    await pump(t, s, d);
    await press(t, 'dispute-close');
    expect(d.closedAt, isNull);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(d.closedAt, now);
    expect(find.byKey(const Key('dispute-close')), findsNothing);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.text('Đã thực hiện · Đã đóng'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Role switch while confirmation is open cannot close', (t) async {
    final (s, d) = fixture();
    await pump(t, s, d);
    await press(t, 'dispute-close');
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(d.closedAt, isNull);
    expect(find.byKey(const Key('dispute-close')), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Closed dispute fits text scale $scale', (t) async {
      final (s, d) = fixture();
      s.closeDispute(d);
      final key = await pump(t, s, d, scale: scale);
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(ListView), const Offset(0, -250));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await captureHome(
        key,
        'dispute-closed-${scale == 1 ? 'normal' : 'large'}',
        t,
      );
    });
  }
}
