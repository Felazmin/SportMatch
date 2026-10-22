import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/auth/session_store.dart';

class TestSessionStore implements SessionStore {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    await beforeWrite?.call();
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 3, 10);
  final start = DateTime(2026, 10, 4, 12);
  DemoSession open(SessionStore store) =>
      DemoSession(store: store, now: () => now);
  test('Fresh store seeds once and restores login, profile and booking without duplicating seeds', () async {
    final store = TestSessionStore();
    final first = open(store);
    await first.initialize();
    first.login(DemoSession.email, DemoSession.password);
    first.updateName('Test Profile');
    first.reserve(
      court: 2,
      start: start,
      hours: 2,
      contact: 'Test Profile',
      contactPhone: DemoSession.phone,
    );
    expect(await first.flush(), isTrue);
    first.dispose();
    final second = open(store);
    await second.initialize();
    expect(second.user!.name, 'Test Profile');
    expect(second.bookings.length, 3);
    expect(second.bookings.singleWhere((b) => b.id == 'NVH0003').total, 240000);
    expect(second.available(2, start, 1), isFalse);
    await second.initialize();
    expect(second.bookings.length, 3);
    second.dispose();
  });
  test('Registered accounts and logout survive restart and retain isolated histories', () async {
    final store = TestSessionStore();
    final first = open(store);
    await first.initialize();
    first.register('New User', 'new@example.com', 'Test1234');
    first.reserve(
      court: 2,
      start: start,
      hours: 1,
      contact: 'New User',
      contactPhone: '0912345678',
    );
    first.logout();
    await first.flush();
    first.dispose();
    final second = open(store);
    await second.initialize();
    expect(second.user, isNull);
    expect(second.bookings, isEmpty);
    expect(second.login('new@example.com', 'wrong'), isFalse);
    expect(second.login('NEW@EXAMPLE.COM', 'Test1234'), isTrue);
    expect(second.bookings.length, 1);
    expect(
      second.register('Duplicate', 'new@example.com', 'Other123'),
      isFalse,
    );
    second.login(DemoSession.phone, DemoSession.password);
    expect(second.bookings.length, 2);
    await second.flush();
    second.dispose();
  });
  test('Cancelled status and released availability persist', () async {
    final store = TestSessionStore();
    final first = open(store);
    await first.initialize();
    first.login(DemoSession.phone, DemoSession.password);
    final booking = first.reserve(
      court: 2,
      start: start,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    first.cancel(booking);
    await first.flush();
    first.dispose();
    final second = open(store);
    await second.initialize();
    expect(
      second.bookings.singleWhere((b) => b.id == booking.id).cancelled,
      isTrue,
    );
    expect(second.upcomingCount, 2);
    expect(second.available(2, start, 1), isTrue);
    final next = second.reserve(
      court: 2,
      start: start,
      hours: 1,
      contact: 'Test',
      contactPhone: DemoSession.phone,
    );
    expect(next.id, 'NVH0004');
    await second.flush();
    second.dispose();
  });
  test(
    'Slow writes are serialized and latest profile and logout win',
    () async {
      final store = TestSessionStore();
      final session = open(store);
      await session.initialize();
      final block = Completer<void>();
      store.beforeWrite = () => block.future;
      session.login(DemoSession.phone, DemoSession.password);
      session.updateName('Latest');
      session.logout();
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 2);
      block.complete();
      await session.flush();
      final data = jsonDecode(store.value!) as Map<String, dynamic>;
      expect(data['activeUser'], isNull);
      expect(data['demoName'], 'Latest');
      expect(store.writes, 4);
      session.dispose();
    },
  );
  test(
    'Read failure blocks mutations and retry preserves existing payload',
    () async {
      final store = TestSessionStore();
      final first = open(store);
      await first.initialize();
      first.login(DemoSession.phone, DemoSession.password);
      await first.flush();
      first.dispose();
      final original = store.value;
      final writes = store.writes;
      store.failRead = true;
      final session = open(store);
      await session.initialize();
      expect(session.loadFailed, isTrue);
      expect(session.initialized, isFalse);
      expect(
        () => session.register('Test', '0912345678', 'Test1234'),
        throwsStateError,
      );
      expect(store.value, original);
      expect(store.writes, writes);
      store.failRead = false;
      await session.initialize();
      expect(session.user!.identifier, DemoSession.phone);
      session.dispose();
    },
  );
  test(
    'Malformed and future-version snapshots are never silently overwritten',
    () async {
      for (final value in [
        'not json',
        '{"version":2}',
        '{"version":1,"demoName":"","users":[]}',
      ]) {
        final store = TestSessionStore()..value = value;
        final session = open(store);
        await session.initialize();
        expect(session.loadFailed, isTrue);
        expect(session.initialized, isFalse);
        await session.retrySave();
        expect(store.value, value);
        expect(store.writes, 0);
        session.dispose();
      }
    },
  );
  test('Invalid owner or booking values reject entire snapshot', () async {
    final original = TestSessionStore();
    final seed = open(original);
    await seed.initialize();
    seed.dispose();
    for (final field in ['owner', 'court', 'hours', 'phone', 'start']) {
      final data = jsonDecode(original.value!) as Map<String, dynamic>;
      final booking = (data['bookings'] as List).first as Map<String, dynamic>;
      booking[field] = switch (field) {
        'owner' => 'unknown',
        'court' => 9,
        'hours' => 0,
        'phone' => 'abc',
        _ => 'bad date',
      };
      final store = TestSessionStore()..value = jsonEncode(data);
      final session = open(store);
      await session.initialize();
      expect(session.loadFailed, isTrue);
      expect(store.writes, 0);
      session.dispose();
    }
  });
  test(
    'Write failures retain previous snapshot and retry saves latest state',
    () async {
      final store = TestSessionStore();
      final session = open(store);
      await session.initialize();
      final original = store.value;
      store.failWrite = true;
      session.register('Saved Later', '0912345678', 'Test1234');
      expect(await session.flush(), isFalse);
      expect(session.saveFailed, isTrue);
      expect(store.value, original);
      store.failWrite = false;
      await session.retrySave();
      expect(session.saveFailed, isFalse);
      final restored = open(store);
      await restored.initialize();
      expect(restored.user!.name, 'Saved Later');
      session.dispose();
      restored.dispose();
    },
  );
  test(
    'Pending save can finish after dispose without notifier errors',
    () async {
      final store = TestSessionStore();
      final session = open(store);
      await session.initialize();
      session.login(DemoSession.phone, DemoSession.password);
      session.dispose();
      expect(await session.flush(), isTrue);
    },
  );
  test(
    'Secure storage adapter reads and writes the app-specific key',
    () async {
      FlutterSecureStorage.setMockInitialValues({'unrelated': 'keep'});
      const store = SecureSessionStore();
      expect(await store.read(), isNull);
      await store.write('sample');
      expect(await store.read(), 'sample');
      expect(await const FlutterSecureStorage().read(key: 'unrelated'), 'keep');
    },
  );
}
