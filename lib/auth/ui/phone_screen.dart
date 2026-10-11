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
import '../domain/phone_number.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final TextEditingController _controller = TextEditingController();
  Country _country = kBrazil;
  String? _fieldError;
  String? _serverError;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CountrySheet(selected: _country),
    );
    if (picked != null && mounted) {
      setState(() {
        _country = picked;
        _fieldError = null;
      });
    }
  }

  Future<void> _submit() async {
    final result = PhoneNumber.parse(_country, _controller.text);
    if (!result.isValid) {
      setState(() {
        _fieldError = result.error;
        _serverError = null;
      });
      return;
    }
    final number = result.number!;

    final throttle = ref.read(otpThrottleProvider);
    if (!throttle.canResend) {
      final seconds = throttle.resendWait.inSeconds + 1;
      setState(() {
        _fieldError = null;
        _serverError = throttle.hitWindowLimit
            ? 'Você atingiu o limite de códigos por hora. Tente mais tarde.'
            : 'Aguarde $seconds s para solicitar outro código.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _fieldError = null;
      _serverError = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestOtp(number.e164);
      // Só registra o envio depois que o servidor confirmou o pedido.
      throttle.recordCodeSent();
      if (!mounted) return;
      setState(() => _loading = false);
      context.push(Routes.otp, extra: number);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _serverError = AppFailure.unknown.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: ZapLogo(size: 24)),
              const SizedBox(height: 40),
              Text(
                'Seu número de telefone',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vamos enviar um código por SMS para confirmar que o número é seu.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (!backend.isReady) ...[
                ZapBanner(message: backend.userMessage, kind: ZapBannerKind.warning),
                const SizedBox(height: 16),
              ],
              OutlinedButton(
                onPressed: _loading ? null : _pickCountry,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_country.name, overflow: TextOverflow.ellipsis)),
                    Text(
                      '+${_country.dialCode}',
                      style: const TextStyle(color: AppColors.accent),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ZapTextField(
                controller: _controller,
                label: 'Telefone',
                hint: _country.isoCode == 'BR' ? '(11) 98765-4321' : 'Número de telefone',
                errorText: _fieldError,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]'))],
                onChanged: (_) {
                  if (_fieldError != null) setState(() => _fieldError = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 16),
                ZapBanner(message: _serverError!),
              ],
              const SizedBox(height: 24),
              ZapButton(label: 'Enviar código', loading: _loading, onPressed: _submit),
              const SizedBox(height: 16),
              const Text(
                'Podem ser cobradas tarifas da sua operadora pelo SMS.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final Country selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = kCountries
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.dialCode.contains(q))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ZapTextField(
                  label: 'Buscar país',
                  prefix: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum país encontrado.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final c = items[i];
                          return ListTile(
                            leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                            title: Text(c.name),
                            trailing: Text(
                              '+${c.dialCode}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                            selected: c == widget.selected,
                            selectedColor: AppColors.accent,
                            onTap: () => Navigator.of(context).pop(c),
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
