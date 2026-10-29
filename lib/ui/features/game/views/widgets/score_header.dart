import 'package:flutter/material.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Barra superior com título do jogo, placar da rodada atual e recorde salvo.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.score,
    required this.highScore,
    required this.isNewRecord,
  });

  final int score;
  final int highScore;
  final bool isNewRecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LetterboxdDots(dotSize: 11),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'QUAL TEM A MAIOR NOTA?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ScorePill(
                key: const Key('current_score_pill'),
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.letterboxdOrange,
                label: 'Acertos',
                value: '$score',
                highlighted: false,
              ),
              const SizedBox(width: 8),
              _ScorePill(
                key: const Key('high_score_pill'),
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.trophyYellow,
                label: isNewRecord ? 'Novo Recorde!' : 'Recorde',
                value: '$highScore',
                highlighted: isNewRecord,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.trophyYellow.withValues(alpha: 0.18)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: highlighted ? AppColors.trophyYellow : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
