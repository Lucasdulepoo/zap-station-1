import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';
import '../domain/profile.dart';

abstract interface class ProfileRepository {
  /// Perfil do usuário autenticado, ou null se não existir/estiver sem sessão.
  Future<Profile?> fetchMine();

  Future<Profile> saveDisplayName(String name);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _columns = 'id, display_name, avatar_path';

  @override
  Future<Profile?> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client.from('profiles').select(_columns).eq('id', uid).maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Profile> saveDisplayName(String name) async {
    final problem = Profile.validateDisplayName(name);
    if (problem != null) throw AppFailure(FailureKind.invalidInput, problem);

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AppFailure(FailureKind.unauthorized, 'Sua sessão expirou. Entre novamente.');
    }
    try {
      // O perfil é criado por trigger no banco quando o usuário se cadastra;
      // aqui só atualizamos (RLS garante que só o próprio perfil é alterável).
      final row = await _client
          .from('profiles')
          .update({'display_name': name.trim()})
          .eq('id', uid)
          .select(_columns)
          .single();
      return Profile.fromMap(row);
    } catch (e) {
      throw _map(e);
    }
  }

  AppFailure _map(Object e) {
    if (e is AppFailure) return e;
    if (e is SocketException || e is TimeoutException) return AppFailure.network;
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return AppFailure.network;
    }
    return AppFailure.unknown;
  }
}

class UnavailableProfileRepository implements ProfileRepository {
  const UnavailableProfileRepository(this.reason);

  final String reason;

  @override
  Future<Profile?> fetchMine() async => null;

  @override
  Future<Profile> saveDisplayName(String name) =>
      Future<Profile>.error(AppFailure(FailureKind.notConfigured, reason));
}
