import 'package:flutter_test/flutter_test.dart';
import 'package:test_do_an/auth/demo_session.dart';

void main() {
  test('Demo login accepts phone, country code and email', () {
    for (final identifier in [
      '090 123 4567',
      '+84 901234567',
      '901234567',
      'DEMO@NVH.VN',
    ]) {
      final session = DemoSession();
      expect(session.login(identifier, 'Demo1234'), isTrue);
      expect(session.user!.name, 'Văn Hùng');
      session.dispose();
    }
  });

  test('Incorrect credentials do not create a session', () {
    final session = DemoSession();
    expect(session.login('0901234567', 'wrong123'), isFalse);
    expect(session.user, isNull);
    session.dispose();
  });

  test('Registered account can log out and log in again', () {
    final session = DemoSession();
    expect(
      session.register('Minh Phát', 'phat@example.com', 'Newpass123'),
      isTrue,
    );
    session.logout();
    expect(session.user, isNull);
    expect(session.login('PHAT@example.com', 'Newpass123'), isTrue);
    expect(session.user!.name, 'Minh Phát');
    session.dispose();
  });

  test('Duplicates are rejected without replacing existing credentials', () {
    final session = DemoSession();
    expect(session.register('A', '0901234567', 'Newpass123'), isFalse);
    expect(session.register('A', 'demo@nvh.vn', 'Newpass123'), isFalse);
    expect(session.register('A', '0912345678', 'Newpass123'), isTrue);
    expect(session.register('B', '+84 912345678', 'Otherpass123'), isFalse);
    session.logout();
    expect(session.login('0912345678', 'Newpass123'), isTrue);
    expect(session.user!.name, 'A');
    session.dispose();
  });

  test(
    'Profile updates survive logout and invalid blank names are ignored',
    () {
      final session = DemoSession();
      session.login('demo@nvh.vn', 'Demo1234');
      session.updateName('  Minh Phát  ');
      session.updateName('   ');
      session.logout();
      session.login('0901234567', 'Demo1234');
      expect(session.user!.name, 'Minh Phát');
      session.dispose();
    },
  );

  test('New app instance does not retain registered demo accounts', () {
    final first = DemoSession();
    first.register('A', 'a@example.com', 'Newpass123');
    first.dispose();
    final second = DemoSession();
    expect(second.login('a@example.com', 'Newpass123'), isFalse);
    second.dispose();
  });
}
