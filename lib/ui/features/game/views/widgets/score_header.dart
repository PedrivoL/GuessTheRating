import 'package:flutter/material.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Barra superior com título do jogo, botões de Conta e Perfil do Letterboxd, placar atual e recorde.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    super.key,
    required this.score,
    required this.highScore,
    required this.isNewRecord,
    required this.onRestart,
    required this.onOpenProfile,
    required this.onOpenAccount,
    this.activeUsername,
    this.loggedInAccountUsername,
  });

  final int score;
  final int highScore;
  final bool isNewRecord;
  final VoidCallback onRestart;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAccount;
  final String? activeUsername;
  final String? loggedInAccountUsername;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RestartRunButton(onPressed: onRestart),
              const SizedBox(width: 10),
              const LetterboxdDots(dotSize: 11),
              const SizedBox(width: 10),
              const Flexible(
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AccountButton(
                loggedInUsername: loggedInAccountUsername,
                onPressed: onOpenAccount,
              ),
              _ProfilePoolButton(
                activeUsername: activeUsername,
                onPressed: onOpenProfile,
              ),
              _ScorePill(
                key: const Key('current_score_pill'),
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.letterboxdOrange,
                label: 'Acertos',
                value: '$score',
                highlighted: false,
              ),
              _ScorePill(
                key: const Key('high_score_pill'),
                icon: Icons.emoji_events_rounded,
                iconColor: AppColors.trophyYellow,
                label: isNewRecord ? 'Novo Recorde' : 'Recorde',
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

class _RestartRunButton extends StatelessWidget {
  const _RestartRunButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Reiniciar partida',
      child: Material(
        color: AppColors.surfaceElevated,
        child: InkWell(
          key: const Key('btn_restart_run'),
          onTap: onPressed,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 17,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.loggedInUsername,
    required this.onPressed,
  });

  final String? loggedInUsername;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLogged =
        loggedInUsername != null && loggedInUsername!.isNotEmpty;
    return Tooltip(
      message: isLogged
          ? 'Conta conectada: @$loggedInUsername'
          : 'Criar conta ou entrar com @nick e senha',
      child: Material(
        color: isLogged
            ? AppColors.letterboxdOrange.withValues(alpha: 0.16)
            : AppColors.surfaceElevated,
        child: InkWell(
          key: const Key('btn_account'),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: isLogged
                    ? AppColors.letterboxdOrange
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLogged
                      ? Icons.verified_user_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: isLogged
                      ? AppColors.letterboxdOrange
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  isLogged ? 'Conta: @$loggedInUsername' : 'Conta',
                  style: TextStyle(
                    color: isLogged
                        ? AppColors.letterboxdOrange
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePoolButton extends StatelessWidget {
  const _ProfilePoolButton({
    required this.activeUsername,
    required this.onPressed,
  });

  final String? activeUsername;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isActive = activeUsername != null && activeUsername!.isNotEmpty;
    return Tooltip(
      message: isActive
          ? 'Jogando com filmes de @$activeUsername (toque para alterar)'
          : 'Usar seus filmes assistidos do Letterboxd',
      child: Material(
        color: isActive
            ? AppColors.letterboxdGreen.withValues(alpha: 0.16)
            : AppColors.surfaceElevated,
        child: InkWell(
          key: const Key('btn_letterboxd_profile'),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: isActive ? AppColors.letterboxdGreen : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  size: 16,
                  color: isActive
                      ? AppColors.letterboxdGreen
                      : AppColors.letterboxdBlue,
                ),
                const SizedBox(width: 5),
                Text(
                  isActive ? '@$activeUsername' : 'Seu @nick',
                  style: TextStyle(
                    color: isActive
                        ? AppColors.letterboxdGreen
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
