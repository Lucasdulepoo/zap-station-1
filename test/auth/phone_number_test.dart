import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/auth/domain/phone_number.dart';

Country _country(String iso) => kCountries.firstWhere((c) => c.isoCode == iso);

void main() {
  group('Brasil', () {
    test('celular com DDD vira E.164', () {
      final r = PhoneNumber.parse(kBrazil, '(11) 98765-4321');
      expect(r.isValid, isTrue);
      expect(r.number!.e164, '+5511987654321');
      expect(r.number!.display, '+55 (11) 98765-4321');
    });

    test('fixo de 10 dígitos é aceito', () {
      final r = PhoneNumber.parse(kBrazil, '1133334444');
      expect(r.number!.e164, '+551133334444');
    });

    test('remove o zero de tronco antes do DDD', () {
      final r = PhoneNumber.parse(kBrazil, '011987654321');
      expect(r.number!.e164, '+5511987654321');
    });

    test('aceita número já em formato internacional', () {
      final r = PhoneNumber.parse(kBrazil, '+55 11 98765-4321');
      expect(r.number!.e164, '+5511987654321');
    });

    test('rejeita DDI de outro país', () {
      final r = PhoneNumber.parse(kBrazil, '+351 912 345 678');
      expect(r.isValid, isFalse);
      expect(r.error, contains('+55'));
    });

    test('rejeita tamanho errado, DDD com zero e celular sem 9', () {
      expect(PhoneNumber.parse(kBrazil, '987654321').isValid, isFalse);
      expect(PhoneNumber.parse(kBrazil, '0987654321').isValid, isFalse); // vira 987654321 (9 dígitos)
      expect(PhoneNumber.parse(kBrazil, '10987654321').isValid, isFalse); // DDD 10 começa com 1, 0 no segundo
      expect(PhoneNumber.parse(kBrazil, '11887654321').isValid, isFalse); // 11 dígitos sem 9
    });

    test('vazio gera mensagem clara', () {
      final r = PhoneNumber.parse(kBrazil, '   ');
      expect(r.isValid, isFalse);
      expect(r.error, isNotEmpty);
    });

    test('máscara esconde quase todos os dígitos', () {
      final n = PhoneNumber.parse(kBrazil, '11987654321').number!;
      expect(n.masked, '+55 ••••• 4321');
      expect(n.masked.contains('9876'), isFalse);
    });
  });

  group('outros países', () {
    test('EUA/Canadá exigem 10 dígitos e código de área válido', () {
      expect(PhoneNumber.parse(_country('US'), '(415) 555-2671').number!.e164, '+14155552671');
      expect(PhoneNumber.parse(_country('US'), '415555267').isValid, isFalse);
      expect(PhoneNumber.parse(_country('US'), '1155552671').isValid, isFalse);
    });

    test('Portugal usa regra genérica', () {
      expect(PhoneNumber.parse(_country('PT'), '912 345 678').number!.e164, '+351912345678');
      expect(PhoneNumber.parse(_country('PT'), '123').isValid, isFalse);
    });

    test('Reino Unido remove o 0 inicial', () {
      expect(PhoneNumber.parse(_country('GB'), '07911 123456').number!.e164, '+447911123456');
    });

    test('nunca ultrapassa 15 dígitos no total (E.164)', () {
      final r = PhoneNumber.parse(_country('PT'), '1234567890123');
      expect(r.isValid, isFalse);
    });
  });

  test('bandeira em emoji é derivada do código ISO', () {
    expect(kBrazil.flag, '\u{1F1E7}\u{1F1F7}');
  });
}
