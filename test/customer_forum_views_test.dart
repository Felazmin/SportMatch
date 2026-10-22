import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/screens/customer_forum_views.dart';
import 'package:test_do_an/screens/events_screen.dart';
import 'package:test_do_an/screens/customer_tournament_checkout_screen.dart';
import 'package:test_do_an/screens/auth_screen.dart';
import 'package:test_do_an/main.dart';

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
  DemoSession session({bool guest = false}) {
    final s = DemoSession(now: () => DateTime(2026, 10, 10, 8));
    addTearDown(s.dispose);
    if (!guest) {
      s.login(DemoSession.phone, DemoSession.password);
    }
    return s;
  }

  Future<GlobalKey> open(
    WidgetTester t,
    Widget screen, {
    bool large = false,
  }) async {
    t.view.physicalSize = Size(large ? 320 : 402, 879);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
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
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Widget detail(DemoSession s, int index) => CustomerEventDetailScreen(
    session: s,
    event: demoEvents[index],
    start: demoEvents[index].start(s.now),
  );
  for (final large in [false, true]) {
    for (var i = 0; i < 3; i++) {
      final index = i;
      testWidgets('Forum reference view $index large=$large', (t) async {
        final s = session();
        final key = await open(
          t,
          index == 0
              ? CustomerForumScreen(session: s)
              : detail(s, index == 1 ? 0 : 2),
          large: large,
        );
        expect(t.takeException(), isNull);
        await captureHome(key, 'forum-$index-${large ? 'large' : 'normal'}', t);
        for (var j = 0; j < 8; j++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -400));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (find.byType(CalendarDatePicker).evaluate().isNotEmpty && j == 2) {
            await captureHome(
              key,
              'forum-$index-calendar-${large ? 'large' : 'normal'}',
              t,
            );
          }
        }
        await captureHome(
          key,
          'forum-$index-bottom-${large ? 'large' : 'normal'}',
          t,
        );
      });
    }
  }
  testWidgets('Forum search and categories route to both detail screens', (
    t,
  ) async {
    final s = session();
    await open(t, CustomerForumScreen(session: s));
    await t.enterText(find.byKey(const Key('forum-search')), 'buoi toi');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('forum-join-social-evening')), findsOneWidget);
    expect(find.byKey(const Key('forum-join-social-morning')), findsNothing);
    await press(t, 'forum-join-social-evening');
    expect(find.text('Chi phí & Lịch trình'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('forum-search')), '');
    await t.pumpAndSettle();
    await press(t, 'forum-mode-3');
    await press(t, 'forum-tournament-tournament-doubles');
    expect(find.text('Chi tiết giải đấu'), findsOneWidget);
    expect(find.text('Phí tham gia'), findsOneWidget);
  });
  for (final index in [0, 2]) {
    testWidgets('Detail $index registers through confirmation and ticket', (
      t,
    ) async {
      final s = session();
      await open(t, detail(s, index));
      await press(t, 'customer-event-register');
      expect(
        find.byType(
          index == 2
              ? CustomerTournamentRegistrationScreen
              : EventRegistrationScreen,
        ),
        findsOneWidget,
      );
      if (index == 2) {
        await t.scrollUntilVisible(
          find.byKey(const Key('tournament-year')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(find.byKey(const Key('tournament-year')), '1995');
        await t.enterText(
          find.byKey(const Key('tournament-email')),
          'bao@example.com',
        );
        await t.enterText(
          find.byKey(const Key('event-team')),
          'Đội thử nghiệm',
        );
        await t.enterText(find.byKey(const Key('event-partner')), 'Nguyễn An');
        await press(t, 'tournament-terms');
      }
      await press(t, 'event-submit');
      if (index != 2) await press(t, 'event-confirm');
      expect(s.participations.single.eventId, demoEvents[index].id);
      expect(
        find.byType(
          index == 2
              ? CustomerTournamentPaymentScreen
              : ParticipationDetailScreen,
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('Existing registration is reopened without double booking', (
    t,
  ) async {
    final s = session();
    final e = demoEvents.first;
    s.joinEvent(
      eventId: e.id,
      start: e.start(s.now),
      quantity: 1,
      contact: 'Văn Hùng',
      contactPhone: DemoSession.phone,
    );
    await open(t, detail(s, 0));
    await press(t, 'customer-event-register');
    expect(find.byType(ParticipationDetailScreen), findsOneWidget);
    expect(s.participations.length, 1);
  });
  testWidgets('Guest must authenticate before event registration', (t) async {
    final s = session(guest: true);
    await open(t, detail(s, 0));
    await press(t, 'customer-event-register');
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(s.participations, isEmpty);
  });
  testWidgets('Calendar changes day and next month without fabricated agenda', (
    t,
  ) async {
    final s = session();
    await open(t, detail(s, 0));
    await t.ensureVisible(find.byType(CalendarDatePicker));
    await t.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final picker = t.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    picker.onDateChanged(DateTime(2026, 10, 13));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Không có lịch được công bố ngày'),
      findsOneWidget,
    );
    picker.onDateChanged(DateTime(2026, 10, 12));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Không có lịch được công bố ngày'),
      findsNothing,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('Cancelled event disables joining and shows actual reason', (
    t,
  ) async {
    final s = session();
    final e = demoEvents.first;
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.cancelEventOccurrence(e.id, e.start(s.now), 'Sân cần bảo trì đột xuất.');
    s.login(DemoSession.phone, DemoSession.password);
    await open(t, detail(s, 0));
    expect(find.textContaining('Sân cần bảo trì'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
            find.byKey(const Key('customer-event-register')),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'Stale fee cannot be confirmed into a differently priced ticket',
    (t) async {
      final s = session();
      final current = demoEvents.first;
      final stale = DemoEvent(
        id: current.id,
        title: current.title,
        kind: current.kind,
        hour: current.hour,
        durationMinutes: current.durationMinutes,
        capacity: current.capacity,
        fee: current.fee + 10000,
        description: current.description,
      );
      await open(
        t,
        EventRegistrationScreen(
          session: s,
          event: stale,
          start: current.start(s.now),
        ),
      );
      await press(t, 'event-submit');
      await press(t, 'event-confirm');
      expect(find.byKey(const Key('event-error')), findsOneWidget);
      expect(s.participations, isEmpty);
    },
  );
  testWidgets('Account change during registration confirmation is rejected', (
    t,
  ) async {
    final s = session();
    await open(t, detail(s, 0));
    await press(t, 'customer-event-register');
    await press(t, 'event-submit');
    s.logout();
    await press(t, 'event-confirm');
    expect(find.byKey(const Key('event-error')), findsOneWidget);
    expect(find.byType(ParticipationDetailScreen), findsNothing);
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.participations, isEmpty);
  });
}
