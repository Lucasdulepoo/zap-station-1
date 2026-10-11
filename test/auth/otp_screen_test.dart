import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/auth/application/providers.dart';
import 'package:zap_station/auth/application/session_controller.dart';
import 'package:zap_station/auth/domain/phone_number.dart';
import 'package:zap_station/auth/ui/otp_screen.dart';
import 'package:zap_station/config/app_config.dart';
import 'package:zap_station/core/theme/app_theme.dart';

import '../helpers/fakes.dart';

PhoneNumber get _phone => PhoneNumber.parse(kBrazil, '11987654321').number!;

Widget _app(FakeAuthRepository auth, FakeProfileRepository profiles) => ProviderScope(
      overrides: [
        backendStatusProvider.overrideWithValue(const BackendStatus.ready()),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp(theme: ZapTheme.dark, home: OtpScreen(phone: _phone)),
    );

Future<void> _submitCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('Verificar'));
  await tester.pump();
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// Tela alta: evita que botões fiquem fora da viewport padrão de teste (800x600).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('mostra o telefone mascarado, nunca completo', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(FakeAuthRepository(), FakeProfileRepository()));

    expect(find.textContaining('4321'), findsOneWidget);
    expect(find.textContaining('9876'), findsNothing);
    await _teardown(tester);
  });

  testWidgets('código com menos de 6 dígitos não chega ao servidor', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth, FakeProfileRepository()));

    await _submitCode(tester, '123');

    expect(auth.verifiedCodes, isEmpty);
    expect(find.textContaining('6 dígitos'), findsWidgets);
    await _teardown(tester);
  });

  testWidgets('código errado é recusado pelo servidor e a sessão NÃO é aberta', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth, FakeProfileRepository()));

    await _submitCode(tester, '000000');

    expect(auth.verifiedCodes, ['000000']);
    expect(auth.isSignedIn, isFalse);
    expect(find.textContaining('Código incorreto'), findsOneWidget);
    expect(find.text('Tentativas restantes: 4'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('cinco erros travam a verificação até pedir outro código', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth, FakeProfileRepository()));

    for (var i = 0; i < 5; i++) {
      await _submitCode(tester, '00000$i');
    }

    expect(auth.verifiedCodes.length, 5);
    expect(find.textContaining('Muitas tentativas incorretas'), findsWidgets);
    final verify = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Verificar'));
    expect(verify.onPressed, isNull);
    await _teardown(tester);
  });

  testWidgets('código correto abre a sessão e leva ao cadastro do perfil', (tester) async {
    _tall(tester);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth, FakeProfileRepository()));
    final container = ProviderScope.containerOf(tester.element(find.byType(OtpScreen)));

    await _submitCode(tester, '123456');
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.isSignedIn, isTrue);
    expect(container.read(sessionProvider).status, SessionStatus.needsProfile);
    await _teardown(tester);
  });
}
