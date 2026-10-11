# ZAP STATION

Aplicativo Android de mensagens (Flutter + Supabase) com identidade visual própria: escuro, tecnológico, destaque ciano.

> **Estado: Fase 1 (fundação).** Existem: identidade visual, navegação, fluxo de cadastro por telefone/OTP e perfil
> (ligados ao Supabase Auth), banco com RLS testado e documentação. **Ainda não existem**: mensagens, grupos, mídia,
> notificações e chamadas — as telas correspondentes aparecem desabilitadas e rotuladas com a fase.
> Leia [`docs/TESTING.md`](docs/TESTING.md) para saber exatamente o que foi e o que **não** foi executado.

## Pré-requisitos
- Flutter estável (Dart ≥ 3.6) e Android SDK (API 24+ no aparelho).
- Uma conta/projeto Supabase e um provedor de SMS para login real — veja [`docs/EXTERNAL_SETUP.md`](docs/EXTERNAL_SETUP.md).
- Para testar o banco localmente: binários do PostgreSQL 15+ (`initdb`, `pg_ctl`, `psql`).

## Primeira execução
O diretório `android/` traz manifesto, Gradle e ícones, mas **não** o `gradle-wrapper.jar` (binário). Complete uma vez:
```bash
flutter create . --platforms=android --org com.zapstation --project-name zap_station
git status   # confira: o flutter create não deve ter sobrescrito nada seu; reverta se algo foi alterado
flutter pub get
```
Versões do AGP/Kotlin/Gradle e dos pacotes **não foram resolvidas por build real** — veja [`docs/VERSIONS.md`](docs/VERSIONS.md).

## Rodar em desenvolvimento
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON \
  --dart-define=APP_ENV=dev
```
Sem essas variáveis o app abre normalmente, avisa que o servidor não está configurado e **recusa** enviar códigos
(nenhum SMS é simulado). Use **somente** a chave `anon`; o app recusa iniciar se detectar uma `service_role`.

Emulador Android acessando Supabase local: `SUPABASE_URL=http://10.0.2.2:54321`.

## Verificar, testar, compilar
```bash
flutter pub get
flutter analyze
flutter test
supabase/tests/run_local.sh        # migrações + 48 verificações de RLS em um PostgreSQL descartável

flutter build apk --debug   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...   # veja docs/SIGNING.md
```
APK em `build/app/outputs/flutter-apk/`. Instalar: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

## Banco de dados
Migrações versionadas em `supabase/migrations/` (ordem pelo timestamp). Aplicar: `supabase link --project-ref <ref> && supabase db push`.
Tabelas: `profiles`, `profile_settings`, `conversations`, `conversation_members`, `messages`, `message_receipts`,
`attachments`, `media_limits`, `calls`, `devices`, `blocks`, `reports`, `group_events`. RLS em todas; `anon` sem acesso a nada.

## Estrutura
```
android/        manifesto, Gradle, ícones, tema de abertura
assets/         marca (SVG) e ícones-fonte
docs/           arquitetura, configuração externa, segurança, testes, versões, assinatura
lib/            módulos: config core auth profiles conversations groups calls contacts settings home
supabase/       config.toml, migrations/, functions/ (plano), tests/ (RLS)
test/           testes Dart (unitários e de widget)
tools/          gerador de ícones
```

## Solução de problemas
| Sintoma | Causa provável |
|---|---|
| Faixa "servidor não configurado" no login | faltou `--dart-define` de `SUPABASE_URL`/`SUPABASE_ANON_KEY` |
| "Não foi possível enviar o SMS" | provedor de SMS não configurado no Supabase Auth |
| "Muitas tentativas" | limite de SMS/hora do Supabase atingido; aguarde |
| `flutter.sdk não definido em local.properties` | rode `flutter create .` / `flutter pub get` para gerar `android/local.properties` |
| Erro de versão do AGP/Gradle/Kotlin | ajuste conforme `docs/VERSIONS.md` |
| `run_local.sh`: "initdb não encontrado" | instale PostgreSQL (`apt install postgresql`) |

## Segurança em uma linha
Só a chave pública entra no app; permissões vivem no banco (RLS) e em Edge Functions; **não há criptografia ponta a ponta** — veja [`docs/SECURITY.md`](docs/SECURITY.md).
