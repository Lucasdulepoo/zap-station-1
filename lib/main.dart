import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/application/providers.dart';
import 'config/app_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  // Tudo dentro da mesma zona para capturar erros assíncronos não tratados.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Logs sem dados pessoais: apenas o tipo do erro.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception.runtimeType}');
    };

    try {
      final config = AppConfig.fromEnvironment();
      final backend = await _initBackend(config);

      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(config),
            backendStatusProvider.overrideWithValue(backend),
          ],
          child: const ZapStationApp(),
        ),
      );
    } catch (e) {
      // Último recurso: nunca deixar o usuário com tela preta.
      debugPrint('Falha na inicialização: ${e.runtimeType}');
      runApp(const StartupErrorApp());
    }
  }, (error, stack) {
    debugPrint('Erro não tratado: ${error.runtimeType}');
  });
}

/// Inicializa o Supabase com timeout. Nunca lança: em caso de problema o app abre
/// normalmente e as telas explicam que o servidor não está disponível.
Future<BackendStatus> _initBackend(AppConfig config) async {
  final problem = config.problem;
  if (problem != null) {
    return BackendStatus(BackendState.notConfigured, problem);
  }
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    ).timeout(const Duration(seconds: 8));
    return const BackendStatus.ready();
  } catch (e) {
    debugPrint('Falha ao iniciar o backend: ${e.runtimeType}');
    return const BackendStatus(BackendState.initFailed);
  }
}

/// Tela mostrada se a construção do app falhar na partida.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ZapTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Não foi possível iniciar o ZAP STATION. Feche e abra o aplicativo novamente.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
