import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStore {
  const SecureTokenStore();

  static const _accessTokenKey = 'auth_access_token';

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<void> setAccessToken(String? token) async {
    final v = token?.trim();
    if (v == null || v.isEmpty) {
      await _storage.delete(key: _accessTokenKey);
      return;
    }
    await _storage.write(key: _accessTokenKey, value: v);
  }

  Future<String?> readAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
  }
}

