import 'package:flutter/material.dart';
import 'package:my_first_app/domain/models/movie.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';

/// Card interativo de filme: basta tocar no card do filme que você acha que tem a maior nota.
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.showRating,
    required this.isChallenger,
    required this.isInteractive,
    required this.isSelected,
    required this.lastGuessCorrect,
    required this.onSelectThisMovie,
  });

  final Movie movie;
  final bool showRating;
  final bool isChallenger;
  final bool isInteractive;
  final bool isSelected;
  final bool? lastGuessCorrect;
  final VoidCallback onSelectThisMovie;

  Color _resolveBorderColor() {
    if (lastGuessCorrect != null && isSelected) {
      return lastGuessCorrect!
          ? AppColors.letterboxdGreen
          : AppColors.errorRed;
    }
    if (isChallenger && isInteractive) {
      return AppColors.letterboxdBlue.withValues(alpha: 0.65);
    }
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _resolveBorderColor();
    final borderWidth = (lastGuessCorrect != null && isSelected) ? 2.8 : 1.4;

    return Semantics(
      button: isInteractive,
      label: showRating
          ? '${movie.title} (${movie.year}), nota ${movie.rating.toStringAsFixed(2)} no Letterboxd. Toque se achar que tem a maior nota.'
          : '${movie.title} (${movie.year}), nota oculta. Toque se achar que tem a maior nota.',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            if (lastGuessCorrect != null && isSelected)
              BoxShadow(
                color: borderColor.withValues(alpha: 0.32),
                blurRadius: 24,
                spreadRadius: 2,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: isInteractive
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onTap: isInteractive ? onSelectThisMovie : null,
            splashColor: AppColors.letterboxdGreen.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fundo ambiente escurecido com o próprio pôster
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.network(
                      movie.posterUrl,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.surface.withValues(alpha: 0.55),
                          AppColors.background.withValues(alpha: 0.94),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final useHorizontalLayout = constraints.maxHeight < 330;
                      if (useHorizontalLayout) {
                        return _HorizontalCardBody(
                          movie: movie,
                          showRating: showRating,
                          isInteractive: isInteractive,
                        );
                      }
                      return _VerticalCardBody(
                        movie: movie,
                        showRating: showRating,
                        isInteractive: isInteractive,
                      );
                    },
                  ),
                ),
                if (lastGuessCorrect != null && isSelected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _FeedbackBadge(isCorrect: lastGuessCorrect!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalCardBody extends StatelessWidget {
  const _VerticalCardBody({
    required this.movie,
    required this.showRating,
    required this.isInteractive,
  });

  final Movie movie;
  final bool showRating;
  final bool isInteractive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: _FramedPoster(movie: movie),
          ),
        ),
        const SizedBox(height: 12),
        _MovieMetadata(movie: movie, centered: true),
        const SizedBox(height: 10),
        _RatingBadgeSection(
          movie: movie,
          showRating: showRating,
          isInteractive: isInteractive,
          compact: false,
        ),
      ],
    );
  }
}

class _HorizontalCardBody extends StatelessWidget {
  const _HorizontalCardBody({
    required this.movie,
    required this.showRating,
    required this.isInteractive,
  });

  final Movie movie;
  final bool showRating;
  final bool isInteractive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPosterWidth = (constraints.maxWidth * 0.36).clamp(80.0, 180.0);
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPosterWidth),
              child: Center(
                child: _FramedPoster(movie: movie),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: _MovieMetadata(movie: movie, centered: false),
                  ),
                  const SizedBox(height: 10),
                  _RatingBadgeSection(
                    movie: movie,
                    showRating: showRating,
                    isInteractive: isInteractive,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FramedPoster extends StatelessWidget {
  const _FramedPoster({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          movie.posterUrl,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _PosterPlaceholder(movie: movie, isLoading: true);
          },
          errorBuilder: (_, _, _) =>
              _PosterPlaceholder(movie: movie, isLoading: false),
        ),
      ),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.movie, required this.isLoading});

  final Movie movie;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            const Icon(
              Icons.local_movies_rounded,
              size: 36,
              color: AppColors.textSecondary,
            ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              movie.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieMetadata extends StatelessWidget {
  const _MovieMetadata({required this.movie, required this.centered});

  final Movie movie;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${movie.year} • Dir. ${movie.director}',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RatingBadgeSection extends StatelessWidget {
  const _RatingBadgeSection({
    required this.movie,
    required this.showRating,
    required this.isInteractive,
    required this.compact,
  });

  final Movie movie;
  final bool showRating;
  final bool isInteractive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accentColor = showRating
        ? AppColors.letterboxdGreen
        : AppColors.letterboxdBlue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: FittedBox(
            key: ValueKey('${movie.id}_rating_$showRating'),
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.65),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    showRating ? movie.rating.toStringAsFixed(2) : '?.??',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    ' / 5.0',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isInteractive) ...[
          const SizedBox(height: 6),
          const Text(
            'Toque se este tiver a maior nota',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedbackBadge extends StatelessWidget {
  const _FeedbackBadge({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final bgColor = isCorrect ? AppColors.letterboxdGreen : AppColors.errorRed;
    final fgColor = isCorrect ? AppColors.background : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: fgColor,
          ),
          const SizedBox(width: 4),
          Text(
            isCorrect ? 'Acertou!' : 'Errou!',
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
