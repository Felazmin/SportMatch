import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/chat/demo_chat.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final now = DateTime(2026, 10, 6, 15, 37);
  DemoSession open({TestSessionStore? store}) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  void login(DemoSession s) => s.login(DemoSession.email, DemoSession.password);

  test('Guest access blocked, seeds and searches match the reference', () {
    final s = open();
    expect(s.conversations, isEmpty);
    expect(() => s.sendChatMessage('minh-phat', 'Hi'), throwsStateError);
    expect(() => s.markAllChatsRead(), throwsStateError);
    login(s);
    expect(s.conversations.length, 5);
    expect(s.unreadMessages, 3);
    expect(s.conversation('minh-phat').messages.length, 6);
    expect(
      filterConversations(
        s.conversations,
        query: '  hoang NAM ',
      ).single.contactId,
      'hoang-nam',
    );
    expect(
      filterConversations(s.conversations, sport: 'Bóng đá').single.contactId,
      'van-duc',
    );
    expect(filterConversations(s.conversations, unreadOnly: true).length, 2);
    expect(filterConversations(s.conversations, query: 'not here'), isEmpty);
    expect(() => s.conversations.clear(), throwsUnsupportedError);
    expect(
      () => s.conversation('minh-phat').messages.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'Sending trims, validates, uses unique ids and does not invent a reply',
    () {
      final s = open();
      login(s);
      for (final invalid in ['', '  ', 'x' * 2001]) {
        expect(() => s.sendChatMessage('minh-phat', invalid), throwsStateError);
      }
      expect(() => s.sendChatMessage('unknown', 'hello'), throwsStateError);
      final first = s.sendChatMessage('minh-phat', '  Hẹn gặp nhé  ');
      final second = s.sendChatMessage('minh-phat', 'Hẹn gặp nhé');
      expect(first.text, 'Hẹn gặp nhé');
      expect(first.id, isNot(second.id));
      expect(first.created, now);
      expect(first.outgoing, isTrue);
      expect(s.conversation('minh-phat').messages.length, 8);
      expect(s.conversations.first.contactId, 'minh-phat');
    },
  );

  test(
    'Read state and histories are isolated across accounts and login aliases',
    () {
      final s = open();
      login(s);
      s.markChatRead('hoang-nam');
      s.sendChatMessage('minh-phat', 'Only demo owner');
      expect(s.unreadMessages, 1);
      s.register('Another', 'other@example.com', 'Test1234');
      expect(s.unreadMessages, 3);
      expect(s.conversation('minh-phat').messages.length, 6);
      s.markAllChatsRead();
      expect(s.unreadMessages, 0);
      s.logout();
      expect(s.conversations, isEmpty);
      s.login(DemoSession.phone, DemoSession.password);
      expect(s.unreadMessages, 1);
      expect(s.conversation('minh-phat').messages.last.text, 'Only demo owner');
    },
  );

  test('Chat state survives restart without reseeding read contacts', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    login(s);
    s.markAllChatsRead();
    s.sendChatMessage('minh-phat', 'Saved text');
    expect(await s.flush(), isTrue);
    final restored = open(store: store);
    await restored.initialize();
    expect(restored.loadFailed, isFalse);
    expect(restored.unreadMessages, 0);
    expect(restored.conversation('minh-phat').messages.last.text, 'Saved text');
    restored.logout();
    login(restored);
    expect(restored.conversation('minh-phat').messages.length, 7);
    await restored.flush();
  });

  test(
    'Old snapshots migrate additively, preserving bookings and profile',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      login(s);
      s.updateName('Preserved');
      await s.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      data.remove('chats');
      store.value = jsonEncode(data);
      final restored = open(store: store);
      await restored.initialize();
      expect(restored.initialized, isTrue);
      expect(restored.user!.name, 'Preserved');
      expect(restored.bookings.length, 2);
      expect(restored.conversations.length, 5);
      expect((jsonDecode(store.value!) as Map)['chats'], isNotNull);
    },
  );

  for (final corruption in [
    'owner',
    'duplicate',
    'contact',
    'message',
    'unread',
  ]) {
    test(
      'Invalid $corruption chat data does not overwrite stored data',
      () async {
        final store = TestSessionStore();
        final s = open(store: store);
        await s.initialize();
        login(s);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        final chats = data['chats'] as Map<String, dynamic>;
        final threads = chats[DemoSession.phone] as List<dynamic>;
        final first = threads.first as Map<String, dynamic>;
        switch (corruption) {
          case 'owner':
            chats['unknown'] = chats.remove(DemoSession.phone);
          case 'duplicate':
            threads.add(first);
          case 'contact':
            first['contactId'] = 'unknown';
          case 'message':
            (first['messages'] as List).add((first['messages'] as List).first);
          case 'unread':
            first['unread'] = 99;
        }
        final corrupted = jsonEncode(data);
        store.value = corrupted;
        final writes = store.writes;
        final restored = open(store: store);
        await restored.initialize();
        expect(restored.loadFailed, isTrue);
        expect(restored.initialized, isFalse);
        expect(restored.user, isNull);
        expect(store.value, corrupted);
        expect(store.writes, writes);
      },
    );
  }

  test('A failed write can retry without appending another message', () async {
    final store = TestSessionStore();
    final s = open(store: store);
    await s.initialize();
    login(s);
    await s.flush();
    store.failWrite = true;
    s.sendChatMessage('minh-phat', 'Do not duplicate');
    expect(await s.flush(), isFalse);
    store.failWrite = false;
    await s.retrySave();
    final restored = open(store: store);
    await restored.initialize();
    expect(
      restored
          .conversation('minh-phat')
          .messages
          .where((m) => m.text == 'Do not duplicate')
          .length,
      1,
    );
  });
  test('Relative timestamps include minute/hour/day boundaries', () {
    expect(chatRelativeTime(now, now), 'Vừa xong');
    expect(
      chatRelativeTime(now.subtract(const Duration(minutes: 10)), now),
      '10 phút trước',
    );
    expect(
      chatRelativeTime(now.subtract(const Duration(hours: 2)), now),
      '2 giờ trước',
    );
    expect(
      chatRelativeTime(now.subtract(const Duration(days: 1)), now),
      'Hôm qua',
    );
    expect(chatClock(now), '15:37');
  });
}
