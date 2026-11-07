import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/data/repositories/account_repository.dart';
import 'package:my_first_app/data/repositories/movie_repository.dart';
import 'package:my_first_app/data/repositories/score_repository.dart';
import 'package:my_first_app/data/repositories/watched_profile_repository.dart';
import 'package:my_first_app/data/services/account_service.dart';
import 'package:my_first_app/data/services/firestore_rest_client.dart';
import 'package:my_first_app/data/services/movie_catalog_service.dart';
import 'package:my_first_app/data/services/score_storage_service.dart';
import 'package:my_first_app/data/services/watched_profile_service.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:my_first_app/main.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/game_screen.dart';

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

    test('serializa e desserializa UserAccount para documento do Cloud Firestore', () {
      final account = UserAccount(
        username: 'pedrivol',
        passwordHash: UserAccount.hashPassword('pedrivol', '1234'),
        watchedMovieIds: const ['m1', 'm2'],
        totalCsvCount: 2,
        customMovies: [sampleMovies.first],
        highScore: 14,
      );
      final encoded = FirestoreAccountClient.encodeFirestoreDocument(account);
      final decoded = FirestoreAccountClient.decodeFirestoreDocument(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.username, equals('pedrivol'));
      expect(decoded.verifyPassword('1234'), isTrue);
      expect(decoded.watchedMovieIds, equals(['m1', 'm2']));
      expect(decoded.customMovies.length, equals(1));
      expect(decoded.customMovies.first.title, equals('Parasita'));
      expect(decoded.highScore, equals(14));
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

      expect(movies.length, equals(1000));
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
        expect(movie.ratingCount, greaterThan(0));
        expect(movie.posterUrl, startsWith('https://'));
      }

      final secretMovies = (await tester.runAsync(service.fetchSecretMovies))!;
      expect(secretMovies.length, greaterThanOrEqualTo(700));
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

    test('filtra o catálogo em Fácil (100), Médio (500) e Difícil (1000)', () async {
      final catalog1000 = List<Movie>.generate(
        1000,
        (i) => Movie(
          id: 'boxd_$i',
          title: 'Movie $i',
          originalTitle: 'Movie $i',
          year: 2000,
          director: 'Director',
          rating: 3.5,
          ratingCount: 1000000 - i,
          posterUrl: 'https://example.com/$i.jpg',
        ),
      );

      final vm = GameViewModel(
        movieRepository: MovieRepository(
          catalogService: StaticMovieCatalogService(catalog1000),
        ),
        scoreRepository: ScoreRepository(
          storageService: InMemoryScoreService(initialHighScore: 0),
        ),
        random: Random(3),
      );

      await vm.initialize();
      expect(vm.difficulty, equals(GameDifficulty.easy));
      expect(vm.activePoolCount, equals(100));

      await vm.setDifficulty(GameDifficulty.medium);
      expect(vm.difficulty, equals(GameDifficulty.medium));
      expect(vm.activePoolCount, equals(500));

      await vm.setDifficulty(GameDifficulty.hard);
      expect(vm.difficulty, equals(GameDifficulty.hard));
      expect(vm.activePoolCount, equals(1000));

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
      expect(find.text('Fácil'), findsOneWidget);
      expect(find.text('Médio'), findsOneWidget);
      expect(find.text('Difícil'), findsOneWidget);
      expect(find.text('Secret'), findsNothing);

      // Hover do mouse por 1 segundo sobre o botão Difícil revela o botão Secret embaixo
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('btn_difficulty_hard'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Secret'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Secret'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_difficulty_secret')));
      await tester.pump();
      expect(vm.difficulty, equals(GameDifficulty.secret));

      expect(find.text(vm.currentMovie!.title), findsWidgets);
      expect(find.text(vm.challengerMovie!.title), findsWidgets);
      // Na 1ª rodada (score == 0), as notas dos dois filmes começam ocultas
      expect(find.text('?.?'), findsNWidgets(2));

      final isChallengerHigher =
          vm.challengerMovie!.rating >= vm.currentMovie!.rating;
      final winningKey = isChallengerHigher
          ? ValueKey('chal_${vm.challengerMovie!.id}')
          : ValueKey('ref_${vm.currentMovie!.id}');

      // Acerta a primeira rodada tocando diretamente no card do filme vencedor
      await tester.tap(find.byKey(winningKey));
      await tester.pump();
      expect(find.text('Acertou!'), findsNothing);
      // Durante a revelação, as notas reais dos dois filmes aparecem na tela
      expect(
        find.text(vm.currentMovie!.rating.toStringAsFixed(2)),
        findsOneWidget,
      );
      expect(
        find.text(vm.challengerMovie!.rating.toStringAsFixed(2)),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));

      expect(vm.score, equals(1));
      expect(vm.phase, equals(GamePhase.playing));
      // A partir da 2ª rodada, o filme que permaneceu mostra a nota e só o novo fica oculto
      expect(find.text('?.?'), findsOneWidget);

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
      await tester.pump();

      expect(find.text('FIM DE JOGO'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_play_again')));
      await tester.pump();
      expect(find.text('FIM DE JOGO'), findsNothing);
      expect(vm.score, equals(0));

      // Volta para mobile (390x844), avança 1 rodada e testa o botão de reiniciar a run
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final isChallengerHigherAfterReset =
          vm.challengerMovie!.rating >= vm.currentMovie!.rating;
      final winningKeyAfterReset = isChallengerHigherAfterReset
          ? ValueKey('chal_${vm.challengerMovie!.id}')
          : ValueKey('ref_${vm.currentMovie!.id}');

      await tester.tap(find.byKey(winningKeyAfterReset));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.score, equals(1));

      await tester.tap(find.byKey(const Key('btn_restart_run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.score, equals(0));
      expect(find.text('?.?'), findsNWidgets(2));
    });

    testWidgets(
      'permite importar watched.csv com @nick e filtra a pool de filmes do jogador',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final profileStorage = InMemoryWatchedProfileService();
        final vm = GameViewModel(
          movieRepository: MovieRepository(
            catalogService: const StaticMovieCatalogService(sampleMovies),
          ),
          scoreRepository: ScoreRepository(
            storageService: InMemoryScoreService(initialHighScore: 0),
          ),
          watchedProfileRepository: WatchedProfileRepository(
            storageService: profileStorage,
          ),
          filmHtmlFetcher: (uri) async {
            if (uri == 'https://boxd.it/i7Q4') {
              return '''
<script type="application/ld+json">
/* <![CDATA[ */
{"@type":"Movie","name":"Sound of Metal","image":"https://a.ltrbxd.com/resized/sound-of-metal.jpg","director":[{"@type":"Person","name":"Darius Marder"}],"aggregateRating":{"@type":"AggregateRating","ratingValue":4.22}}
/* ]]> */
</script>
''';
            }
            return null;
          },
          random: Random(9),
        );
        await vm.initialize();
        addTearDown(vm.dispose);

        const csvSample = '''
Date,Name,Year,Letterboxd URI
2024-01-10,Parasite,2019,https://boxd.it/hTha
2024-01-12,Barbie,2023,https://boxd.it/b234
2024-01-15,Sound of Metal,2019,https://boxd.it/i7Q4
''';

        await vm.importWatchedCsv(username: 'pedrivol', csvContent: csvSample);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: GameScreen(viewModel: vm),
          ),
        );

        expect(vm.isUsingWatchedPool, isTrue);
        expect(vm.activePoolCount, equals(3));
        expect(find.text('Catálogo'), findsOneWidget);
        expect(find.text('@pedrivol'), findsOneWidget);

        // Abre o modal de Catálogo e confere o bloco Buscar username + link pronto para copiar
        await tester.tap(find.byKey(const Key('btn_letterboxd_profile')));
        await tester.pumpAndSettle();

        expect(find.text('CATÁLOGO'), findsOneWidget);
        expect(find.text('Buscar username'), findsOneWidget);
        expect(
          find.text('guesstherating.web.app/pedrivol'),
          findsOneWidget,
        );

        // Digita outro username e vê o endereço atualizar na hora no bloco
        await tester.enterText(
          find.byKey(const Key('input_letterboxd_nick')),
          'nickalvo',
        );
        await tester.pump();
        expect(
          find.text('guesstherating.web.app/nickalvo'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_close_profile_dialog')));
        await tester.pumpAndSettle();

        // O perfil fica salvo no storage incluindo o filme pesquisado fora do catálogo
        final saved = await profileStorage.loadProfile();
        expect(saved, isNotNull);
        expect(saved!.username, equals('pedrivol'));
        expect(saved.watchedMovieIds, equals(['m1', 'm2', 'boxd_i7Q4']));
        expect(saved.customMovies.length, equals(1));
        expect(saved.customMovies.first.title, equals('Sound of Metal'));
        expect(saved.customMovies.first.rating, equals(4.22));
      },
    );

    testWidgets(
      'permite criar conta com @nick e senha, sair e entrar novamente sem reenviar watched.csv',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final accountService = InMemoryAccountService();
        final vm = GameViewModel(
          movieRepository: MovieRepository(
            catalogService: const StaticMovieCatalogService(sampleMovies),
          ),
          scoreRepository: ScoreRepository(
            storageService: InMemoryScoreService(initialHighScore: 5),
          ),
          accountRepository: AccountRepository(accountService: accountService),
          random: Random(11),
        );
        await vm.initialize();
        addTearDown(vm.dispose);

        const csvSample = '''
Date,Name,Year,Letterboxd URI
2024-01-10,Parasite,2019,https://boxd.it/hTha
2024-01-12,Barbie,2023,https://boxd.it/b234
''';

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: GameScreen(
              viewModel: vm,
              csvFilePicker: () async => const PickedCsvFile(
                name: 'watched.csv',
                content: csvSample,
              ),
            ),
          ),
        );

        expect(find.text('Conta'), findsOneWidget);

        // Abre o modal de Conta ao lado do botão de @nick
        await tester.tap(find.byKey(const Key('btn_account')));
        await tester.pumpAndSettle();

        expect(find.text('CONTA DO JOGADOR'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('input_account_nick')),
          'pedrivol',
        );
        await tester.enterText(
          find.byKey(const Key('input_account_password')),
          '1234',
        );
        await tester.tap(find.byKey(const Key('btn_account_pick_csv')));
        await tester.pumpAndSettle();

        expect(
          find.text('✓ 2 filmes carregados do seu watched.csv'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('btn_submit_account')));
        await tester.pumpAndSettle();

        expect(vm.currentAccount?.username, equals('pedrivol'));
        expect(find.text('Conta: @pedrivol'), findsOneWidget);
        expect(find.text('@pedrivol'), findsOneWidget);
        expect(vm.activePoolCount, equals(2));

        // Faz logout e limpa o perfil local
        await vm.logoutAccount();
        await vm.clearWatchedProfile();
        await tester.pumpAndSettle();

        expect(vm.currentAccount, isNull);
        expect(vm.activePoolCount, equals(3));

        // Entra novamente apenas com @nick e senha (sem reenviar watched.csv)
        await tester.tap(find.byKey(const Key('btn_account')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('tab_login_account')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('input_account_nick')),
          'pedrivol',
        );
        await tester.enterText(
          find.byKey(const Key('input_account_password')),
          '1234',
        );
        await tester.tap(find.byKey(const Key('btn_submit_account')));
        await tester.pumpAndSettle();

        expect(vm.currentAccount?.username, equals('pedrivol'));
        expect(vm.isUsingWatchedPool, isTrue);
        expect(vm.activePoolCount, equals(2));
      },
    );

    testWidgets(
      'carrega catálogo automaticamente via URL guesstherating.web.app/nickalvo e alterna no modal Catálogo',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final accountService = InMemoryAccountService(
          initialAccounts: {
            'nickalvo': UserAccount(
              username: 'nickalvo',
              passwordHash: UserAccount.hashPassword('nickalvo', '1234'),
              watchedMovieIds: const ['m1', 'm2'],
              totalCsvCount: 2,
              customMovies: const [],
              highScore: 8,
            ),
          },
        );

        final vm = GameViewModel(
          movieRepository: MovieRepository(
            catalogService: const StaticMovieCatalogService(sampleMovies),
          ),
          scoreRepository: ScoreRepository(
            storageService: InMemoryScoreService(initialHighScore: 0),
          ),
          accountRepository: AccountRepository(accountService: accountService),
          initialUri: Uri.parse('https://guesstherating.web.app/nickalvo'),
          random: Random(15),
        );
        await vm.initialize();
        addTearDown(vm.dispose);

        await tester.pumpWidget(MyApp(viewModel: vm));
        await tester.pumpAndSettle();

        expect(vm.isUsingWatchedPool, isTrue);
        expect(vm.watchedProfile?.username, equals('nickalvo'));
        expect(vm.activePoolCount, equals(2));
        expect(find.text('@nickalvo'), findsOneWidget);

        // Abre o modal Catálogo e alterna para o Catálogo Geral
        await tester.tap(find.byKey(const Key('btn_letterboxd_profile')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_mode_general')));
        await tester.pumpAndSettle();

        expect(vm.isUsingWatchedPool, isFalse);
        expect(vm.activePoolCount, equals(3));

        // Abre novamente o modal Catálogo e volta para o catálogo salvo (Meu Catálogo)
        await tester.tap(find.byKey(const Key('btn_letterboxd_profile')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_mode_watched')));
        await tester.pumpAndSettle();

        expect(vm.isUsingWatchedPool, isTrue);
        expect(vm.activePoolCount, equals(2));
      },
    );
  });
}
