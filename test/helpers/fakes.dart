import 'dart:async';

import 'package:zap_station/auth/data/auth_repository.dart';
import 'package:zap_station/core/errors/app_failure.dart';
import 'package:zap_station/profiles/data/profile_repository.dart';
import 'package:zap_station/profiles/domain/profile.dart';

/// Fake de AuthRepository para testes. Simula o SERVIDOR: só considera o usuário
/// autenticado quando o código aceito é informado (nenhuma verificação local no app).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    bool signedIn = false,
    this.phone,
    this.acceptedCode = '123456',
    this.requestFailure,
  }) : _signedIn = signedIn;

  final String? phone;
  final String acceptedCode;
  AppFailure? requestFailure;

  bool _signedIn;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  final List<String> requestedPhones = [];
  final List<String> verifiedCodes = [];

  @override
  bool get isAvailable => true;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get currentUserId => _signedIn ? 'user-1' : null;

  @override
  String? get currentPhone => _signedIn ? phone : null;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Future<void> requestOtp(String e164Phone) async {
    requestedPhones.add(e164Phone);
    final failure = requestFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> verifyOtp({required String e164Phone, required String code}) async {
    verifiedCodes.add(code);
    if (code != acceptedCode) {
      throw const AppFailure(
        FailureKind.invalidCode,
        'Código incorreto. Confira os dígitos e tente de novo.',
      );
    }
    _signedIn = true;
    _changes.add(true);
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _changes.add(false);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile, this.fetchError});

  Profile? profile;
  Object? fetchError;

  @override
  Future<Profile?> fetchMine() async {
    final error = fetchError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<Profile> saveDisplayName(String name) async {
    final problem = Profile.validateDisplayName(name);
    if (problem != null) throw AppFailure(FailureKind.invalidInput, problem);
    profile = Profile(id: 'user-1', displayName: name.trim());
    return profile!;
  }
}
