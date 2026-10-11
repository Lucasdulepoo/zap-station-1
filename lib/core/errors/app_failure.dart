enum FailureKind {
  notConfigured,
  network,
  invalidInput,
  rateLimited,
  invalidCode,
  expiredCode,
  unauthorized,
  unknown,
}

/// Erro de domínio com mensagem já pronta para o usuário (em português).
///
/// Não carrega telefone, token nem conteúdo de mensagens: o toString é seguro para logs.
class AppFailure implements Exception {
  const AppFailure(this.kind, this.message);

  final FailureKind kind;
  final String message;

  static const AppFailure network = AppFailure(
    FailureKind.network,
    'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
  );

  static const AppFailure unknown = AppFailure(
    FailureKind.unknown,
    'Algo deu errado. Tente novamente em instantes.',
  );

  @override
  String toString() => 'AppFailure(${kind.name})';
}
