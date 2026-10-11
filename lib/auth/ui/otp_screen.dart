import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_failure.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/zap_button.dart';
import '../../core/widgets/zap_feedback.dart';
import '../../core/widgets/zap_logo.dart';
import '../../core/widgets/zap_text_field.dart';
import '../application/providers.dart';
import '../application/session_controller.dart';
import '../domain/phone_number.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final PhoneNumber phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _codeLength = 6;

  final TextEditingController _controller = TextEditingController();
  Timer? _ticker;
  String? _error;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final throttle = ref.read(otpThrottleProvider);
    final code = _controller.text.trim();

    if (!throttle.canVerify) {
      setState(() => _error = 'Muitas tentativas incorretas. Solicite um novo código.');
      return;
    }
    if (code.length != _codeLength) {
      setState(() => _error = 'Digite os $_codeLength dígitos do código.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      // A verificação é feita pelo servidor; o app só avança se houver sessão emitida.
      await ref.read(authRepositoryProvider).verifyOtp(e164Phone: widget.phone.e164, code: code);
      await ref.read(sessionProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _verifying = false);
      // O redirecionamento para perfil/conversas acontece pelo roteador.
    } on AppFailure catch (e) {
      if (e.kind == FailureKind.invalidCode) throttle.recordFailedVerify();
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = throttle.canVerify || e.kind != FailureKind.invalidCode
            ? e.message
            : 'Muitas tentativas incorretas. Solicite um novo código.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = AppFailure.unknown.message;
      });
    }
  }

  Future<void> _resend() async {
    final throttle = ref.read(otpThrottleProvider);
    if (!throttle.canResend) return;

    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.phone.e164);
      throttle.recordCodeSent();
      if (!mounted) return;
      _controller.clear();
      setState(() => _resending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Novo código solicitado. Aguarde o SMS.')),
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = AppFailure.unknown.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final throttle = ref.watch(otpThrottleProvider);
    final wait = throttle.resendWait;
    final canResend = wait == Duration.zero && !_resending && !_verifying;
    final locked = !throttle.canVerify;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Trocar número',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.phone),
        ),
        title: const ZapLogo(size: 18),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Digite o código',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos um SMS com $_codeLength dígitos para ${widget.phone.masked}.',
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ZapTextField(
                controller: _controller,
                label: 'Código de verificação',
                hint: '000000',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: _codeLength,
                autofocus: true,
                enabled: !_verifying && !locked,
                autofillHints: const [AutofillHints.oneTimeCode],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _verify(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ZapBanner(message: _error!),
              ],
              if (!locked && throttle.remainingAttempts < throttle.maxVerifyAttempts) ...[
                const SizedBox(height: 8),
                Text(
                  'Tentativas restantes: ${throttle.remainingAttempts}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              ZapButton(
                label: 'Verificar',
                loading: _verifying,
                onPressed: locked ? null : _verify,
              ),
              const SizedBox(height: 12),
              ZapButton(
                variant: ZapButtonVariant.secondary,
                loading: _resending,
                label: wait == Duration.zero
                    ? 'Reenviar código'
                    : 'Reenviar em ${wait.inSeconds + 1} s',
                onPressed: canResend ? _resend : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
