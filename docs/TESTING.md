# Testes — o que foi executado e o que não foi

Registro honesto. "Executado" significa que rodou neste ambiente e passou; o resto está marcado.

## Executados
| Verificação | Como | Resultado |
|---|---|---|
| Migrações 0001–0007 aplicam do zero | `supabase/tests/run_local.sh` (PostgreSQL 16 local + stubs de `auth`/`storage`) | OK |
| 48 verificações de RLS/regras | `supabase/tests/20_rls_tests.sql` | 48 aprovadas |
| Os testes de RLS detectam regressão | política `messages_select` trocada por `using (true)` em cópia das migrações | falhou como esperado (`FAIL: dave ve mensagens`) |
| Contraste de cores (WCAG AA 4,5:1) | cálculo em Python da paleta | todos os pares ≥ 4,87 |
| Geração dos ícones | `tools/generate_brand_assets.py` + inspeção visual | OK |

Cobertura do RLS: anon sem acesso · não membro não lê mensagens/anexos/chamadas/recibos/arquivos · não forja `sender_id` ·
sem mensagem de sistema pelo cliente · idempotência por id · limite de taxa · janelas de edição (15 min) e exclusão (48 h) ·
colunas imutáveis · bloqueio nos dois sentidos · grupo só-admins · membro removido perde acesso · cliente não se promove
nem adiciona membros · conversa direta idempotente · recibos (não regridem, não forjáveis, privacidade de leitura) ·
anexos (MIME, tamanho, pasta da conversa) · Storage (leitura por participação, upload só com metadado prévio) ·
chamadas só leitura · reatribuição de token FCM · denúncias · perfis e `get_last_seen`.

## Escritos mas NÃO executados
Este ambiente não alcança `pub.dev`, `storage.googleapis.com` nem o Maven do Google, então **não há Dart/Flutter/Android SDK**.
Portanto, **não foram executados**: `flutter pub get`, `flutter analyze`, `flutter test` e `flutter build apk`.
Os arquivos em `test/` (telefone, OTP, config, sessão, roteamento, contraste, telas de login/OTP, fluxo do app) foram
escritos com cuidado, mas podem ter erros de compilação ou de asserção até alguém rodá-los. **Rode `flutter analyze && flutter test`
primeiro** e trate falhas como esperadas na primeira execução.

## Não testáveis ainda (dependem de fases/credenciais)
Cadastro e OTP reais (provedor de SMS) · recuperação de sessão em aparelho · mensagens em tempo real e reconexão ·
grupos pela UI · upload/download/vídeo/voz · notificações em segundo plano · chamadas de voz/vídeo entre dois aparelhos ·
permissões de câmera/microfone · expiração de tokens de chamada · falha do Storage · instalação do APK em aparelho real.
