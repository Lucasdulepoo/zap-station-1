/// Controle de tentativas de OTP no cliente.
///
/// Isto melhora a experiência e reduz abuso acidental, mas NÃO é a defesa real:
/// os limites autoritativos ficam no servidor (Supabase Auth rate limits +
/// provedor de SMS). Veja docs/EXTERNAL_SETUP.md.
class OtpThrottle {
  OtpThrottle({
    this.maxVerifyAttempts = 5,
    this.resendCooldown = const Duration(seconds: 60),
    this.maxSendsPerWindow = 5,
    this.sendWindow = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxVerifyAttempts;
  final Duration resendCooldown;
  final int maxSendsPerWindow;
  final Duration sendWindow;
  final DateTime Function() _clock;

  final List<DateTime> _sends = [];
  int _failedAttempts = 0;

  int get remainingAttempts => (maxVerifyAttempts - _failedAttempts).clamp(0, maxVerifyAttempts);

  /// Depois de esgotar as tentativas, é preciso solicitar um novo código.
  bool get canVerify => remainingAttempts > 0;

  void recordFailedVerify() => _failedAttempts++;

  /// Registra um envio de código confirmado pelo servidor e zera as tentativas de verificação.
  void recordCodeSent() {
    _prune();
    _sends.add(_clock());
    _failedAttempts = 0;
  }

  /// Tempo restante até poder pedir novo código (Duration.zero se já pode).
  Duration get resendWait {
    _prune();
    final now = _clock();
    var wait = Duration.zero;

    if (_sends.isNotEmpty) {
      final cooldownEnd = _sends.last.add(resendCooldown);
      if (cooldownEnd.isAfter(now)) wait = cooldownEnd.difference(now);
    }

    if (_sends.length >= maxSendsPerWindow) {
      final windowEnd = _sends.first.add(sendWindow);
      final windowWait = windowEnd.difference(now);
      if (windowWait > wait) wait = windowWait;
    }

    return wait;
  }

  bool get canResend => resendWait == Duration.zero;

  /// Verdadeiro quando o limite por janela (e não o intervalo curto) é o que bloqueia.
  bool get hitWindowLimit {
    _prune();
    return _sends.length >= maxSendsPerWindow;
  }

  void _prune() {
    final cutoff = _clock().subtract(sendWindow);
    _sends.removeWhere((t) => !t.isAfter(cutoff));
  }
}
