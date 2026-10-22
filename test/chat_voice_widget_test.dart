import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/chat/voice_devices.dart';
import 'package:test_do_an/main.dart';
import 'package:test_do_an/screens/chat_screen.dart';

import 'chat_voice_test.dart' show voiceFixture;
import 'home_accessibility_test.dart' show captureHome;
import 'persistence_test.dart' show TestSessionStore;

class FakeRecorder implements DemoVoiceRecorder {
  bool permission = true;
  Completer<bool>? request;
  int starts = 0, stops = 0, cancels = 0;
  @override
  Future<bool> hasPermission() async =>
      request == null ? permission : request!.future;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<Uint8List> stop() async {
    stops++;
    return voiceFixture();
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}

class FakePlayer implements DemoVoicePlayer {
  int plays = 0, stops = 0;
  final done = StreamController<void>.broadcast();
  @override
  Stream<void> get completed => done.stream;
  @override
  Future<void> play(Uint8List bytes) async {
    plays++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await done.close();
  }
}

void main() {
  setUpAll(() async {
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
    FakeRecorder recorder,
    List<FakePlayer> players, {
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
            createVoiceRecorder: () => recorder,
            createVoicePlayer: () {
              final p = FakePlayer();
              players.add(p);
              return p;
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return key;
  }

  Future<void> press(WidgetTester t, String key) async {
    await t.ensureVisible(find.byKey(Key(key)));
    await t.pump();
    await t.tap(find.byKey(Key(key)));
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t) async {
    if (find.byKey(const Key('chat-record-voice')).evaluate().isEmpty) {
      await t.tap(find.byTooltip('Thêm nội dung'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tin nhắn thoại'));
      await t.pumpAndSettle();
    } else {
      await press(t, 'chat-record-voice');
    }
  }

  Future<void> record(WidgetTester t) async {
    await open(t);
    await t.tap(find.byKey(const Key('voice-record-toggle')));
    await t.pump();
    await t.pump();
    expect(find.text('Đang ghi âm'), findsOneWidget);
    await t.tap(find.byKey(const Key('voice-record-toggle')));
    await t.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Record listen attach send play and stop fits scale $scale', (
      t,
    ) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final recorder = FakeRecorder(), players = <FakePlayer>[];
      final key = await pump(t, s, recorder, players, scale: scale);
      await record(t);
      expect(recorder.starts, 1);
      expect(recorder.stops, 1);
      await press(t, 'voice-record-listen');
      expect(players.last.plays, 1);
      await captureHome(key, 'chat-voice-dialog-$scale', t);
      await press(t, 'voice-record-attach');
      expect(find.byKey(const Key('chat-voice-preview')), findsOneWidget);
      await press(t, 'chat-send');
      final m = s.conversation('minh-phat').messages.last;
      expect(m.voiceMillis, 1000);
      expect(s.conversation('minh-phat').messages.length, 7);
      await captureHome(key, 'chat-voice-message-$scale', t);
      await press(t, 'chat-voice-play-${m.id}');
      expect(players.first.plays, 1);
      players.first.done.add(null);
      await t.pumpAndSettle();
      expect(
        t
            .widget<IconButton>(find.byKey(Key('chat-voice-play-${m.id}')))
            .tooltip,
        'Phát tin nhắn thoại',
      );
      await press(t, 'chat-voice-play-${m.id}');
      final stops = players.first.stops;
      s.register('Another', 'new@example.com', 'Player1234');
      await t.pumpAndSettle();
      expect(players.first.stops, greaterThan(stops));
      expect(find.byKey(Key('chat-voice-play-${m.id}')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Remove prepared voice preserves draft text and stops playback', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final players = <FakePlayer>[];
    await pump(t, s, FakeRecorder(), players);
    await t.enterText(find.byKey(const Key('chat-draft')), 'Giữ nội dung');
    await record(t);
    await press(t, 'voice-record-attach');
    await press(t, 'chat-voice-play-draft');
    expect(players.first.plays, 1);
    final stops = players.first.stops;
    await press(t, 'chat-voice-remove');
    expect(players.first.stops, greaterThan(stops));
    expect(find.byKey(const Key('chat-voice-preview')), findsNothing);
    expect(
      t.widget<TextField>(find.byKey(const Key('chat-draft'))).controller!.text,
      'Giữ nội dung',
    );
    expect(s.conversation('minh-phat').messages.length, 6);
  });
  testWidgets('Denied microphone never starts recording and permits retry', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final recorder = FakeRecorder()..permission = false;
    await pump(t, s, recorder, []);
    await open(t);
    await press(t, 'voice-record-toggle');
    expect(recorder.starts, 0);
    expect(find.textContaining('Chưa có quyền micro'), findsOneWidget);
    recorder.permission = true;
    await t.tap(find.byKey(const Key('voice-record-toggle')));
    await t.pump();
    await t.pump();
    expect(recorder.starts, 1);
    await press(t, 'voice-record-cancel');
    expect(recorder.cancels, greaterThan(0));
    expect(s.conversation('minh-phat').messages.length, 6);
  });
  testWidgets(
    'Changed account while permission is pending cannot start recording',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final recorder = FakeRecorder()..request = Completer<bool>();
      await pump(t, s, recorder, []);
      await open(t);
      await t.tap(find.byKey(const Key('voice-record-toggle')));
      await t.pump();
      s.register('Another', 'new@example.com', 'Player1234');
      recorder.request!.complete(true);
      await t.pumpAndSettle();
      expect(recorder.starts, 0);
      expect(find.byKey(const Key('chat-voice-preview')), findsNothing);
      expect(s.conversation('minh-phat').messages.length, 6);
    },
  );
  testWidgets('Twenty second time limit stops recording without sending', (
    t,
  ) async {
    final s = session()..login(DemoSession.phone, DemoSession.password);
    final recorder = FakeRecorder();
    await pump(t, s, recorder, []);
    await open(t);
    await t.tap(find.byKey(const Key('voice-record-toggle')));
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 20));
    await t.pumpAndSettle();
    expect(recorder.stops, 1);
    expect(find.text('Đang ghi âm'), findsNothing);
    expect(s.conversation('minh-phat').messages.length, 6);
    await press(t, 'voice-record-cancel');
  });
  testWidgets(
    'Background cancels microphone and discards uncommitted recording',
    (t) async {
      final s = session()..login(DemoSession.phone, DemoSession.password);
      final recorder = FakeRecorder();
      await pump(t, s, recorder, []);
      await open(t);
      await t.tap(find.byKey(const Key('voice-record-toggle')));
      await t.pump();
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pumpAndSettle();
      expect(recorder.cancels, greaterThan(0));
      expect(find.text('Đã hủy bản ghi khi rời ứng dụng.'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('voice-record-attach')))
            .onPressed,
        isNull,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
    },
  );
  testWidgets('Failed voice save retries once and survives reload', (t) async {
    final store = TestSessionStore();
    final saved = session(store: store);
    await saved.initialize();
    saved.login(DemoSession.phone, DemoSession.password);
    await saved.flush();
    await pump(t, saved, FakeRecorder(), []);
    await record(t);
    await press(t, 'voice-record-attach');
    await t.enterText(find.byKey(const Key('chat-draft')), 'Hẹn gặp');
    store.failWrite = true;
    await press(t, 'chat-send');
    expect(find.text('Chưa lưu được tin nhắn.'), findsOneWidget);
    expect(saved.conversation('minh-phat').messages.length, 7);
    store.failWrite = false;
    await t.tap(find.text('Thử lưu'));
    await t.pumpAndSettle();
    final reload = session(store: store);
    await reload.initialize();
    expect(
      reload
          .conversation('minh-phat')
          .messages
          .where((m) => m.voice.isNotEmpty)
          .length,
      1,
    );
  });
}
