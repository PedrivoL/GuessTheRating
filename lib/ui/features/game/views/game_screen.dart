import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/widgets/game_over_overlay.dart';
import 'package:my_first_app/ui/features/game/views/widgets/movie_poster_card.dart';
import 'package:my_first_app/ui/features/game/views/widgets/score_header.dart';

const double _wideLayoutBreakpoint = 720.0;

/// Tela principal adaptativa (Android vertical + Web/Desktop lado a lado).
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowUp): () {
              final current = viewModel.currentMovie;
              if (current != null) {
                viewModel.chooseMovieWithHigherRating(current);
              }
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              final current = viewModel.currentMovie;
              if (current != null) {
                viewModel.chooseMovieWithHigherRating(current);
              }
            },
            const SingleActivator(LogicalKeyboardKey.arrowDown): () {
              final challenger = viewModel.challengerMovie;
              if (challenger != null) {
                viewModel.chooseMovieWithHigherRating(challenger);
              }
            },
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              final challenger = viewModel.challengerMovie;
              if (challenger != null) {
                viewModel.chooseMovieWithHigherRating(challenger);
              }
            },
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (viewModel.phase == GamePhase.gameOver) {
                viewModel.restartGame();
              }
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: SafeArea(
                child: _buildBody(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (viewModel.phase == GamePhase.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.letterboxdGreen),
      );
    }

    if (viewModel.phase == GamePhase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.errorRed,
              ),
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage ?? 'Erro ao carregar os filmes.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: viewModel.initialize,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final current = viewModel.currentMovie;
    final challenger = viewModel.challengerMovie;
    if (current == null || challenger == null) {
      return const SizedBox.shrink();
    }

    final isInteractive = viewModel.phase == GamePhase.playing;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ScoreHeader(
                    score: viewModel.score,
                    highScore: viewModel.highScore,
                    isNewRecord: viewModel.isNewRecord,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide =
                            constraints.maxWidth >= _wideLayoutBreakpoint;

                        final referenceCard = MoviePosterCard(
                          key: ValueKey('ref_${current.id}'),
                          movie: current,
                          showRating: true,
                          isChallenger: false,
                          isInteractive: isInteractive,
                          isSelected: viewModel.selectedMovieId == current.id,
                          lastGuessCorrect: viewModel.lastGuessCorrect,
                          onSelectThisMovie: () =>
                              viewModel.chooseMovieWithHigherRating(current),
                        );

                        final challengerCard = MoviePosterCard(
                          key: ValueKey('chal_${challenger.id}'),
                          movie: challenger,
                          showRating: viewModel.isChallengerRatingVisible,
                          isChallenger: true,
                          isInteractive: isInteractive,
                          isSelected:
                              viewModel.selectedMovieId == challenger.id,
                          lastGuessCorrect: viewModel.lastGuessCorrect,
                          onSelectThisMovie: () =>
                              viewModel.chooseMovieWithHigherRating(challenger),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: referenceCard),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: _VsBadge(),
                              ),
                              Expanded(child: challengerCard),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Expanded(child: referenceCard),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: _VsBadge(),
                            ),
                            Expanded(child: challengerCard),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (viewModel.phase == GamePhase.gameOver)
          Positioned.fill(
            child: GameOverOverlay(
              score: viewModel.score,
              highScore: viewModel.highScore,
              isNewRecord: viewModel.isNewRecord,
              currentMovie: current,
              challengerMovie: challenger,
              onPlayAgain: viewModel.restartGame,
            ),
          ),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Text(
        'VS',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
