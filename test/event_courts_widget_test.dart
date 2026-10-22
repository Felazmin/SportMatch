import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/screens/event_courts_screen.dart';
import 'package:test_do_an/screens/calendar_screen.dart';
import 'package:test_do_an/main.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  Future<void> reach(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 200);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }

  final date = DateTime(2026, 10, 9, 10), event = demoEvents.first;
  DemoSession open() {
    final s = DemoSession(now: () => date);
    addTearDown(s.dispose);
    return s;
  }

  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  Widget app(DemoSession s, {double scale = 1, ThemeData? theme}) =>
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: EventCourtsScreen(
          session: s,
          event: event,
          start: event.start(date),
        ),
      );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Court controls commit at $scale', (t) async {
      t.view.physicalSize = const Size(320, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = open();
      owner(s);
      await t.pumpWidget(const MyApp());
      await t.pumpAndSettle();
      final theme = t.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      final capture = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: app(s, scale: scale, theme: theme),
        ),
      );
      await reach(t, 'event-court-2');
      await t.tap(find.byKey(const Key('event-court-2')));
      await reach(t, 'event-courts-save');
      await captureHome(capture, 'event-courts-$scale', t);
      await t.tap(find.byKey(const Key('event-courts-save')));
      await t.pumpAndSettle();
      expect(s.eventCourts(event.id, event.start(date)).single.court, 2);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Stale editor cannot replace newer allocation', (t) async {
    final s = open();
    owner(s);
    await t.pumpWidget(app(s));
    s.allocateEventCourts(event.id, event.start(date), [
      1,
    ], expectedBlockIds: []);
    await t.tap(find.byKey(const Key('event-court-2')));
    await t.tap(find.byKey(const Key('event-courts-save')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('event-courts-error')), findsOneWidget);
    expect(s.eventCourts(event.id, event.start(date)).single.court, 1);
  });
  testWidgets('Player cannot access allocation controls', (t) async {
    final s = open();
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpWidget(app(s));
    expect(find.byKey(const Key('event-courts-save')), findsNothing);
  });
  testWidgets('Event lock opens allocation editor from calendar', (t) async {
    final s = open();
    owner(s);
    s.allocateEventCourts(event.id, event.start(date), [
      2,
    ], expectedBlockIds: []);
    await t.pumpWidget(MaterialApp(home: CalendarScreen(session: s)));
    final button = find.byKey(const Key('calendar-unblock-KB0001'));
    await t.scrollUntilVisible(
      button,
      500,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(EventCourtsScreen), findsOneWidget);
    expect(s.eventCourts(event.id, event.start(date)), hasLength(1));
  });
  testWidgets('Failed disk write retries existing allocation without new IDs', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = DemoSession(store: store, now: () => date);
    addTearDown(s.dispose);
    await s.initialize();
    owner(s);
    await s.flush();
    store.failWrite = true;
    await t.pumpWidget(app(s));
    await t.tap(find.byKey(const Key('event-court-2')));
    await t.tap(find.byKey(const Key('event-courts-save')));
    await t.pumpAndSettle();
    final id = s.eventCourts(event.id, event.start(date)).single.id;
    expect(find.byKey(const Key('event-courts-error')), findsOneWidget);
    store.failWrite = false;
    await t.tap(find.byKey(const Key('event-courts-save')));
    await t.pumpAndSettle();
    expect(s.eventCourts(event.id, event.start(date)).single.id, id);
    expect(s.saveFailed, isFalse);
  });
}
