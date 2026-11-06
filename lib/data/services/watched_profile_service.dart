import 'dart:convert';
import 'package:my_first_app/domain/models/watched_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrato para armazenamento persistente do perfil Letterboxd do jogador.
abstract interface class WatchedProfileService {
  Future<WatchedProfile?> loadProfile();
  Future<void> saveProfile(WatchedProfile profile);
  Future<void> clearProfile();
}

/// Implementação persistente usando SharedPreferences (Android + Web).
class SharedPrefsWatchedProfileService implements WatchedProfileService {
  const SharedPrefsWatchedProfileService();

  static const String _profileKey = 'letterboxd_watched_profile_v1';

  @override
  Future<WatchedProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return WatchedProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveProfile(WatchedProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }
}

/// Implementação em memória para testes e Widget Previews.
class InMemoryWatchedProfileService implements WatchedProfileService {
  InMemoryWatchedProfileService({WatchedProfile? initialProfile})
    : _profile = initialProfile;

  WatchedProfile? _profile;

  @override
  Future<WatchedProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(WatchedProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clearProfile() async {
    _profile = null;
  }
}
