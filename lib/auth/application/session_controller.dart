import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

enum SessionStatus {
  /// Verificando se há sessão salva e se o perfil está completo.
  initializing,

  /// Sem sessão: mostrar o fluxo de telefone/OTP.
  signedOut,

  /// Autenticado, mas o perfil ainda não tem nome.
  needsProfile,

  /// Autenticado com perfil completo.
  ready,
}

class SessionState {
  const SessionState(this.status, {this.degraded = false});

  final SessionStatus status;

  /// Autenticado, mas não foi possível consultar o servidor (rede indisponível).
  /// O app segue utilizável e mostra um aviso, em vez de travar na abertura.
  final bool degraded;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  static const Duration _profileTimeout = Duration(seconds: 6);

  StreamSubscription<bool>? _subscription;

  @override
  SessionState build() {
    final auth = ref.watch(authRepositoryProvider);
    _subscription = auth.signedInChanges.listen((_) => refresh());
    ref.onDispose(() => _subscription?.cancel());

    // Resolve fora do build para não alterar estado durante a construção.
    scheduleMicrotask(refresh);
    return const SessionState(SessionStatus.initializing);
  }

  /// Reavalia sessão e perfil. Chamado na abertura, após login/logout e após salvar o perfil.
  Future<void> refresh() async {
    final auth = ref.read(authRepositoryProvider);

    if (!auth.isSignedIn) {
      state = const SessionState(SessionStatus.signedOut);
      return;
    }

    try {
      final profile =
          await ref.read(profileRepositoryProvider).fetchMine().timeout(_profileTimeout);
      state = (profile?.hasDisplayName ?? false)
          ? const SessionState(SessionStatus.ready)
          : const SessionState(SessionStatus.needsProfile);
    } catch (_) {
      // Sem rede ou servidor lento: não bloqueia o usuário já autenticado.
      state = const SessionState(SessionStatus.ready, degraded: true);
    }
  }
}
