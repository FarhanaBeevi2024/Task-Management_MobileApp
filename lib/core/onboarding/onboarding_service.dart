import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingService {
  OnboardingService(this._storage);

  static const _keySeen = 'onboarding_seen';

  final FlutterSecureStorage _storage;

  bool? _cachedSeen;

  Future<bool> hasSeenIntro() async {
    final cached = _cachedSeen;
    if (cached != null) return cached;
    final raw = await _storage.read(key: _keySeen);
    final seen = raw == '1' || raw?.toLowerCase() == 'true';
    _cachedSeen = seen;
    return seen;
  }

  Future<void> markSeen() async {
    _cachedSeen = true;
    await _storage.write(key: _keySeen, value: '1');
  }

  Future<void> resetForTesting() async {
    _cachedSeen = false;
    await _storage.delete(key: _keySeen);
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(const FlutterSecureStorage());
});

