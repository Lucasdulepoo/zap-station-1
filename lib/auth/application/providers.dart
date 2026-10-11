import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/domain/profile.dart';
import '../data/auth_repository.dart';
import '../domain/otp_throttle.dart';

/// Injetados em main() (e substituídos por fakes nos testes).
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider deve ser sobrescrito em main()'),
);

final backendStatusProvider = Provider<BackendStatus>(
  (ref) => throw UnimplementedError('backendStatusProvider deve ser sobrescrito em main()'),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final status = ref.watch(backendStatusProvider);
  if (!status.isReady) return UnavailableAuthRepository(status.userMessage);
  return SupabaseAuthRepository(Supabase.instance.client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final status = ref.watch(backendStatusProvider);
  if (!status.isReady) return UnavailableProfileRepository(status.userMessage);
  return SupabaseProfileRepository(Supabase.instance.client);
});

/// Um controle de tentativas por execução do app, compartilhado entre as telas de telefone e OTP.
final otpThrottleProvider = Provider<OtpThrottle>((ref) => OtpThrottle());

/// Perfil do usuário atual (usado na tela de configurações).
final myProfileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  return ref.watch(profileRepositoryProvider).fetchMine();
});
