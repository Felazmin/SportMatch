import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/auth/demo_recovery.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  final date = DateTime(2026, 10, 6, 10);
  DemoSession open({TestSessionStore? store, DateTime Function()? clock}) {
    final s = DemoSession(store: store, now: clock ?? () => date);
    addTearDown(s.dispose);
    return s;
  }

  test(
    'Recovery requires a local account, verified challenge and valid password',
    () {
      final s = open();
      expect(
        () => s.beginDemoRecovery('unknown@example.com'),
        throwsStateError,
      );
      final r = s.beginDemoRecovery(DemoSession.email);
      expect(() => s.resetDemoPassword(r, 'New12345'), throwsStateError);
      s.verifyDemoRecovery(r, DemoRecovery.code);
      expect(() => s.resetDemoPassword(r, 'abcdefgh'), throwsStateError);
      s.resetDemoPassword(r, 'New12345');
      expect(s.login(DemoSession.phone, DemoSession.password), isFalse);
      expect(s.login(DemoSession.email, 'New12345'), isTrue);
      expect(() => s.resetDemoPassword(r, 'Other1234'), throwsStateError);
    },
  );
  test(
    'Five invalid attempts lock challenge even for the correct demo code',
    () {
      final s = open();
      final r = s.beginDemoRecovery(DemoSession.phone);
      for (var i = 0; i < 5; i++) {
        expect(() => s.verifyDemoRecovery(r, '000000'), throwsStateError);
      }
      expect(
        () => s.verifyDemoRecovery(r, DemoRecovery.code),
        throwsStateError,
      );
      expect(r.verified, isFalse);
    },
  );
  test('Resend invalidates older challenge, expiry uses exact boundaries', () {
    var now = date;
    final s = open(clock: () => now);
    final first = s.beginDemoRecovery(DemoSession.phone);
    expect(() => s.beginDemoRecovery(DemoSession.phone), throwsStateError);
    now = date.add(const Duration(seconds: 60));
    final second = s.beginDemoRecovery(DemoSession.phone);
    expect(
      () => s.verifyDemoRecovery(first, DemoRecovery.code),
      throwsStateError,
    );
    now = second.expires;
    expect(
      () => s.verifyDemoRecovery(second, DemoRecovery.code),
      throwsStateError,
    );
  });
  test(
    'Email account password recovery persists without exposing another account',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      s.register('User', 'user@example.com', 'Test1234');
      s.logout();
      final r = s.beginDemoRecovery('USER@example.com');
      s.verifyDemoRecovery(r, DemoRecovery.code);
      s.resetDemoPassword(r, 'New12345');
      await s.flush();
      final next = open(store: store);
      await next.initialize();
      expect(next.login('user@example.com', 'Test1234'), isFalse);
      expect(next.login('user@example.com', 'New12345'), isTrue);
      expect(next.login(DemoSession.phone, DemoSession.password), isTrue);
      expect(
        () => next.verifyDemoRecovery(r, DemoRecovery.code),
        throwsStateError,
      );
    },
  );
  test('Group posting requires membership and only the author can delete', () {
    final s = open();
    expect(() => s.createPost('public', 'Hello'), throwsStateError);
    s.login(DemoSession.phone, DemoSession.password);
    expect(() => s.createPost('badminton', 'Hello'), throwsStateError);
    expect(() => s.toggleGroup('unknown'), throwsStateError);
    s.toggleGroup('badminton');
    final p = s.createPost('badminton', 'Hello group');
    s.register('Other', 'other@example.com', 'Test1234');
    expect(s.posts.single.message, 'Hello group');
    expect(s.deletePost(p), isFalse);
    expect(s.joinedGroups, isEmpty);
    s.login(DemoSession.phone, DemoSession.password);
    expect(s.deletePost(p), isTrue);
    final newer = s.createPost('public', 'Second');
    expect(newer.id, 'BD0002');
    s.toggleGroup('badminton');
    expect(s.joinedGroups, isEmpty);
  });
  test('Expense division conserves integer amount, even when fewer dong than names', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    for (final amount in [1, 2, 100001, 100000000]) {
      final e = s.createExpense('Court', amount, ['An', 'Binh', 'Cuong']);
      expect(e.shares.reduce((a, b) => a + b), amount);
      expect(e.shares.first - e.shares.last, lessThanOrEqualTo(1));
    }
    s.register('Other', 'other@example.com', 'Test1234');
    expect(s.expenses, isEmpty);
  });
  test('Invalid expense and post input rejected without mutations', () {
    final s = open()..login(DemoSession.phone, DemoSession.password);
    for (final amount in [0, -1, 100000001]) {
      expect(
        () => s.createExpense('Court', amount, ['A', 'B']),
        throwsStateError,
      );
    }
    expect(() => s.createExpense('Court', 100, ['An', 'an']), throwsStateError);
    expect(() => s.createExpense('Court', 100, ['A']), throwsStateError);
    expect(() => s.createPost('public', ' '), throwsStateError);
    expect(() => s.createPost('public', 'a' * 1001), throwsStateError);
    expect(s.posts, isEmpty);
    expect(s.expenses, isEmpty);
  });
  test(
    'Community and expenses persist and post ids are not reused after deletion',
    () async {
      final store = TestSessionStore();
      final s = open(store: store);
      await s.initialize();
      s.login(DemoSession.phone, DemoSession.password);
      s.toggleGroup('badminton');
      s.deletePost(s.createPost('public', 'Delete me'));
      s.createPost('badminton', 'Keep me');
      s.createExpense('Court', 100001, ['A', 'B', 'C']);
      await s.flush();
      final restored = open(store: store);
      await restored.initialize();
      expect(restored.loadFailed, isFalse);
      expect(restored.posts.single.id, 'BD0002');
      expect(restored.joinedGroups, {'badminton'});
      expect(restored.expenses.single.shares, [33334, 33334, 33333]);
      expect(restored.createPost('public', 'Third').id, 'BD0003');
    },
  );
  for (final field in ['groups', 'posts', 'expenses']) {
    test(
      'Corrupt $field cannot overwrite or partially restore local data',
      () async {
        final store = TestSessionStore();
        final s = open(store: store);
        await s.initialize();
        s.login(DemoSession.phone, DemoSession.password);
        s.toggleGroup('badminton');
        s.createPost('public', 'Hello');
        s.createExpense('Court', 100, ['A', 'B']);
        await s.flush();
        final data = jsonDecode(store.value!) as Map<String, dynamic>;
        if (field == 'groups') {
          data['groups'] = {
            'unknown@example.com': ['badminton'],
          };
        } else {
          ((data[field] as List).first as Map<String, dynamic>)['owner'] =
              'unknown@example.com';
        }
        store.value = jsonEncode(data);
        final value = store.value;
        final restored = open(store: store);
        await restored.initialize();
        expect(restored.loadFailed, isTrue);
        expect(restored.posts, isEmpty);
        expect(store.value, value);
      },
    );
  }
}
