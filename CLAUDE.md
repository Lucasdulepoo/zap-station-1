# CLAUDE.md — ZAP STATION

App Android de mensagens (Flutter + Supabase). Leia `README.md` para rodar e `docs/` para decisões.

## Regras que não podem ser quebradas
- **Nunca** colocar `service_role`, senhas de banco, `LIVEKIT_API_SECRET` ou conta de serviço do FCM em `lib/`, `android/`, assets ou `--dart-define`. No app só entram `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
- **Nunca** simular SMS enviado, número verificado, mensagem entregue ou chamada concluída. Se o provedor não confirmou, a UI mostra erro.
- Botão que não faz nada de verdade fica **desabilitado e rotulado com a fase** (ver `FeaturePendingView`).
- Identidade e permissões vêm do servidor (`auth.uid()` + RLS). Nunca confiar em `sender_id`, papel ou admin enviados pelo cliente.
- Não afirmar criptografia ponta a ponta: não existe. Só TLS em trânsito + RLS. Não inventar protocolo próprio.
- Não registrar telefone, tokens ou conteúdo de mensagens em logs.
- Não marcar teste como aprovado sem executá-lo; registrar o que **não** foi executado em `docs/TESTING.md`.

## Estrutura
`lib/<módulo>/{domain,data,application,ui}`: `config`, `core`, `auth`, `profiles`, `conversations`, `groups`, `calls`, `contacts`, `settings`, `home`.
Módulos `media` e `notifications` serão criados nas Fases 5 e 6.
Repositórios são interfaces (`AuthRepository`…) com implementação Supabase e uma `Unavailable*` usada quando o backend não está configurado. Testes usam fakes em `test/helpers/fakes.dart`.
Estado: Riverpod. Navegação: go_router (`resolveRedirect` é função pura e testada).

## Banco
Migrações em `supabase/migrations` (ordem pelo timestamp no nome). Testes em `supabase/tests`; `supabase/tests/run_local.sh` sobe um PostgreSQL descartável com stubs do Supabase e roda `20_rls_tests.sql`. Toda mudança de política RLS exige teste correspondente — e conferir que o teste **falha** quando a política é enfraquecida.
Escritas privilegiadas (grupos, chamadas, notificações, limpeza) só por Edge Function com `service_role`; o cliente não tem `INSERT/UPDATE` nessas tabelas.

## Comandos
```
flutter pub get && flutter analyze && flutter test
supabase/tests/run_local.sh            # RLS (precisa de binários do PostgreSQL)
python3 tools/generate_brand_assets.py # regenera ícones (Pillow)
```
