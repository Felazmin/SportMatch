import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/admin_players_screen.dart';
import 'package:test_do_an/screens/management_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

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
  void admin(DemoSession s) => s.loginStaff(
    DemoRole.admin,
    DemoSession.adminEmail,
    DemoSession.password,
  );
  void lock(DemoSession s, bool blocked) => s.setPlayerBlocked(
    DemoSession.phone,
    blocked,
    password: DemoSession.password,
    reason: 'Demo access review',
    expectedBlocked: !blocked,
    expectedRevision: s.playerAccessRevision(DemoSession.phone),
  );
  DemoSession make() {
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 8));
    addTearDown(s.dispose);
    s.register('Minh Phát', 'phat@example.com', DemoSession.password);
    s.updateContactPhone('0987654321');
    admin(s);
    return s;
  }

  Finder vertical() => find
      .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
      .last;
  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s, {
    double width = 402,
    double scale = 1,
    Widget? screen,
  }) async {
    t.view.physicalSize = Size(width, 879);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const MyApp());
    final theme = Theme.of(t.element(find.byType(Scaffold).first));
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen ?? AdminPlayersScreen(session: s),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.drag(vertical(), const Offset(0, 5000));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(f, 300, scrollable: vertical());
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester t, {
    String password = DemoSession.password,
  }) async {
    await t.enterText(
      find.byKey(const Key('player-access-reason')),
      'Demo access review',
    );
    await t.enterText(
      find.byKey(const Key('player-access-password')),
      password,
    );
  }

  testWidgets('Search matches accents/contact; status filters and clear work', (
    t,
  ) async {
    final s = make();
    await pump(t, s);
    await t.enterText(
      find.byKey(const Key('admin-player-search')),
      'minh phat',
    );
    await t.pumpAndSettle();
    expect(find.text('Minh Phát'), findsOneWidget);
    expect(find.byKey(const Key('admin-player-0901234567')), findsNothing);
    await t.enterText(
      find.byKey(const Key('admin-player-search')),
      '0987654321',
    );
    await t.pumpAndSettle();
    expect(find.text('Minh Phát'), findsOneWidget);
    await press(t, 'admin-player-filter-true');
    expect(find.byKey(const Key('admin-player-empty')), findsOneWidget);
    await press(t, 'admin-player-clear');
    await press(t, 'admin-player-filter-null');
    await press(t, 'admin-player-0901234567');
    expect(find.byType(AdminPlayerDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Wrong password then correct confirmation locks once and clears secret',
    (t) async {
      final s = make();
      await pump(
        t,
        s,
        screen: AdminPlayerDetailScreen(session: s, id: DemoSession.phone),
      );
      await press(t, 'admin-player-access');
      expect(
        t
            .widget<TextField>(find.byKey(const Key('player-access-password')))
            .obscureText,
        isTrue,
      );
      await fill(t, password: 'wrong');
      await press(t, 'player-access-confirm');
      expect(find.text('Mật khẩu Admin không đúng.'), findsOneWidget);
      expect(s.isBlocked(DemoSession.phone), isFalse);
      expect(
        t
            .widget<TextField>(find.byKey(const Key('player-access-password')))
            .controller!
            .text,
        isEmpty,
      );
      await fill(t);
      await press(t, 'player-access-confirm');
      expect(s.playerAccessRevision(DemoSession.phone), 1);
      expect(find.byKey(const Key('player-access-password')), findsNothing);
      expect(find.text('Đã khóa đăng nhập'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Old open dialog cannot overwrite a newer lock/unlock cycle', (
    t,
  ) async {
    final s = make();
    await pump(
      t,
      s,
      screen: AdminPlayerDetailScreen(session: s, id: DemoSession.phone),
    );
    await press(t, 'admin-player-access');
    lock(s, true);
    lock(s, false);
    await t.pumpAndSettle();
    await fill(t);
    await press(t, 'player-access-confirm');
    expect(find.text('Trạng thái đã thay đổi. Mở lại hồ sơ.'), findsOneWidget);
    expect(s.playerAccessRevision(DemoSession.phone), 2);
    expect(s.isBlocked(DemoSession.phone), isFalse);
  });
  testWidgets('Save failure retries without a second decision', (t) async {
    final store = TestSessionStore();
    final s = DemoSession(now: () => DateTime(2026, 10, 7, 8), store: store);
    addTearDown(s.dispose);
    await s.initialize();
    admin(s);
    await pump(
      t,
      s,
      screen: AdminPlayerDetailScreen(session: s, id: DemoSession.phone),
    );
    await press(t, 'admin-player-access');
    await fill(t);
    store.failWrite = true;
    await press(t, 'player-access-confirm');
    expect(s.playerAccessRevision(DemoSession.phone), 1);
    expect(find.text('Đã thay đổi trong demo, chưa lưu được.'), findsOneWidget);
    store.failWrite = false;
    await press(t, 'player-access-confirm');
    expect(s.playerAccessRevision(DemoSession.phone), 1);
    expect(find.byKey(const Key('player-access-confirm')), findsNothing);
  });
  testWidgets(
    'Owner/player cannot see directory/detail; missing player is handled',
    (t) async {
      final s = make();
      s.loginStaff(
        DemoRole.owner,
        DemoSession.ownerEmail,
        DemoSession.password,
      );
      await pump(t, s);
      expect(find.text('Chỉ Admin được truy cập.'), findsOneWidget);
      s.login(DemoSession.phone, DemoSession.password);
      await pump(
        t,
        s,
        screen: AdminPlayerDetailScreen(session: s, id: DemoSession.phone),
      );
      expect(find.text('Chỉ Admin được truy cập.'), findsOneWidget);
      admin(s);
      await pump(
        t,
        s,
        screen: AdminPlayerDetailScreen(session: s, id: 'unknown@example.com'),
      );
      expect(find.text('Không có người dùng.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Management entry and record link navigate actual screens', (
    t,
  ) async {
    final s = make();
    await pump(t, s, screen: ManagementScreen(session: s));
    await press(t, 'management-player-directory');
    await press(t, 'admin-player-0901234567');
    final id = s.playerRecords(DemoSession.phone).first.id;
    await press(t, 'admin-player-record-$id');
    expect(find.text('Hồ sơ $id'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final size in [(402.0, 1.0), (320.0, 2.0)]) {
    for (final view in ['directory', 'detail', 'confirm', 'empty']) {
      testWidgets('Admin player $view fits ${size.$1} text ${size.$2}', (
        t,
      ) async {
        final s = make();
        Widget? screen;
        if (view == 'detail' || view == 'confirm') {
          screen = AdminPlayerDetailScreen(session: s, id: DemoSession.phone);
        }
        final key = await pump(
          t,
          s,
          width: size.$1,
          scale: size.$2,
          screen: screen,
        );
        if (view == 'confirm') {
          await press(t, 'admin-player-access');
          await fill(t, password: 'wrong');
          await press(t, 'player-access-confirm');
        }
        if (view == 'empty') {
          await t.enterText(
            find.byKey(const Key('admin-player-search')),
            'zzzz',
          );
          await t.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
        }
        await captureHome(
          key,
          'admin-player-$view-${size.$2 == 1 ? 'normal' : 'large'}',
          t,
        );
        for (var i = 0; i < 7; i++) {
          await t.drag(vertical(), const Offset(0, -300));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await captureHome(
          key,
          'admin-player-$view-bottom-${size.$2 == 1 ? 'normal' : 'large'}',
          t,
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }
}
