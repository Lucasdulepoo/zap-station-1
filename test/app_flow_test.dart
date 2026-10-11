import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/app.dart';
import 'package:zap_station/auth/application/providers.dart';
import 'package:zap_station/config/app_config.dart';
import 'package:zap_station/conversations/application/conversations_providers.dart';
import 'package:zap_station/conversations/domain/conversation_summary.dart';
import 'package:zap_station/profiles/domain/profile.dart';

import 'helpers/fakes.dart';

Widget _app({
  required FakeAuthRepository auth,
  required FakeProfileRepository profiles,
  List<ConversationSummary>? conversations,
}) =>
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(supabaseUrl: '', supabaseAnonKey: '')),
        backendStatusProvider.overrideWithValue(const BackendStatus.ready()),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        if (conversations != null) conversationSummariesProvider.overrideWithValue(conversations),
      ],
      child: const ZapStationApp(),
    );

void main() {
  testWidgets('sem sessão salva: abre direto no login por telefone', (tester) async {
    await tester.pumpWidget(_app(auth: FakeAuthRepository(), profiles: FakeProfileRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Seu número de telefone'), findsOneWidget);
    expect(find.text('Conversas'), findsNothing);
  });

  testWidgets('sessão recuperada com perfil: abre nas conversas com a navegação inferior', (tester) async {
    await tester.pumpWidget(_app(
      auth: FakeAuthRepository(signedIn: true),
      profiles: FakeProfileRepository(profile: const Profile(id: 'user-1', displayName: 'Ana')),
    ));
    await tester.pumpAndSettle();

    for (final label in ['Conversas', 'Grupos', 'Chamadas', 'Contatos', 'Ajustes']) {
      expect(find.text(label), findsWidgets, reason: 'aba $label');
    }
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });

  testWidgets('sessão sem nome: obriga a completar o perfil', (tester) async {
    await tester.pumpWidget(_app(
      auth: FakeAuthRepository(signedIn: true),
      profiles: FakeProfileRepository(profile: const Profile(id: 'user-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Como podemos te chamar?'), findsOneWidget);
  });

  testWidgets('abas de fases futuras dizem claramente que ainda não existem', (tester) async {
    await tester.pumpWidget(_app(
      auth: FakeAuthRepository(signedIn: true),
      profiles: FakeProfileRepository(profile: const Profile(id: 'user-1', displayName: 'Ana')),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grupos'));
    await tester.pumpAndSettle();
    expect(find.text('Grupos em breve'), findsOneWidget);

    await tester.tap(find.text('Chamadas'));
    await tester.pumpAndSettle();
    expect(find.text('Chamadas em breve'), findsOneWidget);
  });

  testWidgets('lista de conversas mostra não lidas e filtra pela busca', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_app(
      auth: FakeAuthRepository(signedIn: true),
      profiles: FakeProfileRepository(profile: const Profile(id: 'user-1', displayName: 'Ana')),
      conversations: [
        ConversationSummary(
          id: '1',
          title: 'Bruno',
          lastMessagePreview: 'bora jogar?',
          lastActivityAt: now,
          unreadCount: 3,
        ),
        ConversationSummary(
          id: '2',
          title: 'Clã Alpha',
          lastMessagePreview: 'treino às 20h',
          lastActivityAt: now.subtract(const Duration(days: 1)),
          isGroup: true,
          lastMessageState: MessageDeliveryState.read,
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Clã Alpha'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump();
    expect(find.text('Bruno'), findsNothing);
    expect(find.text('Clã Alpha'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nenhuma conversa encontrada.'), findsOneWidget);
  });
}
