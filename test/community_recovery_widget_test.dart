import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/community_screen.dart';
import 'package:test_do_an/screens/recovery_screen.dart';

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
  DemoSession session({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 6, 10));
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    Widget w, {
    double scale = 1,
    double width = 402,
  }) async {
    t.view.physicalSize = Size(width, 879);
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
          home: w,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    return key;
  }

  Future<void> press(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
    'Recovery shows invalid code and mismatch then persists new password',
    (t) async {
      final s = session();
      final key = await pump(
        t,
        RecoveryScreen(session: s, identifier: DemoSession.phone),
      );
      await press(t, find.byKey(const Key('recovery-request')));
      await captureHome(key, 'recovery-code', t);
      await t.enterText(find.byKey(const Key('recovery-code')), '000000');
      await press(t, find.byKey(const Key('recovery-verify')));
      expect(find.textContaining('Mã không đúng'), findsOneWidget);
      await t.enterText(find.byKey(const Key('recovery-code')), '123456');
      await press(t, find.byKey(const Key('recovery-verify')));
      await t.enterText(find.byKey(const Key('recovery-password')), 'New12345');
      await t.enterText(find.byKey(const Key('recovery-confirm')), 'Wrong123');
      await press(t, find.byKey(const Key('recovery-reset')));
      expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('recovery-confirm')), 'New12345');
      await press(t, find.byKey(const Key('recovery-reset')));
      expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
      expect(s.login(DemoSession.phone, 'New12345'), isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
  testWidgets('Failed recovery save retries without resetting twice', (
    t,
  ) async {
    final store = TestSessionStore();
    final s = session(store: store);
    await s.initialize();
    await pump(t, RecoveryScreen(session: s, identifier: DemoSession.phone));
    await press(t, find.byKey(const Key('recovery-request')));
    await t.enterText(find.byKey(const Key('recovery-code')), '123456');
    await press(t, find.byKey(const Key('recovery-verify')));
    await t.enterText(find.byKey(const Key('recovery-password')), 'New12345');
    await t.enterText(find.byKey(const Key('recovery-confirm')), 'New12345');
    store.failWrite = true;
    await press(t, find.byKey(const Key('recovery-reset')));
    expect(find.byKey(const Key('recovery-retry-save')), findsOneWidget);
    store.failWrite = false;
    await press(t, find.byKey(const Key('recovery-retry-save')));
    expect(s.saveFailed, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  testWidgets('Join a group, post to it then delete own post', (t) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final key = await pump(t, CommunityScreen(session: s));
    await press(t, find.byKey(const Key('community-mode-1')));
    await press(t, find.byKey(const Key('group-join-badminton')));
    expect(s.joinedGroups, {'badminton'});
    await press(t, find.byKey(const Key('group-posts-badminton')));
    await press(t, find.byKey(const Key('community-compose')));
    await t.enterText(
      find.byKey(const Key('post-message')),
      'Tìm bạn chơi cầu lông',
    );
    await press(t, find.byKey(const Key('post-submit')));
    expect(s.posts.length, 1);
    await captureHome(key, 'community-posts', t);
    await press(t, find.byKey(Key('post-delete-${s.posts.single.id}')));
    await press(t, find.byKey(const Key('community-delete-confirm')));
    expect(s.posts, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets('Expense input creates exact shares and opens personal history', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final key = await pump(t, CommunityScreen(session: s));
    await press(t, find.byKey(const Key('community-mode-2')));
    await press(t, find.byKey(const Key('expense-create')));
    await t.enterText(find.byKey(const Key('expense-title')), 'Tiền sân');
    await t.enterText(find.byKey(const Key('expense-amount')), '100001');
    await t.enterText(
      find.byKey(const Key('expense-names')),
      'An\nBình\nCường',
    );
    await press(t, find.byKey(const Key('expense-submit')));
    expect(s.expenses.single.shares, [33334, 33334, 33333]);
    expect(find.text('33.334đ'), findsNWidgets(2));
    await captureHome(key, 'expense-detail', t);
    expect(t.takeException(), isNull);
  });
  for (final screen in [
    'community',
    'post',
    'expense',
    'expense-detail',
    'recovery',
  ]) {
    testWidgets('$screen fits 320px with 200 percent text', (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final expense = s.createExpense('Khoản chi thử nghiệm', 100001, [
        'Nguyễn Văn An',
        'Bình',
        'Cường',
      ]);
      final w = switch (screen) {
        'community' => CommunityScreen(session: s),
        'post' => PostFormScreen(session: s, groupId: 'public'),
        'expense' => ExpenseFormScreen(session: s),
        'expense-detail' => ExpenseDetailScreen(session: s, expense: expense),
        _ => RecoveryScreen(session: s, identifier: DemoSession.phone),
      };
      final key = await pump(t, w, width: 320, scale: 2);
      await captureHome(key, '$screen-large', t);
      await t.drag(find.byType(ListView).first, const Offset(0, -300));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
