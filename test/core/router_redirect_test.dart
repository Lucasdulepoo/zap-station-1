import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/auth/application/session_controller.dart';
import 'package:zap_station/core/router/app_router.dart';
import 'package:zap_station/core/utils/time_format.dart';

void main() {
  group('resolveRedirect', () {
    test('inicializando: tudo vai para a splash', () {
      expect(resolveRedirect(SessionStatus.initializing, Routes.conversations), Routes.splash);
      expect(resolveRedirect(SessionStatus.initializing, Routes.splash), isNull);
    });

    test('sem sessão: só o fluxo de telefone/OTP é acessível', () {
      expect(resolveRedirect(SessionStatus.signedOut, Routes.splash), Routes.phone);
      expect(resolveRedirect(SessionStatus.signedOut, Routes.conversations), Routes.phone);
      expect(resolveRedirect(SessionStatus.signedOut, Routes.profile), Routes.phone);
      expect(resolveRedirect(SessionStatus.signedOut, Routes.phone), isNull);
      expect(resolveRedirect(SessionStatus.signedOut, Routes.otp), isNull);
    });

    test('perfil incompleto: obriga a completar o perfil', () {
      expect(resolveRedirect(SessionStatus.needsProfile, Routes.conversations), Routes.profile);
      expect(resolveRedirect(SessionStatus.needsProfile, Routes.otp), Routes.profile);
      expect(resolveRedirect(SessionStatus.needsProfile, Routes.profile), isNull);
    });

    test('pronto: sai de splash/auth e fica na área logada', () {
      expect(resolveRedirect(SessionStatus.ready, Routes.splash), Routes.conversations);
      expect(resolveRedirect(SessionStatus.ready, Routes.phone), Routes.conversations);
      expect(resolveRedirect(SessionStatus.ready, Routes.profile), Routes.conversations);
      expect(resolveRedirect(SessionStatus.ready, Routes.settings), isNull);
    });
  });

  group('formatActivityTime', () {
    final now = DateTime(2026, 10, 10, 15, 30);

    test('hoje mostra HH:mm', () {
      expect(formatActivityTime(DateTime(2026, 10, 10, 9, 5), now), '09:05');
    });

    test('ontem mostra "Ontem"', () {
      expect(formatActivityTime(DateTime(2026, 10, 9, 23, 59), now), 'Ontem');
    });

    test('antes disso mostra dd/MM', () {
      expect(formatActivityTime(DateTime(2026, 10, 1, 8), now), '01/10');
    });
  });
}
