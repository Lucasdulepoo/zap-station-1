import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';

/// Autenticação por telefone. A verificação do código é SEMPRE feita pelo servidor;
/// nenhuma implementação deste contrato pode considerar um número verificado sem
/// a confirmação do provedor.
abstract interface class AuthRepository {
  /// Falso quando o backend não está configurado/iniciado.
  bool get isAvailable;

  bool get isSignedIn;

  String? get currentUserId;

  /// Telefone do usuário autenticado (vem do Supabase Auth, nunca do cliente).
  String? get currentPhone;

  Stream<bool> get signedInChanges;

  Future<void> requestOtp(String e164Phone);

  Future<void> verifyOtp({required String e164Phone, required String code});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentPhone => _client.auth.currentUser?.phone;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null).distinct();

  @override
  Future<void> requestOtp(String e164Phone) async {
    try {
      await _client.auth.signInWithOtp(phone: e164Phone, shouldCreateUser: true);
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw _mapOther(e);
    }
  }

  @override
  Future<void> verifyOtp({required String e164Phone, required String code}) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: e164Phone,
        token: code,
        type: OtpType.sms,
      );
      if (response.session == null) {
        // Sem sessão emitida pelo servidor = não verificado.
        throw const AppFailure(
          FailureKind.invalidCode,
          'Não foi possível confirmar o código. Tente novamente.',
        );
      }
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw _mapOther(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw _mapOther(e);
    }
  }

  AppFailure _mapAuthException(AuthException e) {
    final message = e.message.toLowerCase();
    if (e.statusCode == '429' || message.contains('rate limit') || message.contains('too many')) {
      return const AppFailure(
        FailureKind.rateLimited,
        'Muitas tentativas. Aguarde alguns minutos antes de tentar de novo.',
      );
    }
    if (message.contains('expired')) {
      return const AppFailure(
        FailureKind.expiredCode,
        'O código expirou. Solicite um novo código.',
      );
    }
    if (message.contains('invalid') && message.contains('phone')) {
      return const AppFailure(FailureKind.invalidInput, 'Número de telefone inválido.');
    }
    if (message.contains('invalid') || message.contains('token')) {
      return const AppFailure(
        FailureKind.invalidCode,
        'Código incorreto. Confira os dígitos e tente de novo.',
      );
    }
    if (message.contains('sms') || message.contains('provider')) {
      return const AppFailure(
        FailureKind.unknown,
        'Não foi possível enviar o SMS agora. Tente novamente mais tarde.',
      );
    }
    return AppFailure.unknown;
  }

  AppFailure _mapOther(Object e) {
    if (e is SocketException || e is TimeoutException) return AppFailure.network;
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return AppFailure.network;
    }
    return AppFailure.unknown;
  }
}

/// Usada quando o backend não foi configurado ou falhou ao iniciar.
/// Todas as operações falham de forma explícita: nada é simulado.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository(this.reason);

  final String reason;

  AppFailure get _failure => AppFailure(FailureKind.notConfigured, reason);

  @override
  bool get isAvailable => false;

  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserId => null;

  @override
  String? get currentPhone => null;

  @override
  Stream<bool> get signedInChanges => const Stream<bool>.empty();

  @override
  Future<void> requestOtp(String e164Phone) => Future<void>.error(_failure);

  @override
  Future<void> verifyOtp({required String e164Phone, required String code}) =>
      Future<void>.error(_failure);

  @override
  Future<void> signOut() async {}
}
