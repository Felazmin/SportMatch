import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/play_groups_screen.dart';

import 'group_roster_test.dart' show publishedRosterGroup;
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
  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s,
    String id,
    double scale,
  ) async {
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
          home: PlayGroupDetailScreen(session: s, id: id),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final target = find.byKey(Key(key));
    await t.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Direct-join roster and accent-insensitive search fit $scale', (
      t,
    ) async {
      final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
      addTearDown(s.dispose);
      final id = publishedRosterGroup(s);
      s.login(DemoSession.phone, DemoSession.password);
      s.updateName('Nguyễn Minh Phát');
      s.toggleGroup(id);
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      final key = await pump(t, s, id, scale);
      await press(t, 'group-member-search');
      await t.enterText(
        find.byKey(const Key('group-member-search')),
        'nguyen minh',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.text('Thành viên (1)'), findsOneWidget);
      expect(find.text('Nguyễn Minh Phát'), findsOneWidget);
      await captureHome(key, 'group-roster-$scale', t);
      await t.enterText(
        find.byKey(const Key('group-member-search')),
        'khong tim thay',
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('group-member-empty')), findsOneWidget);
      await press(t, 'group-member-search-clear');
      expect(find.text('Nguyễn Minh Phát'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Approval status filters update after review and deny players', (
    t,
  ) async {
    final s = DemoSession(now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    final id = publishedRosterGroup(s, approval: true);
    s.login(DemoSession.phone, DemoSession.password);
    s.toggleGroup(id);
    s.loginStaff(DemoRole.owner, DemoSession.ownerEmail, DemoSession.password);
    await pump(t, s, id, 1);
    await press(t, 'group-members-filter-approved');
    expect(find.byKey(const Key('group-member-empty')), findsOneWidget);
    await press(t, 'group-members-filter-pending');
    await press(t, 'group-member-approve-${DemoSession.phone}');
    await t.tap(find.byKey(const Key('finance-confirm')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('group-member-empty')), findsOneWidget);
    await press(t, 'group-members-filter-approved');
    expect(
      find.byKey(Key('group-request-${DemoSession.phone}')),
      findsOneWidget,
    );
    expect(find.text('Thành viên (1)'), findsOneWidget);
    s.login(DemoSession.phone, DemoSession.password);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('group-member-search')), findsNothing);
    expect(find.text('Cần tài khoản Chủ sân hoặc Admin.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
