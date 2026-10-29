import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/data/repositories/movie_repository.dart';
import 'package:my_first_app/data/repositories/score_repository.dart';
import 'package:my_first_app/data/services/movie_catalog_service.dart';
import 'package:my_first_app/data/services/score_storage_service.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/main.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';

void main() {
  const sampleMovies = <Movie>[
    Movie(
      id: 'm1',
      title: 'Parasita',
      originalTitle: 'Parasite',
      year: 2019,
      director: 'Bong Joon-ho',
      rating: 4.6,
      posterUrl: 'https://example.com/parasite.jpg',
    ),
    Movie(
      id: 'm2',
      title: 'Barbie',
      originalTitle: 'Barbie',
      year: 2023,
      director: 'Greta Gerwig',
      rating: 3.8,
      posterUrl: 'https://example.com/barbie.jpg',
    ),
    Movie(
      id: 'm3',
      title: 'Morbius',
      originalTitle: 'Morbius',
      year: 2022,
      director: 'Daniel Espinosa',
      rating: 1.7,
      posterUrl: 'https://example.com/morbius.jpg',
    ),
  ];

  group('Movie Serialization', () {
    test('serializa e desserializa Movie corretamente', () {
      final json = sampleMovies.first.toJson();
      final parsed = Movie.fromJson(json);

      expect(parsed.id, equals('m1'));
      expect(parsed.title, equals('Parasita'));
      expect(parsed.rating, equals(4.6));
    });

    test('lança FormatException para JSON inválido', () {
      expect(
        () => Movie.fromJson(<String, dynamic>{'invalid': true}),
        throwsFormatException,
      );
    });

    testWidgets('catálogo real assets/data/movies.json carrega sem erros', (
      tester,
    ) async {
      const service = AssetMovieCatalogService();
      final movies = (await tester.runAsync(service.fetchMovies))!;

      expect(movies.length, greaterThanOrEqualTo(750));
      final ids = movies.map((m) => m.id).toSet();
      final posters = movies.map((m) => m.posterUrl).toSet();
      final titleYears = movies
          .map(
            (m) =>
                '${m.originalTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}|${m.year}',
          )
          .toSet();

      expect(ids.length, equals(movies.length));
      expect(posters.length, equals(movies.length));
      expect(titleYears.length, equals(movies.length));
      for (final movie in movies) {
        expect(movie.rating, inInclusiveRange(0.5, 5.0));
        expect(movie.posterUrl, startsWith('https://'));
      }
    });
  });

  group('GameViewModel Higher or Lower', () {
    test('avança mantendo o desafiante na tela ao acertar e salva recorde', () async {
      final storage = InMemoryScoreService(initialHighScore: 0);
      final vm = GameViewModel(
        movieRepository: MovieRepository(
          catalogService: const StaticMovieCatalogService(sampleMovies),
        ),
        scoreRepository: ScoreRepository(storageService: storage),
        random: Random(1),
        revealDelay: const Duration(milliseconds: 10),
        gameOverDelay: const Duration(milliseconds: 10),
      );

      await vm.initialize();
      expect(vm.phase, equals(GamePhase.playing));

      final initialChallenger = vm.challengerMovie!;
      final initialCurrent = vm.currentMovie!;
      final winner = initialChallenger.rating >= initialCurrent.rating
          ? initialChallenger
          : initialCurrent;

      await vm.chooseMovieWithHigherRating(winner);
      expect(vm.score, equals(1));
      expect(vm.highScore, equals(1));
      expect(await storage.loadHighScore(), equals(1));

      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(vm.phase, equals(GamePhase.playing));
      expect(vm.currentMovie, equals(initialChallenger));

      vm.dispose();
    });

    test('entra em gameOver ao escolher o filme com menor nota', () async {
      final vm = GameViewModel(
        movieRepository: MovieRepository(
          catalogService: const StaticMovieCatalogService(sampleMovies),
        ),
        scoreRepository: ScoreRepository(
          storageService: InMemoryScoreService(initialHighScore: 5),
        ),
        random: Random(2),
        revealDelay: const Duration(milliseconds: 10),
        gameOverDelay: const Duration(milliseconds: 10),
      );

      await vm.initialize();
      final current = vm.currentMovie!;
      final challenger = vm.challengerMovie!;
      final loser = current.rating < challenger.rating ? current : challenger;

      await vm.chooseMovieWithHigherRating(loser);
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(vm.phase, equals(GamePhase.gameOver));
      expect(vm.score, equals(0));
      expect(vm.highScore, equals(5));

      vm.restartGame();
      expect(vm.phase, equals(GamePhase.playing));

      vm.dispose();
    });
  });

  group('GameScreen Widget Tests (Mobile & Web)', () {
    testWidgets('renderiza e permite jogar e reiniciar sem erros de layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final vm = GameViewModel(
        movieRepository: MovieRepository(
          catalogService: const StaticMovieCatalogService(sampleMovies),
        ),
        scoreRepository: ScoreRepository(
          storageService: InMemoryScoreService(initialHighScore: 2),
        ),
        random: Random(7),
        revealDelay: const Duration(milliseconds: 100),
        gameOverDelay: const Duration(milliseconds: 100),
      );
      await vm.initialize();
      addTearDown(vm.dispose);

      await tester.pumpWidget(MyApp(viewModel: vm));
      expect(find.text('QUAL TEM A MAIOR NOTA?'), findsOneWidget);
      expect(find.text(vm.currentMovie!.title), findsWidgets);
      expect(find.text(vm.challengerMovie!.title), findsWidgets);

      final isChallengerHigher =
          vm.challengerMovie!.rating >= vm.currentMovie!.rating;
      final winningKey = isChallengerHigher
          ? ValueKey('chal_${vm.challengerMovie!.id}')
          : ValueKey('ref_${vm.currentMovie!.id}');

      // Acerta a primeira rodada tocando diretamente no card do filme vencedor
      await tester.tap(find.byKey(winningKey));
      await tester.pump();
      expect(find.text('Acertou!'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));

      expect(vm.score, equals(1));
      expect(vm.phase, equals(GamePhase.playing));

      // Testa redimensionamento para layout Web/Desktop largo (1024x720)
      await tester.binding.setSurfaceSize(const Size(1024, 720));
      await tester.pump();

      // Força um erro na segunda rodada tocando no card do filme com menor nota
      final isChallengerHigherRound2 =
          vm.challengerMovie!.rating >= vm.currentMovie!.rating;
      final losingKey = isChallengerHigherRound2
          ? ValueKey('ref_${vm.currentMovie!.id}')
          : ValueKey('chal_${vm.challengerMovie!.id}');

      await tester.tap(find.byKey(losingKey));
      await tester.pump();
      expect(find.text('Errou!'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('FIM DE JOGO!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_play_again')));
      await tester.pump();
      expect(find.text('FIM DE JOGO!'), findsNothing);
      expect(vm.score, equals(0));
    });
  });
}
