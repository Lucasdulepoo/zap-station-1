import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/zap_avatar.dart';
import '../../core/widgets/zap_button.dart';
import '../../core/widgets/zap_feedback.dart';
import '../../core/widgets/zap_text_field.dart';
import '../../profiles/domain/profile.dart';
import '../application/providers.dart';
import '../application/session_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _fieldError; // validação local do nome
  String? _serverError; // falha ao salvar / sair
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = Profile.validateDisplayName(_controller.text);
    if (problem != null) {
      setState(() => _fieldError = problem);
      return;
    }

    setState(() {
      _saving = true;
      _fieldError = null;
      _serverError = null;
    });

    try {
      await ref.read(profileRepositoryProvider).saveDisplayName(_controller.text);
      await ref.read(sessionProvider.notifier).refresh();
      // O roteador leva para as conversas quando o perfil fica completo.
      if (mounted) setState(() => _saving = false);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = AppFailure.unknown.message;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      await ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _serverError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, __) => ZapAvatar(name: value.text, radius: 48),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Foto de perfil: disponível na Fase 5',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Como podemos te chamar?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esse nome aparece para as pessoas com quem você conversa.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ZapTextField(
                controller: _controller,
                label: 'Seu nome',
                errorText: _fieldError,
                maxLength: 60,
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
                onChanged: (_) {
                  if (_fieldError != null) setState(() => _fieldError = null);
                },
                onSubmitted: (_) => _save(),
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 16),
                ZapBanner(message: _serverError!),
              ],
              const SizedBox(height: 24),
              ZapButton(label: 'Continuar', loading: _saving, onPressed: _save),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _signOut,
                child: const Text('Usar outro número'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
