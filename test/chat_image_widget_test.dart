import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/chat_screen.dart';

import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  late Uint8List bytes;
  setUpAll(() async {
    bytes = (await rootBundle.load('assets/auth/vietnam.png')).buffer
        .asUint8List();
    for (final e in {
      'Inter': 'assets/fonts/Inter.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(rootBundle.load(e.value))).load();
    }
  });
  DemoSession session({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  Future<GlobalKey> pump(
    WidgetTester t,
    DemoSession s,
    Future<Uint8List?> Function() picker, {
    double scale = 1,
  }) async {
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
          home: ChatDetailScreen(
            session: s,
            contactId: 'minh-phat',
            pickImage: picker,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> choose(WidgetTester t) async {
    if (find.byKey(const Key('chat-pick-image')).evaluate().isEmpty) {
      await t.tap(find.byTooltip('Thêm nội dung'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ảnh'));
    } else {
      await t.tap(find.byKey(const Key('chat-pick-image')));
    }
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pumpAndSettle();
  }

  Future<void> imageReady(WidgetTester t, Finder parent) async {
    final imageFinder = parent.evaluate().single.widget is Image
        ? parent
        : find.descendant(of: parent, matching: find.byType(Image));
    final image = t.widget<Image>(imageFinder);
    await t.runAsync(() => precacheImage(image.image, t.element(imageFinder)));
    await t.pumpAndSettle();
    final raw = t.widget<RawImage>(
      find.descendant(of: imageFinder, matching: find.byType(RawImage)),
    );
    expect(raw.image, isNotNull);
    await t.runAsync(() async {
      final pixels = await raw.image!.toByteData();
      expect(pixels, isNotNull);
      expect(pixels!.buffer.asUint8List().any((v) => v != 0), isTrue);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Pick preview remove send and zoom image at scale $scale', (
      t,
    ) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final key = await pump(t, s, () async => bytes, scale: scale);
      await t.enterText(find.byKey(const Key('chat-draft')), 'Ảnh sân tối nay');
      await choose(t);
      expect(find.byKey(const Key('chat-image-preview')), findsOneWidget);
      await imageReady(t, find.byKey(const Key('chat-image-preview')));
      expect(s.conversation('minh-phat').messages.length, 6);
      await captureHome(key, 'chat-image-preview-$scale', t);
      await t.tap(find.byKey(const Key('chat-image-remove')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      expect(
        t
            .widget<TextField>(find.byKey(const Key('chat-draft')))
            .controller!
            .text,
        'Ảnh sân tối nay',
      );
      await choose(t);
      await t.tap(find.byKey(const Key('chat-send')));
      await t.pumpAndSettle();
      final message = s.conversation('minh-phat').messages.last;
      expect(message.image, base64Encode(bytes));
      expect(message.text, 'Ảnh sân tối nay');
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      expect(t.takeException(), isNull);
      await imageReady(t, find.byKey(Key('chat-image-${message.id}')));
      await captureHome(key, 'chat-image-message-$scale', t);
      await t.tap(find.byKey(Key('chat-image-${message.id}')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('chat-image-viewer')), findsOneWidget);
      await imageReady(t, find.byKey(const Key('chat-image-viewer')));
      expect(t.takeException(), isNull);
      s.register('Another', 'another@example.com', 'Player1234');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('chat-image-viewer')), findsNothing);
      expect(find.text('Cuộc trò chuyện không khả dụng.'), findsOneWidget);
    });
  }
  testWidgets('Cancelled and broken image picker preserve the text draft', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    var cancelled = true;
    await pump(
      t,
      s,
      () async => cancelled
          ? null
          : Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    await t.enterText(
      find.byKey(const Key('chat-draft')),
      'Giữ nguyên nội dung',
    );
    await choose(t);
    expect(find.byKey(const Key('chat-image-preview')), findsNothing);
    cancelled = false;
    await choose(t);
    expect(find.byKey(const Key('chat-image-preview')), findsNothing);
    expect(find.text('Không thể mở ảnh. Hãy chọn lại.'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byKey(const Key('chat-draft'))).controller!.text,
      'Giữ nguyên nội dung',
    );
    expect(s.conversation('minh-phat').messages.length, 6);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Changed account while picker is open cannot attach or send the old image',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final pending = Completer<Uint8List?>();
      await pump(t, s, () => pending.future);
      await t.tap(find.byKey(const Key('chat-pick-image')));
      await t.pump();
      expect(find.byKey(const Key('chat-image-loading')), findsOneWidget);
      s.register('Another', 'new@example.com', 'Player1234');
      pending.complete(bytes);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      expect(
        s.conversations
            .expand((c) => c.messages)
            .where((m) => m.image.isNotEmpty),
        isEmpty,
      );
      s.login(DemoSession.phone, DemoSession.password);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('chat-image-preview')), findsNothing);
      expect(s.conversation('minh-phat').messages.length, 6);
    },
  );
  testWidgets('Failed image save retries once and survives reload', (t) async {
    final store = TestSessionStore();
    final s = session(store: store);
    await s.initialize();
    s.login(DemoSession.phone, DemoSession.password);
    await s.flush();
    await pump(t, s, () async => bytes);
    await choose(t);
    store.failWrite = true;
    await t.tap(find.byKey(const Key('chat-send')));
    await t.pumpAndSettle();
    expect(find.text('Chưa lưu được tin nhắn.'), findsOneWidget);
    expect(s.conversation('minh-phat').messages.length, 7);
    expect(
      t.widget<IconButton>(find.byKey(const Key('chat-pick-image'))).onPressed,
      isNull,
    );
    store.failWrite = false;
    await t.tap(find.text('Thử lưu'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-preview')), findsNothing);
    final reload = session(store: store);
    await reload.initialize();
    expect(
      reload
          .conversation('minh-phat')
          .messages
          .where((m) => m.image.isNotEmpty)
          .length,
      1,
    );
    expect(reload.conversation('minh-phat').messages.length, 7);
  });
}
