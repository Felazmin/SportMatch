import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  Future<void> show(WidgetTester tester, DemoSession session) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
  }

  testWidgets('Load error has retry and does not expose empty account', (
    tester,
  ) async {
    final store = TestSessionStore()..failRead = true;
    final session = DemoSession(store: store);
    await show(tester, session);
    expect(find.text('Không thể đọc dữ liệu đã lưu.'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
    store.failRead = false;
    await tester.tap(find.byKey(const Key('storage-retry-load')));
    await tester.pumpAndSettle();
    expect(find.text('NVH ACADEMY'), findsOneWidget);
    expect(store.value, isNotNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Saved profile restores into app after rebuild; logout persists',
    (tester) async {
      final store = TestSessionStore();
      final first = DemoSession(store: store);
      await first.initialize();
      first.register('Persistent User', '0912345678', 'Test1234');
      await first.flush();
      first.dispose();
      final restored = DemoSession(store: store);
      await show(tester, restored);
      await tester.tap(find.text('Tài khoản').last);
      await tester.pumpAndSettle();
      expect(find.text('Persistent User'), findsOneWidget);
      restored.logout();
      await restored.flush();
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
      final guest = DemoSession(store: store);
      await show(tester, guest);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(guest.user, isNull);
      await tester.pumpWidget(const SizedBox());
      guest.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Write error banner survives navigation and retry clears it', (
    tester,
  ) async {
    final store = TestSessionStore();
    final session = DemoSession(store: store);
    await show(tester, session);
    store.failWrite = true;
    session.login(DemoSession.phone, DemoSession.password);
    await session.flush();
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa lưu được dữ liệu. Đừng đóng ứng dụng.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tài khoản').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('storage-retry-save')), findsOneWidget);
    store.failWrite = false;
    await tester.tap(find.byKey(const Key('storage-retry-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('storage-retry-save')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    expect(tester.takeException(), isNull);
  });
}
