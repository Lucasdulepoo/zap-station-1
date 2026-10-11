import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zap_station/auth/application/providers.dart';
import 'package:zap_station/auth/ui/phone_screen.dart';
import 'package:zap_station/config/app_config.dart';
import 'package:zap_station/core/errors/app_failure.dart';
import 'package:zap_station/core/router/app_router.dart';
import 'package:zap_station/core/theme/app_theme.dart';

import '../helpers/fakes.dart';

Widget _app(FakeAuthRepository auth, {BackendStatus backend = const BackendStatus.ready()}) {
  final router = GoRouter(
    initialLocation: Routes.phone,
    routes: [
      GoRoute(path: Routes.phone, builder: (_, __) => const PhoneScreen()),
      GoRoute(path: Routes.otp, builder: (_, __) => const Scaffold(body: Text('TELA-OTP'))),
    ],
  );
  return ProviderScope(
    overrides: [
      backendStatusProvider.overrideWithValue(backend),
      authRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp.router(theme: ZapTheme.dark, routerConfig: router),
  );
}

/// Tela alta: evita que botões fiquem fora da viewport padrão de teste (800x600).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('número inválido mostra erro e NÃO chama o servidor', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth));

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.textContaining('DDD'), findsOneWidget);
    expect(auth.requestedPhones, isEmpty);
    expect(find.text('TELA-OTP'), findsNothing);
  });

  testWidgets('número válido pede o código em E.164 e abre a tela de OTP', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth));

    await tester.enterText(find.byType(TextField), '(11) 98765-4321');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(auth.requestedPhones, ['+5511987654321']);
    expect(find.text('TELA-OTP'), findsOneWidget);
  });

  testWidgets('falha do servidor aparece para o usuário e não avança', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository(
      requestFailure: const AppFailure(FailureKind.rateLimited, 'Muitas tentativas. Aguarde.'),
    );
    await tester.pumpWidget(_app(auth));

    await tester.enterText(find.byType(TextField), '11987654321');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();

    expect(find.text('Muitas tentativas. Aguarde.'), findsOneWidget);
    expect(find.text('TELA-OTP'), findsNothing);
  });

  testWidgets('backend não configurado: avisa e o envio falha de forma explícita', (tester) async {
    _tall(tester);
    const backend = BackendStatus(BackendState.notConfigured, 'Servidor não configurado (teste).');
    await tester.pumpWidget(_app(FakeAuthRepository(), backend: backend));

    expect(find.text('Servidor não configurado (teste).'), findsOneWidget);
  });
}
