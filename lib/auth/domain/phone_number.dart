/// País para seleção de DDI. Lista inicial; pode crescer sem mudar a validação.
class Country {
  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
    this.stripLeadingZero = false,
  });

  final String isoCode;
  final String name;

  /// DDI sem o "+".
  final String dialCode;

  /// Países em que o prefixo de tronco "0" é digitado no número nacional mas
  /// não faz parte do formato internacional (ex.: Brasil 011, Reino Unido 07...).
  final bool stripLeadingZero;

  /// Bandeira em emoji a partir do código ISO (letras indicadoras regionais).
  String get flag => String.fromCharCodes(
        isoCode.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
      );

  @override
  bool operator ==(Object other) => other is Country && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;
}

const Country kBrazil = Country(isoCode: 'BR', name: 'Brasil', dialCode: '55', stripLeadingZero: true);

const List<Country> kCountries = [
  kBrazil,
  Country(isoCode: 'PT', name: 'Portugal', dialCode: '351'),
  Country(isoCode: 'US', name: 'Estados Unidos', dialCode: '1'),
  Country(isoCode: 'CA', name: 'Canadá', dialCode: '1'),
  Country(isoCode: 'AR', name: 'Argentina', dialCode: '54'),
  Country(isoCode: 'CL', name: 'Chile', dialCode: '56'),
  Country(isoCode: 'CO', name: 'Colômbia', dialCode: '57'),
  Country(isoCode: 'MX', name: 'México', dialCode: '52'),
  Country(isoCode: 'PY', name: 'Paraguai', dialCode: '595'),
  Country(isoCode: 'UY', name: 'Uruguai', dialCode: '598'),
  Country(isoCode: 'ES', name: 'Espanha', dialCode: '34'),
  Country(isoCode: 'FR', name: 'França', dialCode: '33', stripLeadingZero: true),
  Country(isoCode: 'DE', name: 'Alemanha', dialCode: '49', stripLeadingZero: true),
  Country(isoCode: 'IT', name: 'Itália', dialCode: '39'),
  Country(isoCode: 'GB', name: 'Reino Unido', dialCode: '44', stripLeadingZero: true),
  Country(isoCode: 'AO', name: 'Angola', dialCode: '244'),
  Country(isoCode: 'MZ', name: 'Moçambique', dialCode: '258'),
  Country(isoCode: 'JP', name: 'Japão', dialCode: '81', stripLeadingZero: true),
  Country(isoCode: 'IN', name: 'Índia', dialCode: '91'),
];

/// Número validado e normalizado para E.164.
class PhoneNumber {
  const PhoneNumber._(this.country, this.nationalNumber);

  final Country country;

  /// Somente dígitos, sem DDI e sem prefixo de tronco.
  final String nationalNumber;

  /// Formato aceito pelo Supabase Auth: "+5511987654321".
  String get e164 => '+${country.dialCode}$nationalNumber';

  /// Exibição amigável. Para o Brasil: "+55 (11) 98765-4321".
  String get display {
    if (country.isoCode == 'BR') {
      final ddd = nationalNumber.substring(0, 2);
      final rest = nationalNumber.substring(2);
      final cut = rest.length - 4;
      return '+55 ($ddd) ${rest.substring(0, cut)}-${rest.substring(cut)}';
    }
    return '+${country.dialCode} $nationalNumber';
  }

  /// Versão mascarada para telas e logs: "+55 ••••• 4321".
  String get masked {
    final last = nationalNumber.substring(nationalNumber.length - 4);
    return '+${country.dialCode} ••••• $last';
  }

  /// Valida e normaliza. A confirmação real de que o número existe e pertence ao
  /// usuário é feita pelo provedor de SMS/Supabase; isto só evita requisições inválidas.
  static PhoneParseResult parse(Country country, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const PhoneParseResult.error('Digite o número de telefone.');
    }

    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (trimmed.startsWith('+')) {
      if (!digits.startsWith(country.dialCode)) {
        return PhoneParseResult.error(
          'Esse número não começa com +${country.dialCode}. '
          'Escolha o país correto ou digite só o número local.',
        );
      }
      digits = digits.substring(country.dialCode.length);
    }

    if (country.stripLeadingZero) {
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
    }

    if (digits.isEmpty) {
      return const PhoneParseResult.error('Digite o número de telefone.');
    }

    if (country.dialCode.length + digits.length > 15) {
      return const PhoneParseResult.error('Número longo demais. Confira os dígitos.');
    }

    final String? problem = switch (country.isoCode) {
      'BR' => _validateBrazil(digits),
      'US' || 'CA' => _validateNanp(digits),
      _ => digits.length < 6 ? 'Número curto demais. Confira os dígitos.' : null,
    };

    if (problem != null) return PhoneParseResult.error(problem);
    return PhoneParseResult.ok(PhoneNumber._(country, digits));
  }

  static String? _validateBrazil(String digits) {
    if (digits.length != 10 && digits.length != 11) {
      return 'Use DDD + número (10 ou 11 dígitos). Exemplo: (11) 98765-4321.';
    }
    // DDD: dois dígitos, nenhum deles zero.
    if (digits[0] == '0' || digits[1] == '0') {
      return 'DDD inválido.';
    }
    // Celular com 11 dígitos: o terceiro dígito é 9.
    if (digits.length == 11 && digits[2] != '9') {
      return 'Celulares brasileiros têm 9 depois do DDD.';
    }
    return null;
  }

  static String? _validateNanp(String digits) {
    if (digits.length != 10) {
      return 'Use 10 dígitos: código de área + número.';
    }
    if (digits[0] == '0' || digits[0] == '1') {
      return 'Código de área inválido.';
    }
    return null;
  }
}

class PhoneParseResult {
  const PhoneParseResult.ok(PhoneNumber this.number) : error = null;
  const PhoneParseResult.error(String this.error) : number = null;

  final PhoneNumber? number;
  final String? error;

  bool get isValid => number != null;
}
