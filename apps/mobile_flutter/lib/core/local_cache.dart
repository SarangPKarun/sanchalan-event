import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small non-sensitive key/value storage on the device (cached lists, drafts).
/// Tokens belong in [AuthStorage], not here. Every call swallows storage errors:
/// a cache that cannot be read or written must never break a screen.
class LocalCache {
  LocalCache([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  Future<String?> read(String key) async {
    try {
      return await _prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
    } catch (_) {}
  }
}

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());
