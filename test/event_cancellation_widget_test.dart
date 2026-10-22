import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/screens/events_screen.dart';
import 'package:test_do_an/screens/activities_screen.dart';

void main() {
  final date = DateTime(2026, 10, 9, 10);
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
  Widget app(DemoSession s, {double scale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: EventDetailScreen(
      session: s,
      event: demoEvents.first,
      start: demoEvents.first.start(date),
    ),
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Owner confirms whole cancellation at $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = open();
      owner(s);
      await tester.pumpWidget(app(s, scale: scale));
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-cancel-occurrence')),
        250,
      );
      await tester.ensureVisible(
        find.byKey(const Key('event-cancel-occurrence')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-cancel-occurrence')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('event-cancel-reason')),
        'Sân bảo trì',
      );
      await tester.tap(find.byKey(const Key('event-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(
        s.eventCancellation(demoEvents.first.id, demoEvents.first.start(date)),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('event-register')), findsNothing);
    });
  }
  testWidgets(
    'Player cannot cancel whole event and cancelled date disables joining',
    (tester) async {
      final s = open();
      owner(s);
      s.cancelEventOccurrence(
        demoEvents.first.id,
        demoEvents.first.start(date),
        'Sân bảo trì',
      );
      s.login(DemoSession.phone, DemoSession.password);
      await tester.pumpWidget(app(s));
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-register')),
        200,
      );
      expect(find.byKey(const Key('event-cancel-occurrence')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('event-register')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('Manager catalog is reachable from activity management', (
    tester,
  ) async {
    final s = open();
    owner(s);
    await tester.pumpWidget(MaterialApp(home: ActivitiesScreen(session: s)));
    await tester.tap(find.byKey(const Key('activity-seeded-events')));
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
  });
  testWidgets(
    'Manager can open a future ticket cohort after catalog changes day',
    (t) async {
      var clock = date;
      final s = DemoSession(now: () => clock);
      addTearDown(s.dispose);
      s.login(DemoSession.phone, DemoSession.password);
      final e = demoEvents.first;
      final ticket = s.joinEvent(
        eventId: e.id,
        start: e.start(clock),
        quantity: 1,
        contact: 'Test Player',
        contactPhone: DemoSession.phone,
      );
      clock = clock.add(const Duration(days: 1));
      owner(s);
      await t.pumpWidget(MaterialApp(home: EventsScreen(session: s)));
      await t.tap(
        find.byKey(
          Key('event-cohort-${e.id}-${ticket.start.toIso8601String()}'),
        ),
      );
      await t.pumpAndSettle();
      final button = find.byKey(const Key('event-cancel-occurrence'));
      await t.ensureVisible(button);
      expect(t.widget<OutlinedButton>(button).onPressed, isNotNull);
    },
  );
}
