import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/auth/domain/otp_throttle.dart';

void main() {
  late DateTime now;
  late OtpThrottle throttle;

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    throttle = OtpThrottle(clock: () => now);
  });

  test('antes de qualquer envio já é possível pedir um código', () {
    expect(throttle.canResend, isTrue);
    expect(throttle.resendWait, Duration.zero);
  });

  test('após enviar, o reenvio só libera depois de 60 segundos', () {
    throttle.recordCodeSent();
    expect(throttle.canResend, isFalse);
    expect(throttle.resendWait, const Duration(seconds: 60));

    now = now.add(const Duration(seconds: 59));
    expect(throttle.canResend, isFalse);

    now = now.add(const Duration(seconds: 1));
    expect(throttle.canResend, isTrue);
  });

  test('cinco tentativas incorretas travam a verificação até pedir novo código', () {
    for (var i = 0; i < 5; i++) {
      expect(throttle.canVerify, isTrue);
      throttle.recordFailedVerify();
    }
    expect(throttle.canVerify, isFalse);
    expect(throttle.remainingAttempts, 0);

    throttle.recordCodeSent();
    expect(throttle.canVerify, isTrue);
    expect(throttle.remainingAttempts, 5);
  });

  test('limite por hora bloqueia mesmo após o intervalo curto', () {
    for (var i = 0; i < 5; i++) {
      throttle.recordCodeSent();
      now = now.add(const Duration(seconds: 61));
    }
    expect(throttle.hitWindowLimit, isTrue);
    expect(throttle.canResend, isFalse);
    expect(throttle.resendWait, greaterThan(const Duration(minutes: 50)));

    now = now.add(const Duration(hours: 1));
    expect(throttle.canResend, isTrue);
    expect(throttle.hitWindowLimit, isFalse);
  });
}
