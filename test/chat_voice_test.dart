import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/chat/demo_chat.dart';
import 'package:test_do_an/chat/demo_voice.dart';

import 'persistence_test.dart' show TestSessionStore;

Uint8List voiceFixture({int milliseconds = 1000}) {
  final size = milliseconds * 32;
  final bytes = Uint8List(44 + size);
  final data = ByteData.sublistView(bytes);
  for (final e in {0: 'RIFF', 8: 'WAVE', 12: 'fmt ', 36: 'data'}.entries) {
    bytes.setRange(e.key, e.key + 4, ascii.encode(e.value));
  }
  data.setUint32(4, bytes.length - 8, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, size, Endian.little);
  return bytes;
}

void main() {
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(store: store, now: () => DateTime(2026, 10, 9, 10));
    addTearDown(s.dispose);
    return s;
  }

  test('WAV bounds, duration and payload consistency are validated', () {
    for (final duration in [500, 1000, 20000]) {
      expect(
        voiceDurationMillis(voiceFixture(milliseconds: duration)),
        duration,
      );
    }
    for (final duration in [100, 22000]) {
      expect(
        () => voiceDurationMillis(voiceFixture(milliseconds: duration)),
        throwsFormatException,
      );
    }
    final corrupt = voiceFixture();
    ByteData.sublistView(corrupt).setUint32(40, 999999, Endian.little);
    expect(() => voiceDurationMillis(corrupt), throwsFormatException);
    expect(() => decodeVoice('AAAA'), throwsFormatException);
    expect(() => decodeVoice('A' * 950000), throwsFormatException);
    expect(voiceClock(1250), '0:02');
  });
  test('Non-44-byte WAV with an extra padded chunk is supported', () {
    final original = voiceFixture();
    final bytes = Uint8List(original.length + 10);
    bytes.setRange(0, 36, original);
    bytes.setRange(36, 40, ascii.encode('JUNK'));
    ByteData.sublistView(bytes).setUint32(40, 1, Endian.little);
    bytes.setRange(46, bytes.length, original.sublist(36));
    ByteData.sublistView(bytes).setUint32(4, bytes.length - 8, Endian.little);
    expect(voiceDurationMillis(bytes), 1000);
  });
  test('Voice only and caption send without inventing incoming messages', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    final a = s.sendChatMessage('minh-phat', '', voice: voiceFixture());
    final b = s.sendChatMessage(
      'minh-phat',
      ' Hẹn gặp ',
      voice: voiceFixture(),
    );
    expect(a.voiceMillis, 1000);
    expect(a.preview, 'Tin nhắn thoại · 0:01');
    expect(b.text, 'Hẹn gặp');
    expect(a.id, isNot(b.id));
    expect(DemoChatMessage.fromJson(a.toJson()).voice, a.voice);
    expect(s.conversation('minh-phat').messages.length, 8);
    expect(
      () => s.sendChatMessage('minh-phat', '', voice: Uint8List(0)),
      throwsStateError,
    );
    expect(
      () => s.sendChatMessage(
        'minh-phat',
        '',
        voice: voiceFixture(),
        image: Uint8List(0),
      ),
      throwsStateError,
    );
    expect(s.conversation('minh-phat').messages.length, 8);
  });
  test('Voice quota is account scoped and does not prevent text', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    for (var i = 0; i < maxChatVoicesPerAccount; i++) {
      s.sendChatMessage(
        i.isOdd ? 'minh-phat' : 'van-duc',
        '',
        voice: voiceFixture(),
      );
    }
    expect(
      () => s.sendChatMessage('minh-phat', '', voice: voiceFixture()),
      throwsStateError,
    );
    s.sendChatMessage('minh-phat', 'Vẫn gửi văn bản');
    s.register('Another', 'voice@example.com', 'Player1234');
    expect(
      s.sendChatMessage('minh-phat', '', voice: voiceFixture()).voiceMillis,
      1000,
    );
  });
  test(
    'Failed save retries one voice, reload and aliases preserve isolation',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      store.failWrite = true;
      s.sendChatMessage('minh-phat', '', voice: voiceFixture());
      expect(await s.flush(), isFalse);
      store.failWrite = false;
      await s.retrySave();
      final reload = open(store: store);
      await reload.initialize();
      expect(reload.loadFailed, isFalse);
      expect(
        reload
            .conversation('minh-phat')
            .messages
            .where((m) => m.voice.isNotEmpty)
            .length,
        1,
      );
      expect(reload.bookings.length, 2);
      reload.register('Other', 'other@example.com', 'Player1234');
      expect(
        reload.conversations
            .expand((c) => c.messages)
            .where((m) => m.voice.isNotEmpty),
        isEmpty,
      );
    },
  );
  for (final kind in ['duration', 'encoding', 'limit']) {
    test('Corrupt voice $kind snapshot is rejected without writing', () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      s.sendChatMessage('minh-phat', '', voice: voiceFixture());
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      final messages = data['chats'][DemoSession.phone][0]['messages'] as List;
      final raw = messages.last as Map<String, dynamic>;
      if (kind == 'duration') {
        raw['voiceMillis'] = 999999;
      } else if (kind == 'encoding') {
        raw['voice'] = 'AAAA';
      } else {
        for (var i = 0; i < 20; i++) {
          messages.add({...raw, 'id': 'extra-$i'});
        }
      }
      store.value = jsonEncode(data);
      final value = store.value, writes = store.writes;
      final reload = open(store: store);
      await reload.initialize();
      expect(reload.loadFailed, isTrue);
      expect(store.value, value);
      expect(store.writes, writes);
    });
  }
}
