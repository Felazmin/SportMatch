import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/tournament_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 8, 10));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  (DemoSession, DemoEvent, DemoParticipation, DemoParticipation) fixture({
    DemoSession? session,
  }) {
    final s = session ?? DemoSession(now: () => now);
    addTearDown(s.dispose);
    final e = demoEvents.firstWhere((e) => e.kind == DemoEventKind.tournament);
    s.login(DemoSession.phone, DemoSession.password);
    final a = s.joinEvent(
      eventId: e.id,
      start: e.start(now),
      quantity: 1,
      contact: 'Minh Phat',
      contactPhone: DemoSession.phone,
      team: 'Câu lạc bộ cầu lông Thành Phố',
      partner: 'Minh Anh',
    );
    s.register('Player B', 'b@example.com', 'Player1234');
    final b = s.joinEvent(
      eventId: e.id,
      start: e.start(now),
      quantity: 1,
      contact: 'Player B',
      contactPhone: DemoSession.phone,
      team: 'Câu lạc bộ thể thao cuối tuần',
      partner: 'Player C',
    );
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start,
      court: 1,
    );
    return (s, e, a, b);
  }

  void finish(DemoSession s, DemoParticipation a, DemoParticipation b) {
    now = a.start.add(const Duration(minutes: 30));
    s.login(DemoSession.phone, DemoSession.password);
    s.demoCheckIn(a);
    s.login('b@example.com', 'Player1234');
    s.demoCheckIn(b);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    s.finishTournamentMatch('TD0001', 0, 21, 10);
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
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
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Reschedule changes same match, no duplicate registration or fixture',
    (t) async {
      final (s, e, a, _) = fixture();
      await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
      await press(t, 'match-reschedule-TD0001');
      await press(t, 'match-time');
      await t.tap(find.text('14:30').last);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('match-reschedule-reason')),
        'Điều chỉnh giờ theo hai đội',
      );
      await press(t, 'match-save');
      expect(
        s.tournamentMatches(e.id, a.start).single.start,
        a.start.add(const Duration(minutes: 30)),
      );
      expect(find.textContaining('14:30–15:00'), findsOneWidget);
      expect(s.managedParticipations.length, 2);
      expect(t.takeException(), isNull);
    },
  );
  for (final changedRole in [false, true]) {
    testWidgets(
      'Admin correction confirmation guarded: role change $changedRole',
      (t) async {
        final (s, e, a, b) = fixture();
        finish(s, a, b);
        await pump(
          t,
          TournamentScreen(session: s, event: e, start: a.start),
          1,
        );
        await press(t, 'match-correct-TD0001');
        await t.enterText(
          find.byKey(const Key('finance-reason')),
          'Nhập nhầm thứ tự hai đội',
        );
        await t.tap(find.byKey(const Key('finance-text-confirm')));
        await t.pumpAndSettle();
        await t.enterText(find.byKey(const Key('match-score-first')), '10');
        await t.enterText(find.byKey(const Key('match-score-second')), '21');
        await t.tap(find.byKey(const Key('match-score-submit')));
        await t.pumpAndSettle();
        if (changedRole) {
          s.loginStaff(
            DemoRole.owner,
            DemoSession.ownerEmail,
            DemoSession.password,
          );
        }
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('finance-confirm')));
        await t.pumpAndSettle();
        expect(
          s.tournamentMatches(e.id, a.start).single.firstScore,
          changedRole ? 21 : 10,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Failed result correction write retries without replaying correction',
    (t) async {
      final store = TestSessionStore();
      final session = DemoSession(store: store, now: () => now);
      await session.initialize();
      final (s, e, a, b) = fixture(session: session);
      finish(s, a, b);
      expect(await s.flush(), isTrue);
      await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
      await press(t, 'match-correct-TD0001');
      await t.enterText(
        find.byKey(const Key('finance-reason')),
        'Nhập nhầm điểm hai đội',
      );
      await t.tap(find.byKey(const Key('finance-text-confirm')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('match-score-first')), '10');
      await t.enterText(find.byKey(const Key('match-score-second')), '21');
      await t.tap(find.byKey(const Key('match-score-submit')));
      await t.pumpAndSettle();
      store.failWrite = true;
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(
        find.text('Chưa lưu được vào thiết bị. Hãy thử lưu lại.'),
        findsOneWidget,
      );
      expect(s.tournamentMatches(e.id, a.start).single.revision, 2);
      store.failWrite = false;
      await press(t, 'finance-retry-save');
      final reload = DemoSession(store: store, now: () => now);
      addTearDown(reload.dispose);
      await reload.initialize();
      final match = reload.tournamentMatches(e.id, a.start).single;
      expect(match.firstScore, 10);
      expect(match.secondScore, 21);
      expect(match.revision, 2);
      expect(reload.managedParticipations.length, 2);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Reschedule layout fits at scale $scale', (t) async {
      final (s, e, a, _) = fixture();
      final key = await pump(
        t,
        TournamentScreen(session: s, event: e, start: a.start),
        scale,
      );
      await press(t, 'match-reschedule-TD0001');
      await captureHome(key, 'tournament-reschedule-$scale', t);
      await press(t, 'match-save');
      expect(t.takeException(), isNull);
      await captureHome(key, 'tournament-reschedule-bottom-$scale', t);
    });
  }
  testWidgets('Cancel confirmation cannot transfer from Owner to Admin', (
    t,
  ) async {
    final (s, e, a, _) = fixture();
    await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
    await press(t, 'match-cancel-TD0001');
    await t.enterText(
      find.byKey(const Key('finance-reason')),
      'Hai đội yêu cầu đổi lịch',
    );
    await t.tap(find.byKey(const Key('finance-text-confirm')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.tournamentMatches(e.id, a.start).single.state, 'scheduled');
    expect(find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Result confirmation cannot transfer from Owner to Admin', (
    t,
  ) async {
    final (s, e, a, b) = fixture();
    finish(s, a, b);
    // Schedule a second fixture while its time is still in the future.
    now = a.start.subtract(const Duration(hours: 1));
    s.scheduleTournamentMatch(
      first: a.id,
      second: b.id,
      start: a.start.add(const Duration(minutes: 30)),
      court: 1,
    );
    now = a.start.add(const Duration(hours: 1));
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
    await press(t, 'match-result-TD0002');
    await t.enterText(find.byKey(const Key('match-score-first')), '21');
    await t.enterText(find.byKey(const Key('match-score-second')), '11');
    await t.tap(find.byKey(const Key('match-score-submit')));
    await t.pumpAndSettle();
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(s.tournamentMatches(e.id, a.start).last.state, 'scheduled');
    expect(find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
  });
  testWidgets('Reschedule form retains its opening account', (t) async {
    final (s, e, a, _) = fixture();
    await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
    await press(t, 'match-reschedule-TD0001');
    await t.enterText(
      find.byKey(const Key('match-reschedule-reason')),
      'Hai đội yêu cầu đổi lịch',
    );
    s.loginStaff(DemoRole.admin, DemoSession.adminEmail, DemoSession.password);
    await t.pumpAndSettle();
    await press(t, 'match-save');
    expect(s.tournamentMatches(e.id, a.start).single.revision, 0);
    expect(find.text('Tài khoản đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
  });
  testWidgets(
    'Failed cancel write reports error and retry preserves one revision',
    (t) async {
      final store = TestSessionStore();
      final session = DemoSession(store: store, now: () => now);
      await session.initialize();
      final (s, e, a, _) = fixture(session: session);
      expect(await s.flush(), isTrue);
      await pump(t, TournamentScreen(session: s, event: e, start: a.start), 1);
      await press(t, 'match-cancel-TD0001');
      await t.enterText(
        find.byKey(const Key('finance-reason')),
        'Hai đội yêu cầu đổi lịch',
      );
      await t.tap(find.byKey(const Key('finance-text-confirm')));
      await t.pumpAndSettle();
      store.failWrite = true;
      await t.tap(find.byKey(const Key('finance-confirm')));
      await t.pumpAndSettle();
      expect(
        find.text('Chưa lưu được vào thiết bị. Hãy thử lưu lại.'),
        findsOneWidget,
      );
      expect(s.tournamentMatches(e.id, a.start).single.revision, 1);
      store.failWrite = false;
      await press(t, 'finance-retry-save');
      final reload = DemoSession(store: store, now: () => now);
      addTearDown(reload.dispose);
      await reload.initialize();
      expect(reload.tournamentMatches(e.id, a.start).single.state, 'cancelled');
      expect(reload.tournamentMatches(e.id, a.start).single.revision, 1);
      expect(reload.managedParticipations.length, 2);
    },
  );
}
