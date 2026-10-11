import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/config/app_config.dart';

String _jwt(Map<String, Object?> payload) {
  String enc(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.assinatura';
}

void main() {
  test('sem URL/chave o backend é considerado não configurado, com mensagem clara', () {
    const config = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    expect(config.isBackendConfigured, isFalse);
    expect(config.problem, contains('SUPABASE_URL'));
  });

  test('configuração válida com chave anon', () {
    final config = AppConfig(
      supabaseUrl: 'https://abcd.supabase.co',
      supabaseAnonKey: _jwt({'role': 'anon'}),
    );
    expect(config.isBackendConfigured, isTrue);
    expect(config.problem, isNull);
  });

  test('recusa chave service_role no cliente', () {
    final config = AppConfig(
      supabaseUrl: 'https://abcd.supabase.co',
      supabaseAnonKey: _jwt({'role': 'service_role'}),
    );
    expect(config.isBackendConfigured, isFalse);
    expect(config.problem, contains('service_role'));
    expect(AppConfig.looksLikeServiceRoleKey(_jwt({'role': 'anon'})), isFalse);
    expect(AppConfig.looksLikeServiceRoleKey('nao-e-jwt'), isFalse);
  });

  test('exige https, exceto para desenvolvimento local', () {
    final remote = AppConfig(supabaseUrl: 'http://abcd.supabase.co', supabaseAnonKey: _jwt({'role': 'anon'}));
    expect(remote.problem, contains('https'));

    final local = AppConfig(supabaseUrl: 'http://10.0.2.2:54321', supabaseAnonKey: _jwt({'role': 'anon'}));
    expect(local.isBackendConfigured, isTrue);
  });

  test('kAppVersion coincide com a versão do pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(match!.group(1), kAppVersion);
  });

  test('BackendStatus descreve cada estado para o usuário', () {
    expect(const BackendStatus.ready().isReady, isTrue);
    expect(const BackendStatus(BackendState.initFailed).userMessage, contains('internet'));
    expect(const BackendStatus(BackendState.notConfigured, 'motivo').userMessage, 'motivo');
  });
}
