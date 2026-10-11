# Edge Functions

Nenhuma função foi implementada na Fase 1 — de propósito: cada uma depende de credenciais externas
(LiveKit, Firebase) que ainda não existem, e funções sem teste real seriam só aparência de progresso.

Plano (autorização sempre no servidor, identidade sempre vinda do JWT, nunca do corpo da requisição):

| Função | Fase | O que faz | Segredos necessários |
|---|---|---|---|
| `group-admin` | 4 | Criar grupo, adicionar/remover membros, mudar papéis, sair, registrar `group_events` | — (usa `service_role` do runtime) |
| `media-cleanup` | 5 | Remover anexos órfãos (`message_id is null` e antigos) e objetos do Storage | — |
| `push-notify` | 6 | Disparado por webhook de `messages`/`calls`; envia FCM sem conteúdo privado | `FCM_SERVICE_ACCOUNT_JSON` |
| `call-token` | 7 | Cria a sala, valida participação/bloqueio e emite token LiveKit curto restrito à sala | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` |
| `account-delete` | 8 | Exclusão de conta e dados pessoais | — |

Segredos entram por `supabase secrets set` (veja `.env.example`), nunca no repositório nem no APK.
