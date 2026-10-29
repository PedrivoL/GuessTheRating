import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:my_first_app/data/repositories/movie_repository.dart';
import 'package:my_first_app/data/repositories/score_repository.dart';
import 'package:my_first_app/data/services/movie_catalog_service.dart';
import 'package:my_first_app/data/services/score_storage_service.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

@Preview(name: 'Mobile - Jogando', group: 'Telas', size: Size(390, 844))
Widget mobileGamePreview() {
  return MyApp(
    viewModelBuilder: () => GameViewModel.preview(score: 4, highScore: 9),
  );
}

@Preview(name: 'Web/Desktop - Jogando', group: 'Telas', size: Size(1024, 720))
Widget webGamePreview() {
  return MyApp(
    viewModelBuilder: () => GameViewModel.preview(score: 4, highScore: 9),
  );
}

@Preview(name: 'Mobile - Fim de Jogo', group: 'Telas', size: Size(390, 844))
Widget gameOverPreview() {
  return MyApp(
    viewModelBuilder: () =>
        GameViewModel.preview(score: 6, highScore: 6, gameOver: true),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.viewModel, this.viewModelBuilder});

  final GameViewModel? viewModel;
  final GameViewModel Function()? viewModelBuilder;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GameViewModel? _ownedViewModel;

  GameViewModel get _activeViewModel => widget.viewModel ?? _ownedViewModel!;

  @override
  void initState() {
    super.initState();
    _ensureOwnedViewModelIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel != null && _ownedViewModel != null) {
      _ownedViewModel!.dispose();
      _ownedViewModel = null;
    } else if (widget.viewModel == null && _ownedViewModel == null) {
      _ensureOwnedViewModelIfNeeded();
    }
  }

  void _ensureOwnedViewModelIfNeeded() {
    if (widget.viewModel != null) return;
    final builder = widget.viewModelBuilder;
    if (builder != null) {
      _ownedViewModel = builder();
      return;
    }
    final vm = GameViewModel(
      movieRepository: MovieRepository(
        catalogService: const AssetMovieCatalogService(),
      ),
      scoreRepository: ScoreRepository(
        storageService: const SharedPreferencesScoreService(),
      ),
    );
    _ownedViewModel = vm;
    vm.initialize();
  }

  @override
  void dispose() {
    _ownedViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuessTheRating • Qual tem a Maior Nota?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: GameScreen(viewModel: _activeViewModel),
    );
  }
}
