import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/chat_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  DemoSession session({TestSessionStore? store}) {
    final s = DemoSession(
      now: () => DateTime(2026, 10, 6, 15, 37),
      store: store,
    );
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester tester,
    Widget screen, {
    double width = 402,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 879);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return key;
  }

  void login(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);

  testWidgets(
    'Search, clear, sport and unread filters, then opening marks read',
    (tester) async {
      final s = session();
      login(s);
      await pump(tester, ChatListScreen(session: s));
      await tester.enterText(find.byKey(const Key('chat-search')), 'hoang nam');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-hoang-nam')), findsOneWidget);
      expect(find.byKey(const Key('chat-minh-phat')), findsNothing);
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-sport-Bóng đá')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-van-duc')), findsOneWidget);
      expect(find.byKey(const Key('chat-hoang-nam')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-sport-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thông báo tin nhắn'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<String>));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-minh-phat')), findsNothing);
      await tester.tap(find.byKey(const Key('chat-hoang-nam')));
      await tester.pumpAndSettle();
      expect(s.unreadMessages, 1);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-hoang-nam')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Send text and emoji, keep local-only labels and no synthetic replies',
    (tester) async {
      final s = session();
      login(s);
      await pump(tester, ChatDetailScreen(session: s, contactId: 'minh-phat'));
      expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('chat-draft')), 'Xin chào');
      await tester.tap(find.byTooltip('Biểu tượng cảm xúc'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('👍'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(s.conversation('minh-phat').messages.last.text, 'Xin chào👍');
      expect(s.conversation('minh-phat').messages.length, 7);
      expect(find.text('15:37 · Cục bộ'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chat-draft')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byTooltip('Gọi điện'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa kết nối dịch vụ thật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Save failure retains draft, retry saves exactly once', (
    tester,
  ) async {
    final store = TestSessionStore();
    final s = session(store: store);
    await s.initialize();
    login(s);
    await s.flush();
    await pump(tester, ChatDetailScreen(session: s, contactId: 'minh-phat'));
    store.failWrite = true;
    await tester.enterText(find.byKey(const Key('chat-draft')), 'Retry once');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được tin nhắn.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-draft')))
          .controller!
          .text,
      'Retry once',
    );
    store.failWrite = false;
    await tester.tap(find.text('Thử lưu'));
    await tester.pumpAndSettle();
    expect(
      s
          .conversation('minh-phat')
          .messages
          .where((m) => m.text == 'Retry once')
          .length,
      1,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-draft')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Long history opens at the latest message and scrolls after sending',
    (tester) async {
      final s = session();
      login(s);
      for (var i = 0; i < 50; i++) {
        s.sendChatMessage('minh-phat', 'Tin nhắn $i ${'nội dung dài ' * 20}');
      }
      final last = s.sendChatMessage('minh-phat', 'Tin cuối');
      await pump(tester, ChatDetailScreen(session: s, contactId: 'minh-phat'));
      expect(
        find.byKey(Key('message-${last.id}')).hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('chat-draft')), 'Tin mới');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      final latest = s.conversation('minh-phat').messages.last;
      expect(
        find.byKey(Key('message-${latest.id}')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Account entry and bottom tabs navigate actual home views', (
    tester,
  ) async {
    final s = session();
    login(s);
    await tester.pumpWidget(MyApp(session: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tin nhắn'),
      150,
      scrollable: find.descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('Tin nhắn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tin nhắn'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatListScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-nav-2')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatListScreen), findsNothing);
    expect(find.byKey(const ValueKey('explore')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Switching account never exposes the previous conversation or draft send',
    (tester) async {
      final s = session();
      login(s);
      await pump(tester, ChatDetailScreen(session: s, contactId: 'minh-phat'));
      await tester.enterText(
        find.byKey(const Key('chat-draft')),
        'Private draft',
      );
      s.register('Other', 'other@example.com', 'Test1234');
      await tester.pumpAndSettle();
      expect(find.text('Cuộc trò chuyện không khả dụng.'), findsOneWidget);
      expect(find.byKey(const Key('chat-draft')), findsNothing);
      expect(s.conversation('minh-phat').messages.length, 6);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 402.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Chat list/detail fit $width width and $scale text scale', (
        tester,
      ) async {
        final s = session();
        login(s);
        final listCapture = await pump(
          tester,
          ChatListScreen(session: s),
          width: width,
          scale: scale,
        );
        await captureHome(
          listCapture,
          'chat-list-${width.toInt()}-${scale.toInt()}',
          tester,
        );
        expect(tester.takeException(), isNull);
        final detailCapture = await pump(
          tester,
          ChatDetailScreen(session: s, contactId: 'minh-phat'),
          width: width,
          scale: scale,
        );
        await captureHome(
          detailCapture,
          'chat-detail-${width.toInt()}-${scale.toInt()}',
          tester,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.enterText(
          find.byKey(const Key('chat-draft')),
          'Tin nhắn nhiều dòng\nDòng tiếp theo',
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const Key('chat-send'))).bottom,
          lessThanOrEqualTo(579),
        );
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      });
    }
  }
}
