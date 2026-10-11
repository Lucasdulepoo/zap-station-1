import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/core/widgets/zap_avatar.dart';
import 'package:zap_station/profiles/domain/profile.dart';

void main() {
  test('iniciais do avatar', () {
    expect(ZapAvatar.initialsOf('Ana'), 'A');
    expect(ZapAvatar.initialsOf('ana maria souza'), 'AS');
    expect(ZapAvatar.initialsOf('   '), '?');
    expect(ZapAvatar.initialsOf(''), '?');
  });

  test('validação do nome do perfil espelha o CHECK do banco (1..60)', () {
    expect(Profile.validateDisplayName('   '), isNotNull);
    expect(Profile.validateDisplayName('Ana'), isNull);
    expect(Profile.validateDisplayName('a' * 60), isNull);
    expect(Profile.validateDisplayName('a' * 61), isNotNull);
  });
}
