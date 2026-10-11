# Arquitetura — ZAP STATION

## Visão geral
```
 App Flutter (Android)                         Supabase                       Serviços externos
┌───────────────────────────┐   anon key    ┌──────────────────────┐
│ UI → Riverpod → Repository│──────────────▶│ Auth (OTP por SMS)   │──▶ Provedor de SMS (Twilio…)
│   (interfaces + fakes)    │   JWT + RLS   │ PostgreSQL + RLS     │
│                           │◀──Realtime────│ Realtime / Storage   │
└───────────────────────────┘               │ Edge Functions       │──▶ LiveKit (tokens/salas)
                                            │  (service_role)      │──▶ FCM (push)
                                            └──────────────────────┘
```
O app usa apenas a chave pública `anon`. Toda decisão de acesso é do banco (RLS) ou de Edge Functions.

## Módulos (`lib/`)
| Módulo | Conteúdo na Fase 1 |
|---|---|
| `config` | `AppConfig` (dart-define), validação (recusa `service_role`, exige https), `BackendStatus` |
| `core` | tema, widgets reutilizáveis, roteador, erros (`AppFailure`), utilitários |
| `auth` | telefone (E.164), controle de tentativas de OTP, repositório Supabase, sessão, telas de login/OTP/perfil/splash |
| `profiles` | modelo e repositório de perfil |
| `conversations` | modelo de lista, tela com busca (sem dados falsos), `ConversationTile` |
| `groups`, `calls`, `contacts` | telas "em breve" honestas (rotuladas com a fase) |
| `settings` | perfil, estado do servidor, versão, sair |
| `home` | navegação inferior (5 abas, estado preservado por aba) |

Padrão por módulo: `domain` (modelos/regras puras) · `data` (repositórios) · `application` (providers/estado) · `ui`.

## Decisões
- **Riverpod + go_router.** Redirecionamento por estado de sessão em função pura (`resolveRedirect`), fácil de testar.
- **Repositório com interface + `Unavailable*`.** Sem configuração do Supabase o app abre, mostra aviso e falha de forma explícita nas operações. Nada é simulado.
- **Splash nunca trava.** `Supabase.initialize` tem timeout de 8 s; consulta de perfil tem 6 s. Autenticado sem rede entra em modo degradado com aviso.
- **Telefone fica só em `auth.users`.** `profiles` não copia o número (menos exposição). Contatos por telefone (Fase 3) usarão RPC com hash/consentimento.
- **Mensagens com `seq` identity** além do UUID: o UUID gerado no cliente dá idempotência no reenvio (PK duplicada = já recebido); `seq` dá ordem total e cursor de paginação/contador de não lidas.
- **Recibos por destinatário** (`message_receipts`), iguais para direto e grupo; estado do remetente é derivado. `last_read_seq` em `conversation_members` sustenta o contador de não lidas mesmo com confirmação de leitura desligada.
- **Mídia**: binário no bucket privado `chat-media` (`<conversation_id>/<attachment_id>`); banco guarda só metadados. Upload só é aceito pelo Storage se o metadado já existe em `attachments` (tipo/tamanho validados antes). Leitura por URL assinada (Fase 5).
- **Grupos e chamadas**: sem `INSERT/UPDATE` direto pelo cliente; só via Edge Function (Fases 4 e 7).
- **Remoção de membro**: `left_at` preenchido ⇒ perde leitura imediatamente (toda política usa `is_active_member`).

## Regras de negócio documentadas
- Editar: só texto, só o remetente, até **15 min**; marca `edited_at`.
- Excluir "para todos": só o remetente, até **48 h**; apaga o corpo e marca `deleted_at`; mensagem excluída é imutável.
- Limite de envio: 30 mensagens / 10 s por remetente (trigger).
- Respostas citadas só para mensagens da mesma conversa.
- Bloqueio vale nos dois sentidos para enviar, abrir conversa direta e registrar anexo; o bloqueado não vê que foi bloqueado.
- Tamanhos máximos (editáveis em `media_limits`): imagem 20 MiB, vídeo 100 MiB, voz 16 MiB, áudio 50 MiB, documento 50 MiB.

## Fora do escopo da Fase 1 (e por quê)
Mensagens, grupos, mídia, push e chamadas dependem de backend real e/ou credenciais externas; ficam desabilitados e rotulados em vez de simulados.
