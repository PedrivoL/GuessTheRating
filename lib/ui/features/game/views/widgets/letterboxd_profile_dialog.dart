import 'package:flutter/material.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Modal para o jogador inserir seu nick do Letterboxd e importar seu `watched.csv` uma única vez,
/// carregando imediatamente quaisquer filmes que não estejam no `movies.json` local.
class LetterboxdProfileDialog extends StatefulWidget {
  const LetterboxdProfileDialog({
    super.key,
    required this.viewModel,
    this.csvFilePicker = pickCsvFile,
  });

  final GameViewModel viewModel;
  final CsvFilePickerCallback csvFilePicker;

  @override
  State<LetterboxdProfileDialog> createState() =>
      _LetterboxdProfileDialogState();
}

class _LetterboxdProfileDialogState extends State<LetterboxdProfileDialog> {
  late final TextEditingController _nickController;
  String? _pickedFileName;
  WatchedCsvMatchResult? _resolvedCsvResult;
  String? _errorMessage;
  bool _isBusy = false;
  int _lookupCompleted = 0;
  int _lookupTotal = 0;

  @override
  void initState() {
    super.initState();
    _nickController = TextEditingController(
      text: widget.viewModel.watchedProfile?.username ?? '',
    );
  }

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  Future<void> _handlePickCsv() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final picked = await widget.csvFilePicker();
      if (!mounted || picked == null) return;

      setState(() {
        _pickedFileName = picked.name;
        _resolvedCsvResult = null;
        _isBusy = true;
        _lookupCompleted = 0;
        _lookupTotal = 0;
      });

      final resolved = await widget.viewModel.resolveWatchedCsv(
        picked.content,
        onLookupProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _lookupCompleted = completed;
            _lookupTotal = total;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _resolvedCsvResult = resolved;
        _isBusy = false;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível ler o arquivo selecionado: $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _handleSaveAndPlay() async {
    final nick = _nickController.text.trim();
    final resolved = _resolvedCsvResult;
    final existingProfile = widget.viewModel.watchedProfile;

    if (resolved == null && existingProfile == null && nick.isEmpty) {
      setState(() {
        _errorMessage =
            'Digite um @nick já cadastrado ou selecione o arquivo watched.csv.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      if (resolved != null) {
        await widget.viewModel.applyResolvedWatchedCsv(
          username: nick.isEmpty
              ? (existingProfile?.username ?? 'voce')
              : nick,
          resolvedResult: resolved,
        );
      } else if (nick.isNotEmpty) {
        await widget.viewModel.loadPoolByNick(nick);
      } else if (existingProfile != null) {
        await widget.viewModel.setWatchedPoolActive(true);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erro ao salvar perfil: $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _handleSwitchMode(bool useWatchedPool) async {
    await widget.viewModel.setWatchedPoolActive(useWatchedPool);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleClearProfile() async {
    await widget.viewModel.clearWatchedProfile();
    if (!mounted) return;
    setState(() {
      _pickedFileName = null;
      _resolvedCsvResult = null;
      _nickController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final existingProfile = widget.viewModel.watchedProfile;
    final isUsingWatched = widget.viewModel.isUsingWatchedPool;
    final resolved = _resolvedCsvResult;

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
          child: SingleChildScrollView(
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
                        'FILMES DO JOGADOR',
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
                        key: const Key('btn_close_profile_dialog'),
                        onTap: _isBusy
                            ? null
                            : () => Navigator.of(context).pop(),
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
                if (existingProfile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: isUsingWatched
                            ? AppColors.letterboxdGreen
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: AppColors.letterboxdGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Perfil salvo: @${existingProfile.username}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              key: const Key('btn_clear_profile'),
                              onPressed: _isBusy ? null : _handleClearProfile,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.errorRed,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              child: const Text(
                                'Remover',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${existingProfile.watchedMovieIds.length} filmes disponíveis na sua pool (${existingProfile.totalCsvCount} no watched.csv).',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _ModeChoiceButton(
                                buttonKey: const Key('btn_mode_watched'),
                                label: 'Meus Filmes',
                                selected: isUsingWatched,
                                onTap: () => _handleSwitchMode(true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ModeChoiceButton(
                                buttonKey: const Key('btn_mode_general'),
                                label: 'Catálogo Geral',
                                selected: !isUsingWatched,
                                onTap: () => _handleSwitchMode(false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'SEU NICK NO LETTERBOXD',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('input_letterboxd_nick'),
                  controller: _nickController,
                  enabled: !_isBusy,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: pedrivol',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixText: '@',
                    prefixStyle: const TextStyle(
                      color: AppColors.letterboxdGreen,
                      fontWeight: FontWeight.w800,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    disabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                        color: AppColors.letterboxdGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ARQUIVO WATCHED.CSV (SÓ PRECISA IMPORTAR 1 VEZ)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  key: const Key('btn_pick_watched_csv'),
                  onPressed: _isBusy ? null : _handlePickCsv,
                  icon: Icon(
                    _pickedFileName != null
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_rounded,
                    size: 18,
                    color: _pickedFileName != null
                        ? AppColors.letterboxdGreen
                        : AppColors.letterboxdBlue,
                  ),
                  label: Text(
                    _pickedFileName != null
                        ? 'Selecionado: $_pickedFileName'
                        : 'Selecionar arquivo watched.csv',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: _pickedFileName != null
                          ? AppColors.letterboxdGreen
                          : AppColors.border,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                if (_isBusy && _lookupTotal > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.letterboxdBlue),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carregando filmes fora do catálogo ($_lookupCompleted/$_lookupTotal)...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _lookupCompleted / _lookupTotal,
                          minHeight: 5,
                          backgroundColor: AppColors.background,
                          color: AppColors.letterboxdGreen,
                        ),
                      ],
                    ),
                  ),
                ] else if (resolved != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.letterboxdGreen),
                    ),
                    child: Text(
                      '✓ ${resolved.matchedMovies.length} filmes carregados do seu watched.csv',
                      style: const TextStyle(
                        color: AppColors.letterboxdGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'No Letterboxd, acesse Settings → Data → Export Your Data e selecione o arquivo watched.csv.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
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
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  key: const Key('btn_apply_profile'),
                  onPressed: _isBusy ? null : _handleSaveAndPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.letterboxdGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: Text(
                    _isBusy
                        ? 'CARREGANDO FILMES...'
                        : (resolved != null
                              ? 'SALVAR E JOGAR COM MEUS FILMES'
                              : (existingProfile != null
                                    ? 'ATUALIZAR NICK E USAR MEUS FILMES'
                                    : 'SALVAR E JOGAR')),
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

class _ModeChoiceButton extends StatelessWidget {
  const _ModeChoiceButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.letterboxdGreen.withValues(alpha: 0.18)
          : AppColors.surface,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: selected ? AppColors.letterboxdGreen : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.letterboxdGreen
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
