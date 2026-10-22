import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';
import 'package:test_do_an/auth/demo_registration.dart';

import 'persistence_test.dart' show TestSessionStore;

void main() {
  late DateTime now;
  setUp(() => now = DateTime(2026, 10, 7, 10));
  DemoSession make([TestSessionStore? store]) {
    final s = DemoSession(now: () => now, store: store);
    addTearDown(s.dispose);
    return s;
  }

  test('Account exists only after correct OTP; normalized phone and replay protection', () {
    final s = make();
    final c = s.beginDemoRegistration('New', '+84 912345678', 'Test1234');
    expect(s.user, isNull);
    expect(s.login('0912345678', 'Test1234'), isFalse);
    s.completeDemoRegistration(c, '123456');
    expect(s.user!.identifier, '0912345678');
    expect(c.consumed, isTrue);
    expect(() => s.completeDemoRegistration(c, '123456'), throwsStateError);
    s.logout();
    expect(s.login('0912345678', 'Test1234'), isTrue);
  });
  test('Wrong code increments attempts and five failures lock challenge', () {
    final s = make();
    final c = s.beginDemoRegistration('New', 'new@example.com', 'Test1234');
    for (var i = 0; i < 5; i++) {
      expect(() => s.completeDemoRegistration(c, '000000'), throwsStateError);
    }
    expect(c.attempts, 5);
    expect(() => s.completeDemoRegistration(c, '123456'), throwsStateError);
    expect(s.user, isNull);
    now = now.add(const Duration(seconds: 60));
    final replacement = s.resendDemoRegistration(c);
    expect(replacement.attempts, 0);
    s.completeDemoRegistration(replacement, '123456');
    expect(s.user!.identifier, 'new@example.com');
  });
  test('Code expires exactly after five minutes and can be resent', () {
    final s = make();
    final c = s.beginDemoRegistration('New', 'new@example.com', 'Test1234');
    now = now.add(const Duration(minutes: 5));
    expect(() => s.completeDemoRegistration(c, '123456'), throwsStateError);
    final replacement = s.resendDemoRegistration(c);
    expect(replacement.expires, now.add(const Duration(minutes: 5)));
    s.completeDemoRegistration(replacement, '123456');
    expect(s.user, isNotNull);
  });
  test(
    'Resend denies early attempts and invalidates old challenge at 60 seconds',
    () {
      final s = make();
      final c = s.beginDemoRegistration('New', 'new@example.com', 'Test1234');
      now = now.add(const Duration(milliseconds: 59999));
      expect(() => s.resendDemoRegistration(c), throwsStateError);
      now = now.add(const Duration(milliseconds: 1));
      final next = s.resendDemoRegistration(c);
      expect(() => s.completeDemoRegistration(c, '123456'), throwsStateError);
      s.completeDemoRegistration(next, '123456');
    },
  );
  test('Foreign, cancelled and superseded challenges cannot register', () {
    final s = make(), other = make();
    final foreign = other.beginDemoRegistration(
      'Other',
      'other@example.com',
      'Test1234',
    );
    expect(
      () => s.completeDemoRegistration(foreign, '123456'),
      throwsStateError,
    );
    final old = s.beginDemoRegistration('Old', 'old@example.com', 'Test1234');
    final next = s.beginDemoRegistration(
      'Next',
      'next@example.com',
      'Test1234',
    );
    s.cancelDemoRegistration(old);
    expect(() => s.completeDemoRegistration(old, '123456'), throwsStateError);
    s.completeDemoRegistration(next, '123456');
    expect(s.user!.identifier, 'next@example.com');
    final cancelled = s.beginDemoRegistration(
      'Last',
      'last@example.com',
      'Test1234',
    );
    s.cancelDemoRegistration(cancelled);
    expect(() => s.resendDemoRegistration(cancelled), throwsStateError);
  });
  test('Duplicate accounts and invalid drafts are rejected before issuing challenge', () {
    final s = make();
    expect(
      () => s.beginDemoRegistration('User', DemoSession.email, 'Test1234'),
      throwsStateError,
    );
    for (final input in [
      ('', 'test@example.com', 'Test1234'),
      ('Name', 'bad', 'Test1234'),
      ('Name', 'test@example.com', 'short'),
    ]) {
      expect(
        () => s.beginDemoRegistration(input.$1, input.$2, input.$3),
        throwsStateError,
      );
    }
  });
  test(
    'Account creation racing with verification never duplicates account',
    () {
      final s = make();
      final c = s.beginDemoRegistration('First', 'new@example.com', 'Test1234');
      s.register('Second', 'new@example.com', 'Another123');
      expect(() => s.completeDemoRegistration(c, '123456'), throwsStateError);
      expect(s.user!.name, 'Second');
      s.logout();
      expect(s.login('new@example.com', 'Test1234'), isFalse);
    },
  );
  test('Staff alias registration stays ordinary player', () {
    final s = make();
    final c = s.beginDemoRegistration(
      'Ordinary',
      DemoSession.adminEmail,
      'Test1234',
    );
    s.completeDemoRegistration(c, '123456');
    expect(s.role, DemoRole.player);
  });
  test('Pending registration is not stored or restored', () async {
    final store = TestSessionStore();
    final s = make(store);
    await s.initialize();
    final c = s.beginDemoRegistration(
      'Pending',
      'pending@example.com',
      'PendingSecret123',
    );
    await s.flush();
    expect(store.value, isNot(contains('pending@example.com')));
    expect(store.value, isNot(contains('PendingSecret123')));
    final r = make(store);
    await r.initialize();
    expect(() => r.completeDemoRegistration(c, '123456'), throwsStateError);
    expect(r.login('pending@example.com', 'PendingSecret123'), isFalse);
  });
  test(
    'Verified account persists; retry saves without repeating verification',
    () async {
      final store = TestSessionStore();
      final s = make(store);
      await s.initialize();
      store.failWrite = true;
      final c = s.beginDemoRegistration('New', 'new@example.com', 'Test1234');
      s.completeDemoRegistration(c, '123456');
      expect(await s.flush(), isFalse);
      expect(c.consumed, isTrue);
      store.failWrite = false;
      await s.retrySave();
      final r = make(store);
      await r.initialize();
      expect(r.user!.identifier, 'new@example.com');
      r.logout();
      expect(r.login('new@example.com', 'Test1234'), isTrue);
    },
  );
  test('Uninitialized sessions cannot issue or complete registration', () {
    final s = make(TestSessionStore());
    expect(
      () => s.beginDemoRegistration('New', 'new@example.com', 'Test1234'),
      throwsStateError,
    );
    expect(
      () => s.completeDemoRegistration(
        DemoRegistration(identifier: 'new@example.com', issued: now),
        '123456',
      ),
      throwsStateError,
    );
  });
}
