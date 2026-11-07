import 'package:flutter/material.dart';
import 'package:my_first_app/domain/models/watched_profile.dart';
import 'package:my_first_app/ui/core/theme/app_theme.dart';
import 'package:my_first_app/ui/core/utils/csv_file_picker.dart';
import 'package:my_first_app/ui/features/game/view_models/game_view_model.dart';
import 'package:my_first_app/ui/features/game/views/widgets/letterboxd_dots.dart';

/// Modal de Conta (Opção 2: `@nick` + Senha/PIN + `watched.csv` salvo na conta).
class AccountDialog extends StatefulWidget {
  const AccountDialog({
    super.key,
    required this.viewModel,
    this.csvFilePicker = pickCsvFile,
  });

  final GameViewModel viewModel;
  final CsvFilePickerCallback csvFilePicker;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  late final TextEditingController _nickController;
  late final TextEditingController _passwordController;
  bool _isLoginMode = false;
  String? _pickedFileName;
  WatchedCsvMatchResult? _resolvedCsvResult;
  String? _errorMessage;
  bool _isBusy = false;
  int _lookupCompleted = 0;
  int _lookupTotal = 0;

  @override
  void initState() {
    super.initState();
    final existingNick =
        widget.viewModel.currentAccount?.username ??
        widget.viewModel.watchedProfile?.username ??
        '';
    _nickController = TextEditingController(text: existingNick);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nickController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleSubmit() async {
    final nick = _nickController.text.trim();
    final password = _passwordController.text.trim();
    final activeAccount = widget.viewModel.currentAccount;

    setState(() {
      _errorMessage = null;
      _isBusy = true;
    });

    try {
      if (activeAccount != null) {
        final resolved = _resolvedCsvResult;
        if (resolved == null) {
          throw const FormatException(
            'Selecione um novo arquivo watched.csv para atualizar os filmes da sua conta.',
          );
        }
        await widget.viewModel.applyResolvedWatchedCsv(
          username: activeAccount.username,
          resolvedResult: resolved,
        );
      } else if (_isLoginMode) {
        await widget.viewModel.loginAccount(
          username: nick,
          password: password,
        );
      } else {
        await widget.viewModel.registerAccountWithCsv(
          username: nick,
          password: password,
          resolvedResult: _resolvedCsvResult,
        );
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
        _errorMessage = 'Erro ao processar conta: $e';
        _isBusy = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await widget.viewModel.logoutAccount();
    if (!mounted) return;
    setState(() {
      _passwordController.clear();
      _pickedFileName = null;
      _resolvedCsvResult = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAccount = widget.viewModel.currentAccount;
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
                        'CONTA DO JOGADOR',
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
                        key: const Key('btn_close_account_dialog'),
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
                if (activeAccount != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 18,
                              color: AppColors.letterboxdBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Conectado como @${activeAccount.username}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              key: const Key('btn_logout_account'),
                              onPressed: _isBusy ? null : _handleLogout,
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
                                'Sair',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• ${activeAccount.watchedMovieIds.length} filmes assistidos salvos na conta\n• Recorde da conta: ${activeAccount.highScore}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ATUALIZAR WATCHED.CSV DA CONTA',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildCsvPickerSection(resolved),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('btn_submit_account'),
                    onPressed: _isBusy ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.letterboxdBlue,
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
                          : 'ATUALIZAR FILMES DA CONTA',
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          buttonKey: const Key('tab_register_account'),
                          label: 'Criar Conta',
                          selected: !_isLoginMode,
                          onTap: _isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _isLoginMode = false;
                                    _errorMessage = null;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TabButton(
                          buttonKey: const Key('tab_login_account'),
                          label: 'Entrar',
                          selected: _isLoginMode,
                          onTap: _isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _isLoginMode = true;
                                    _errorMessage = null;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SEU USERNAME',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input_account_nick'),
                    controller: _nickController,
                    enabled: !_isBusy,
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
                        color: AppColors.letterboxdBlue,
                        fontWeight: FontWeight.w800,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
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
                          color: AppColors.letterboxdBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SENHA OU PIN',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input_account_password'),
                    controller: _passwordController,
                    enabled: !_isBusy,
                    obscureText: true,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Mínimo de 3 caracteres',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
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
                          color: AppColors.letterboxdBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'ARQUIVO WATCHED.CSV (OPCIONAL)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCsvPickerSection(resolved),
                  ] else ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Ao entrar, seu recorde e seus filmes do watched.csv (se enviados) serão carregados automaticamente.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
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
                    key: const Key('btn_submit_account'),
                    onPressed: _isBusy ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.letterboxdBlue,
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
                          ? 'PROCESSANDO...'
                          : (_isLoginMode
                                ? 'ENTRAR NA CONTA'
                                : (resolved != null
                                      ? 'CRIAR CONTA E SALVAR FILMES'
                                      : 'CRIAR CONTA')),
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

  Widget _buildCsvPickerSection(WatchedCsvMatchResult? resolved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('btn_account_pick_csv'),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  color: AppColors.letterboxdBlue,
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
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.letterboxdBlue.withValues(alpha: 0.18)
          : AppColors.surfaceElevated,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: selected ? AppColors.letterboxdBlue : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? AppColors.letterboxdBlue
                  : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
