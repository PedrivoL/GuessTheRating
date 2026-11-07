import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_app/domain/models/user_account.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Modal de Catálogo: permite alternar entre o Catálogo Geral e o Meu Catálogo,
/// buscar o catálogo de qualquer `username` e copiar o link direto da página
/// `guesstherating.web.app/username`.
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
  late final TextEditingController _usernameController;
  String? _errorMessage;
  bool _isBusy = false;
  bool _copiedLink = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.viewModel.watchedProfile?.username ??
          widget.viewModel.currentAccount?.username ??
          '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String _resolveShareUsername() {
    final typed = UserAccount.normalizeUsername(_usernameController.text);
    if (typed.isNotEmpty) return typed;
    final fromProfile = widget.viewModel.watchedProfile?.username;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final fromAccount = widget.viewModel.currentAccount?.username;
    if (fromAccount != null && fromAccount.isNotEmpty) return fromAccount;
    return 'username';
  }

  Future<void> _handleCopyShareLink() async {
    final targetUsername = _resolveShareUsername();
    final url = 'https://guesstherating.web.app/$targetUsername';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() {
      _copiedLink = true;
    });
  }

  Future<void> _handleLoadUsernameCatalog() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Digite o username de quem você quer usar o catálogo.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      await widget.viewModel.loadPoolByNick(username);
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
        _errorMessage = 'Erro ao carregar catálogo: $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _handleSelectGeneralCatalog() async {
    await widget.viewModel.setWatchedPoolActive(false);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSelectOwnCatalog() async {
    final accountHasMovies =
        (widget.viewModel.currentAccount?.watchedMovieIds.length ?? 0) >= 2;
    final profileHasMovies =
        (widget.viewModel.watchedProfile?.watchedMovieIds.length ?? 0) >= 2;
    final hasOwn = accountHasMovies || profileHasMovies;
    if (!hasOwn) {
      setState(() {
        _errorMessage =
            'Nenhum catálogo próprio salvo ainda. Busque um username abaixo ou envie seu watched.csv no botão Conta.';
      });
      return;
    }
    await widget.viewModel.activateOwnCatalog();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleClearProfile() async {
    await widget.viewModel.clearWatchedProfile();
    if (!mounted) return;
    setState(() {
      _usernameController.clear();
      _errorMessage = null;
      _copiedLink = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final existingProfile = widget.viewModel.watchedProfile;
    final currentAccount = widget.viewModel.currentAccount;
    final isUsingWatched = widget.viewModel.isUsingWatchedPool;

    final ownUsername = currentAccount?.username ?? existingProfile?.username;
    final ownCount = (currentAccount != null &&
            currentAccount.watchedMovieIds.length >= 2)
        ? currentAccount.watchedMovieIds.length
        : existingProfile?.watchedMovieIds.length;
    final isOwnCatalogActive = isUsingWatched &&
        existingProfile != null &&
        (currentAccount == null ||
            existingProfile.username == currentAccount.username);
    final shareUsername = _resolveShareUsername();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
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
                        'CATÁLOGO',
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
                const Text(
                  'ESCOLHER CATÁLOGO ATIVO',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChoiceButton(
                        buttonKey: const Key('btn_mode_general'),
                        icon: Icons.public_rounded,
                        label: 'Catálogo Geral',
                        subtitle: 'Filmes do Letterboxd',
                        selected: !isUsingWatched,
                        accentColor: AppColors.letterboxdBlue,
                        onTap: _isBusy ? null : _handleSelectGeneralCatalog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeChoiceButton(
                        buttonKey: const Key('btn_mode_watched'),
                        icon: Icons.person_rounded,
                        label: 'Meu Catálogo',
                        subtitle: ownUsername != null
                            ? '@$ownUsername (${ownCount ?? 0} filmes)'
                            : 'Não conectado',
                        selected: isOwnCatalogActive,
                        accentColor: AppColors.letterboxdGreen,
                        onTap: _isBusy ? null : _handleSelectOwnCatalog,
                      ),
                    ),
                  ],
                ),
                if (existingProfile != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: isUsingWatched
                            ? AppColors.letterboxdGreen
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUsingWatched
                              ? Icons.check_circle_rounded
                              : Icons.folder_special_rounded,
                          size: 16,
                          color: isUsingWatched
                              ? AppColors.letterboxdGreen
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            isUsingWatched
                                ? 'Jogando com: @${existingProfile.username} (${existingProfile.watchedMovieIds.length} filmes)'
                                : 'Salvo: @${existingProfile.username} (${existingProfile.watchedMovieIds.length} filmes)',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: AppColors.letterboxdGreen,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Buscar username',
                            key: Key('tab_explore_nick'),
                            style: TextStyle(
                              color: AppColors.letterboxdGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'USERNAME DO JOGADOR',
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
                        controller: _usernameController,
                        enabled: !_isBusy,
                        onChanged: (_) {
                          setState(() {
                            _copiedLink = false;
                          });
                        },
                        onSubmitted: (_) {
                          if (!_isBusy) _handleLoadUsernameCatalog();
                        },
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ex: pedrivol',
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          prefixText: '@',
                          prefixStyle: TextStyle(
                            color: AppColors.letterboxdGreen,
                            fontWeight: FontWeight.w800,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: AppColors.letterboxdGreen,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ENDEREÇO DA PÁGINA DO CATÁLOGO',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'guesstherating.web.app/$shareUsername',
                                key: const Key('text_share_catalog_url'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.letterboxdGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: _copiedLink
                                ? AppColors.letterboxdGreen
                                : AppColors.surface,
                            child: InkWell(
                              key: const Key('btn_copy_catalog_link'),
                              onTap: _handleCopyShareLink,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.zero,
                                  border: Border.all(
                                    color: AppColors.letterboxdGreen,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _copiedLink
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                      size: 14,
                                      color: _copiedLink
                                          ? Colors.black
                                          : AppColors.letterboxdGreen,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _copiedLink ? 'COPIADO!' : 'COPIAR LINK',
                                      style: TextStyle(
                                        color: _copiedLink
                                            ? Colors.black
                                            : AppColors.letterboxdGreen,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        key: const Key('btn_apply_profile'),
                        onPressed: _isBusy ? null : _handleLoadUsernameCatalog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.letterboxdGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        child: Text(
                          _isBusy
                              ? 'CARREGANDO CATÁLOGO...'
                              : 'CARREGAR CATÁLOGO DO USERNAME',
                        ),
                      ),
                    ],
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
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accentColor.withValues(alpha: 0.16)
          : AppColors.surfaceElevated,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: selected ? accentColor : AppColors.border,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected ? accentColor : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? accentColor : AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
