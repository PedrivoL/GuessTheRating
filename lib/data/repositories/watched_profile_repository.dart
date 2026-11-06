import 'package:my_first_app/data/services/watched_profile_service.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';

/// Repositório responsável por gerenciar o perfil de filmes assistidos do jogador.
class WatchedProfileRepository {
  WatchedProfileRepository({required this._storageService});

  final WatchedProfileService _storageService;

  Future<WatchedProfile?> getProfile() => _storageService.loadProfile();

  Future<void> saveProfile(WatchedProfile profile) =>
      _storageService.saveProfile(profile);

  Future<void> clearProfile() => _storageService.clearProfile();
}
