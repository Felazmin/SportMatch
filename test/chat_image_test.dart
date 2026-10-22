import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/chat/demo_chat.dart';

import 'multi_facility_test.dart' show sampleFacilityProof;
import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 9, 10);
  final bytes = base64Decode(sampleFacilityProof);
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void login(DemoSession s) => s.login(DemoSession.phone, DemoSession.password);

  test(
    'Image-only and caption messages preserve unique IDs and immutable data',
    () {
      final s = open();
      login(s);
      final image = s.sendChatMessage('minh-phat', '', image: bytes);
      final caption = s.sendChatMessage(
        'minh-phat',
        '  Hẹn gặp tại sân  ',
        image: bytes,
      );
      expect(image.image, sampleFacilityProof);
      expect(image.preview, 'Ảnh');
      expect(caption.preview, 'Ảnh · Hẹn gặp tại sân');
      expect(image.outgoing, isTrue);
      expect(caption.id, isNot(image.id));
      expect(DemoChatMessage.fromJson(image.toJson()).image, image.image);
      expect(s.conversation('minh-phat').messages.length, 8);
      expect(
        s.conversation('minh-phat').messages.where((m) => !m.outgoing).length,
        3,
      );
    },
  );
  test('Invalid attachment and caption reject atomically', () {
    final s = open();
    login(s);
    for (final invalid in [
      Uint8List(0),
      Uint8List(400001),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      expect(
        () => s.sendChatMessage('minh-phat', 'Photo', image: invalid),
        throwsStateError,
      );
    }
    expect(
      () => s.sendChatMessage('minh-phat', 'x' * 2001, image: bytes),
      throwsStateError,
    );
    expect(
      () => s.sendChatMessage('unknown', '', image: bytes),
      throwsStateError,
    );
    expect(s.conversation('minh-phat').messages.length, 6);
    s.logout();
    expect(
      () => s.sendChatMessage('minh-phat', '', image: bytes),
      throwsStateError,
    );
  });
  test('Account attachment limit includes all conversations, but not other accounts', () {
    final s = open();
    login(s);
    for (var i = 0; i < maxChatImagesPerAccount; i++) {
      s.sendChatMessage(i.isEven ? 'minh-phat' : 'hoang-nam', '', image: bytes);
    }
    expect(
      () => s.sendChatMessage('van-duc', '', image: bytes),
      throwsStateError,
    );
    expect(s.conversation('van-duc').messages.length, 1);
    s.sendChatMessage('van-duc', 'Văn bản vẫn gửi được');
    s.register('Another', 'image@example.com', 'Player1234');
    expect(s.conversation('minh-phat').messages.length, 6);
    expect(
      s.sendChatMessage('minh-phat', '', image: bytes).image,
      sampleFacilityProof,
    );
  });
  test('Images survive save retry and reload with one message only', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    login(s);
    await s.flush();
    store.failWrite = true;
    final message = s.sendChatMessage('minh-phat', 'Ảnh của tôi', image: bytes);
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
          .where((m) => m.id == message.id)
          .length,
      1,
    );
    expect(
      reload.conversation('minh-phat').messages.last.image,
      sampleFacilityProof,
    );
    expect(reload.bookings.length, 2);
    reload.register('Other', 'other@example.com', 'Player1234');
    expect(
      reload.conversations
          .expand((c) => c.messages)
          .where((m) => m.image.isNotEmpty),
      isEmpty,
    );
  });
  test('Legacy messages without image field migrate unchanged', () {
    final old = seedConversations(now).first.messages.first.toJson()
      ..remove('image');
    final message = DemoChatMessage.fromJson(old);
    expect(message.image, isEmpty);
    expect(message.preview, old['text']);
  });
  for (final corrupt in ['encoding', 'size', 'limit']) {
    test(
      'Corrupt image $corrupt snapshot cannot overwrite stored data',
      () async {
        final store = TestSessionStore();
        final s = open(store: store);
        await s.initialize();
        login(s);
        final message = s.sendChatMessage('minh-phat', '', image: bytes);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        final messages =
            ((data['chats'][DemoSession.phone] as List).first['messages']
                as List);
        final raw = messages.last as Map<String, dynamic>;
        if (corrupt == 'limit') {
          for (var i = 0; i < maxChatImagesPerAccount; i++) {
            messages.add({...raw, 'id': '${message.id}-extra-$i'});
          }
        } else {
          raw['image'] = corrupt == 'size' ? 'A' * 540000 : 'not an image';
        }
        store.value = jsonEncode(data);
        final value = store.value, writes = store.writes;
        final reload = open(store: store);
        await reload.initialize();
        expect(reload.loadFailed, isTrue);
        expect(store.value, value);
        expect(store.writes, writes);
      },
    );
  }
}
