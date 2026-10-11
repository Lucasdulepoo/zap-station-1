import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/auth/application/providers.dart';
import 'package:zap_station/auth/application/session_controller.dart';
import 'package:zap_station/profiles/domain/profile.dart';

import '../helpers/fakes.dart';

ProviderContainer _container(FakeAuthRepository auth, FakeProfileRepository profiles) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(profiles),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sem sessão salva: signedOut', () async {
    final c = _container(FakeAuthRepository(), FakeProfileRepository());
    expect(c.read(sessionProvider).status, SessionStatus.initializing);
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.signedOut);
  });

  test('sessão recuperada com perfil completo: ready', () async {
    final c = _container(
      FakeAuthRepository(signedIn: true),
      FakeProfileRepository(profile: const Profile(id: 'user-1', displayName: 'Ana')),
    );
    c.read(sessionProvider);
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.ready);
    expect(c.read(sessionProvider).degraded, isFalse);
  });

  test('sessão sem nome no perfil: needsProfile', () async {
    final c = _container(
      FakeAuthRepository(signedIn: true),
      FakeProfileRepository(profile: const Profile(id: 'user-1')),
    );
    c.read(sessionProvider);
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.needsProfile);
  });

  test('servidor inacessível não trava o usuário autenticado: ready + degraded', () async {
    final c = _container(
      FakeAuthRepository(signedIn: true),
      FakeProfileRepository(fetchError: Exception('sem rede')),
    );
    c.read(sessionProvider);
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.ready);
    expect(c.read(sessionProvider).degraded, isTrue);
  });

  test('logout reavalia a sessão para signedOut', () async {
    final auth = FakeAuthRepository(signedIn: true);
    final c = _container(
      auth,
      FakeProfileRepository(profile: const Profile(id: 'user-1', displayName: 'Ana')),
    );
    c.read(sessionProvider);
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.ready);

    await auth.signOut();
    await pumpEventQueue();
    expect(c.read(sessionProvider).status, SessionStatus.signedOut);
  });
}
