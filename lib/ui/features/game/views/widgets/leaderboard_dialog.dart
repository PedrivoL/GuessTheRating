import 'package:flutter/material.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Modal que exibe o Ranking Global (Leaderboard) de todos os jogadores com conta criada.
class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({
    super.key,
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  List<LeaderboardEntry> _entries = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await widget.viewModel.fetchLeaderboard();
      if (!mounted) return;
      setState(() {
        _entries = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar o ranking: $e';
        _isLoading = false;
      });
    }
  }

  Color _rankAccentColor(int rank) {
    return switch (rank) {
      1 => AppColors.trophyYellow,
      2 => const Color(0xFFC0C8D0),
      3 => const Color(0xFFCD7F32),
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUsername = widget.viewModel.currentAccount?.username;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const LetterboxdDots(dotSize: 11),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'RANKING GLOBAL',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.surfaceElevated,
                    child: InkWell(
                      key: const Key('btn_refresh_leaderboard'),
                      onTap: _isLoading ? null : _loadLeaderboard,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.surfaceElevated,
                    child: InkWell(
                      key: const Key('btn_close_leaderboard_dialog'),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.trophyYellow,
                      ),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: AppColors.errorRed),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (_entries.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Nenhum jogador cadastrado no ranking ainda.\nCrie sua Conta para inaugurar o placar global!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final rank = index + 1;
                      final accent = _rankAccentColor(rank);
                      final isCurrentUser =
                          currentUsername != null &&
                          UserAccount.normalizeUsername(currentUsername) ==
                              entry.username;

                      return Container(
                        key: Key('leaderboard_row_${entry.username}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? AppColors.letterboxdBlue.withValues(alpha: 0.14)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: isCurrentUser
                                ? AppColors.letterboxdBlue
                                : (rank == 1
                                      ? AppColors.trophyYellow.withValues(
                                          alpha: 0.55,
                                        )
                                      : AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rank <= 3
                                    ? accent.withValues(alpha: 0.16)
                                    : AppColors.background,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                  color: rank <= 3 ? accent : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  color: rank <= 3
                                      ? accent
                                      : AppColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '@${entry.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.letterboxdBlue
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.zero,
                                        border: Border.all(
                                          color: AppColors.letterboxdBlue,
                                        ),
                                      ),
                                      child: const Text(
                                        'VOCÊ',
                                        style: TextStyle(
                                          color: AppColors.letterboxdBlue,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  size: 15,
                                  color: rank <= 3
                                      ? accent
                                      : AppColors.trophyYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${entry.highScore}',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
