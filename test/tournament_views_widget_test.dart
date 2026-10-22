import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/demo/demo_events.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/tournament_directory_screen.dart';
import 'package:test_do_an/screens/tournament_results_screen.dart';
import 'package:test_do_an/screens/tournament_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  setUpAll(() async {
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  void owner(DemoSession s) => s.loginStaff(
    DemoRole.owner,
    DemoSession.ownerEmail,
    DemoSession.password,
  );
  (DemoSession, DemoEvent, DateTime) fixture({bool populated = true}) {
    final s = DemoSession(now: () => now);
    addTearDown(s.dispose);
    final e = demoEvents.firstWhere((e) => e.kind == DemoEventKind.tournament);
    final start = e.start(now);
    if (populated) {
      final p = <DemoParticipation>[];
      for (var i = 0; i < 4; i++) {
        if (i == 0) {
          s.login(DemoSession.phone, DemoSession.password);
        } else {
          s.register(
            'Private contact $i',
            'player$i@example.com',
            'Player1234',
          );
        }
        p.add(
          s.joinEvent(
            eventId: e.id,
            start: start,
            quantity: 1,
            contact: 'Private contact $i',
            contactPhone: DemoSession.phone,
            team: [
              'Z Câu lạc bộ cầu lông Thành Phố',
              'A Nhóm giao lưu cuối tuần',
              'B Câu lạc bộ thể thao tuổi trẻ',
              'C Nhóm chơi cầu lông',
            ][i],
            partner: 'Partner $i',
          ),
        );
      }
      owner(s);
      final a = s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[1].id,
        start: start,
        court: 1,
      );
      final b = s.scheduleTournamentMatch(
        first: p[2].id,
        second: p[3].id,
        start: start,
        court: 2,
      );
      s.scheduleTournamentMatch(
        first: p[0].id,
        second: p[2].id,
        start: start.add(const Duration(minutes: 30)),
        court: 1,
      );
      final d = s.scheduleTournamentMatch(
        first: p[1].id,
        second: p[3].id,
        start: start.add(const Duration(hours: 1)),
        court: 2,
      );
      s.cancelTournamentMatch(d.id, 0, 'Adjust schedule');
      now = start.add(const Duration(minutes: 30));
      for (var i = 0; i < 4; i++) {
        s.login(
          i == 0 ? DemoSession.phone : 'player$i@example.com',
          i == 0 ? DemoSession.password : 'Player1234',
        );
        s.demoCheckIn(p[i]);
      }
      owner(s);
      s.finishTournamentMatch(a.id, 0, 21, 15);
      s.finishTournamentMatch(b.id, 0, 21, 10);
    }
    owner(s);
    return (s, e, start);
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
    'Management hub opens seeded tournament and actual team results',
    (t) async {
      final (s, e, start) = fixture();
      await pump(t, ManagementScreen(session: s), 1);
      await press(t, 'management-tournaments');
      await t.enterText(find.byKey(const Key('tournaments-search')), 'doi');
      await t.pumpAndSettle();
      await press(t, 'tournament-${e.id}-${start.toIso8601String()}');
      await press(t, 'tournament-results');
      expect(find.text('Kết quả các đội'), findsOneWidget);
      expect(find.text('Điểm ghi: 15'), findsOneWidget);
      final initial = t
          .getTopLeft(find.byKey(const Key('result-team-VE0002')))
          .dy;
      expect(
        initial,
        lessThan(t.getTopLeft(find.byKey(const Key('result-team-VE0001'))).dy),
      );
      await press(t, 'results-sort');
      await t.tap(find.text('Số trận thắng').last);
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.byKey(const Key('result-team-VE0001'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('result-team-VE0002'))).dy),
      );
      expect(find.textContaining('Private contact'), findsNothing);
    },
  );
  testWidgets(
    'Player own-team and status filters show only matching fixtures',
    (t) async {
      final (s, e, start) = fixture();
      s.login(DemoSession.phone, DemoSession.password);
      await pump(t, TournamentScreen(session: s, event: e, start: start), 1);
      await press(t, 'matches-own-team');
      expect(find.textContaining('TD0002'), findsNothing);
      expect(find.textContaining('TD0004'), findsNothing);
      expect(find.textContaining('TD0001'), findsOneWidget);
      expect(find.textContaining('TD0003'), findsOneWidget);
      await press(t, 'matches-state-completed');
      expect(find.textContaining('TD0003'), findsNothing);
      await press(t, 'matches-state-cancelled');
      expect(find.text('Không có trận phù hợp.'), findsOneWidget);
      await press(t, 'matches-all-teams');
      expect(find.textContaining('TD0004'), findsOneWidget);
      expect(find.byKey(const Key('match-add')), findsNothing);
    },
  );
  testWidgets('Directory search/time filters and role change stay guarded', (
    t,
  ) async {
    final (s, _, _) = fixture(populated: false);
    await pump(t, TournamentDirectoryScreen(session: s), 1);
    await press(t, 'tournaments-period-ended');
    expect(find.text('Không có giải đấu phù hợp.'), findsOneWidget);
    await press(t, 'tournaments-period-all');
    await t.enterText(
      find.byKey(const Key('tournaments-search')),
      'Không có tên này',
    );
    await t.pumpAndSettle();
    expect(find.text('Không có giải đấu phù hợp.'), findsOneWidget);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.text('Cần tài khoản Chủ sân hoặc Admin.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Results never expose another tournament to an outsider', (
    t,
  ) async {
    final (s, e, start) = fixture();
    await pump(
      t,
      TournamentResultsScreen(session: s, event: e, start: start),
      1,
    );
    s.register('Outsider', 'out@example.com', 'Player1234');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('result-team-VE0001')), findsNothing);
    expect(
      find.text('Cần tài khoản quản lý hoặc vé của giải này.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Active team filter excludes cancelled tickets without erasing results',
    (t) async {
      final (s, e, start) = fixture(populated: false);
      s.login(DemoSession.phone, DemoSession.password);
      final a = s.joinEvent(
        eventId: e.id,
        start: start,
        quantity: 1,
        contact: 'Minh Phat',
        contactPhone: DemoSession.phone,
        team: 'Đội cầu lông đã hủy',
        partner: 'Minh Anh',
      );
      expect(s.cancelParticipation(a), isTrue);
      owner(s);
      await pump(
        t,
        TournamentResultsScreen(session: s, event: e, start: start),
        1,
      );
      expect(find.byKey(Key('result-team-${a.id}')), findsOneWidget);
      await press(t, 'results-active-only');
      expect(find.byKey(Key('result-team-${a.id}')), findsNothing);
      expect(find.text('Không có đội phù hợp.'), findsOneWidget);
      await press(t, 'results-active-only');
      expect(find.byKey(Key('result-team-${a.id}')), findsOneWidget);
      expect(s.tournamentResults(e.id, start).single.cancelled, isTrue);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Search and court filters combine at scale $scale', (t) async {
      final (s, e, start) = fixture();
      await pump(
        t,
        TournamentScreen(session: s, event: e, start: start),
        scale,
      );
      await press(t, 'matches-search');
      await t.enterText(find.byKey(const Key('matches-search')), 'thanh pho');
      await t.pumpAndSettle();
      expect(find.textContaining('TD0001'), findsOneWidget);
      expect(find.textContaining('TD0002'), findsNothing);
      await press(t, 'matches-court');
      await t.tap(find.text('Sân 2').last);
      await t.pumpAndSettle();
      expect(find.text('Không có trận phù hợp.'), findsOneWidget);
      await press(t, 'matches-search-clear');
      expect(find.textContaining('TD0002'), findsOneWidget);
      await t.scrollUntilVisible(
        find.textContaining('TD0004'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('TD0004'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('Results search ignores accents and clears at scale $scale', (
      t,
    ) async {
      final (s, e, start) = fixture();
      await pump(
        t,
        TournamentResultsScreen(session: s, event: e, start: start),
        scale,
      );
      await t.enterText(find.byKey(const Key('results-search')), 'thanh pho');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('result-team-VE0001')), findsOneWidget);
      expect(find.byKey(const Key('result-team-VE0002')), findsNothing);
      await t.enterText(
        find.byKey(const Key('results-search')),
        'khong co doi',
      );
      await t.pumpAndSettle();
      expect(find.text('Không có đội phù hợp.'), findsOneWidget);
      await press(t, 'results-search-clear');
      expect(find.byKey(const Key('result-team-VE0002')), findsOneWidget);
      await press(t, 'results-active-only');
      expect(t.takeException(), isNull);
    });
    for (final view in [
      'directory',
      'results',
      'own-fixtures',
      'empty-results',
    ]) {
      testWidgets('$view fits scale $scale', (t) async {
        final (s, e, start) = fixture(populated: view != 'empty-results');
        if (view == 'own-fixtures') {
          s.login(DemoSession.phone, DemoSession.password);
        }
        final Widget screen = switch (view) {
          'directory' => TournamentDirectoryScreen(session: s),
          'own-fixtures' => TournamentScreen(
            session: s,
            event: e,
            start: start,
          ),
          _ => TournamentResultsScreen(session: s, event: e, start: start),
        };
        final key = await pump(t, screen, scale);
        if (view == 'own-fixtures') await press(t, 'matches-own-team');
        expect(t.takeException(), isNull);
        await captureHome(key, 'tournament-$view-$scale', t);
        await t.drag(find.byType(ListView).first, const Offset(0, -650));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await captureHome(key, 'tournament-$view-bottom-$scale', t);
      });
    }
  }
}
