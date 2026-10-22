import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/tournament_screen.dart';
import 'package:test_do_an/screens/activities_screen.dart';
import 'package:test_do_an/screens/events_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late DateTime now;
  final start = DateTime(2026, 10, 9, 18);
  setUp(() => now = DateTime(2026, 10, 7, 10));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  (DemoSession, DemoEvent, DemoParticipation, DemoParticipation) fixture() {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    final a = s.saveActivity(
      title: 'Giải cầu lông đôi giao lưu cuối tuần',
      kind: DemoEventKind.tournament,
      start: start,
      durationMinutes: 120,
      capacity: 8,
      fee: 65000,
      description: 'Thi đấu giao lưu theo thể lệ của ban tổ chức.',
    );
    s.transitionActivity(a.id, 'pending', 0);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    s.transitionActivity(a.id, 'approved', 1);
    s.login(DemoSession.phone, DemoSession.password);
    final p = s.joinEvent(
      eventId: a.id,
      start: start,
      quantity: 1,
      contact: 'Minh Phat',
      contactPhone: DemoSession.phone,
      team: 'Câu lạc bộ cầu lông Thành Phố',
      partner: 'Minh Anh',
    );
    s.register('Player Two', 'two@example.com', 'Player1234');
    final q = s.joinEvent(
      eventId: a.id,
      start: start,
      quantity: 1,
      contact: 'Player Two',
      contactPhone: DemoSession.phone,
      team: 'Câu lạc bộ giao lưu cuối tuần',
      partner: 'Player Three',
    );
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    return (s, a.event, p, q);
  }

  Future<GlobalKey> pump(WidgetTester t, Widget screen, double scale) async {
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
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, String key, String label) async {
    await press(t, key);
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Organizer entry, create fixture, record score, player ticket entry',
    (t) async {
      final (s, e, p, q) = fixture();
      await pump(t, ActivityDetailScreen(session: s, id: e.id), 1);
      await press(t, 'activity-matches');
      await press(t, 'match-add');
      await choose(t, 'match-first', p.id);
      await choose(t, 'match-second', q.id);
      await choose(t, 'match-time', '18:00');
      await press(t, 'match-save');
      expect(s.tournamentMatches(e.id, start).length, 1);
      now = start.add(const Duration(minutes: 30));
      s.login(DemoSession.phone, DemoSession.password);
      s.demoCheckIn(p);
      s.login('two@example.com', 'Player1234');
      s.demoCheckIn(q);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      expect(s.tournamentMatches(e.id, start).single.start, start);
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const Key('match-result-TD0001')),
            )
            .onPressed,
        isNotNull,
      );
      await press(t, 'match-result-TD0001');
      await t.enterText(find.byKey(const Key('match-score-first')), '21');
      await t.enterText(find.byKey(const Key('match-score-second')), '15');
      await t.tap(find.byKey(const Key('match-score-submit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('match-score-TD0001')), findsOneWidget);
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, ParticipationDetailScreen(session: s, participation: p), 1);
      await press(t, 'participation-matches');
      expect(find.text('21 – 15'), findsOneWidget);
      expect(find.byKey(const Key('match-add')), findsNothing);
    },
  );
  testWidgets('Role changed during result confirmation cannot commit', (
    t,
  ) async {
    final (s, e, p, q) = fixture();
    s.scheduleTournamentMatch(
      first: p.id,
      second: q.id,
      start: start,
      court: 1,
    );
    now = start.add(const Duration(minutes: 30));
    s.login(DemoSession.phone, DemoSession.password);
    s.demoCheckIn(p);
    s.login('two@example.com', 'Player1234');
    s.demoCheckIn(q);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await pump(t, TournamentScreen(session: s, event: e, start: start), 1);
    await press(t, 'match-result-TD0001');
    await t.enterText(find.byKey(const Key('match-score-first')), '21');
    await t.enterText(find.byKey(const Key('match-score-second')), '15');
    await t.tap(find.byKey(const Key('match-score-submit')));
    await t.pumpAndSettle();
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.tournamentMatches(e.id, start).single.state, 'scheduled');
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('Schedule/form/results/dialog fit at scale $scale', (t) async {
      final (s, e, p, q) = fixture();
      s.scheduleTournamentMatch(
        first: p.id,
        second: q.id,
        start: start,
        court: 1,
      );
      final key = await pump(
        t,
        TournamentScreen(session: s, event: e, start: start),
        scale,
      );
      await captureHome(key, 'tournament-list-$scale', t);
      expect(t.takeException(), isNull);
      await press(t, 'match-add');
      await choose(t, 'match-first', p.id);
      await choose(t, 'match-second', q.id);
      await captureHome(key, 'tournament-form-$scale', t);
      await press(t, 'match-save');
      expect(t.takeException(), isNull);
      await captureHome(key, 'tournament-form-bottom-$scale', t);
      await t.pageBack();
      await t.pumpAndSettle();
      now = start.add(const Duration(minutes: 30));
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await t.pumpAndSettle();
      await press(t, 'match-result-TD0001');
      await captureHome(key, 'tournament-score-dialog-$scale', t);
      expect(t.takeException(), isNull);
    });
  }
}
