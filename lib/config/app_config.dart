import 'dart:convert';

/// Versão exibida no app. Deve coincidir com `version:` do pubspec.yaml (há teste).
const String kAppVersion = '0.1.0+1';

/// Configuração injetada em tempo de compilação com `--dart-define`.
///
/// Nunca coloque segredos aqui: tudo que entra no APK pode ser extraído.
/// Apenas a URL pública do Supabase e a chave `anon` (pública por design,
/// protegida por RLS) pertencem ao cliente.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.environment = 'dev',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        environment: String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String environment;

  /// Motivo pelo qual o backend não pode ser usado, ou null se a configuração é válida.
  String? get problem {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return 'O servidor ainda não foi configurado neste aplicativo. '
          'Compile com SUPABASE_URL e SUPABASE_ANON_KEY (veja o README).';
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL é inválida.';
    }
    if (uri.scheme != 'https' && !_isLocalHost(uri.host)) {
      return 'SUPABASE_URL deve usar https.';
    }
    if (looksLikeServiceRoleKey(supabaseAnonKey)) {
      return 'A chave informada é uma chave service_role. Ela nunca deve '
          'estar em um aplicativo: use a chave anon.';
    }
    return null;
  }

  bool get isBackendConfigured => problem == null;

  static bool _isLocalHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

  /// Defesa em profundidade: recusa iniciar se alguém colocar por engano uma
  /// chave JWT com `role: service_role` no cliente.
  static bool looksLikeServiceRoleKey(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final json = jsonDecode(payload);
      return json is Map<String, dynamic> && json['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}

enum BackendState { ready, notConfigured, initFailed }

/// Resultado da inicialização do backend, calculado em main() e injetado via Riverpod.
class BackendStatus {
  const BackendStatus(this.state, [this.detail]);

  const BackendStatus.ready() : this(BackendState.ready);

  final BackendState state;
  final String? detail;

  bool get isReady => state == BackendState.ready;

  String get userMessage {
    switch (state) {
      case BackendState.ready:
        return 'Conectado ao servidor.';
      case BackendState.notConfigured:
        return detail ?? 'O servidor não está configurado.';
      case BackendState.initFailed:
        return 'Não foi possível iniciar a conexão com o servidor. '
            'Verifique sua internet e abra o app novamente.';
    }
  }
}
