import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _key = 'nvh_demo_session_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}
