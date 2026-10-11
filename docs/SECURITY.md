# Segurança e privacidade

## Modelo
- O app tem apenas a chave **anon**. Tudo que ela pode fazer é definido por privilégios de coluna + RLS (migração 0006).
- `anon` (não autenticado) não tem privilégio em nenhuma tabela pública; testado.
- Identidade vem de `auth.uid()` (JWT). `sender_id`, `owner_id`, `reporter_id` têm default `auth.uid()` e a política exige igualdade.
- Operações privilegiadas (grupos, chamadas, notificações, limpeza, exclusão de conta) serão Edge Functions com `service_role` — o cliente não tem `INSERT/UPDATE` nessas tabelas.
- `SECURITY DEFINER` só em funções auxiliares com `search_path` fixo, `execute` revogado de `public/anon` e concedido apenas a `authenticated`.

## Implementado (Fase 1)
- RLS em todas as tabelas; leitura de mensagens/anexos/arquivos exige ser **membro ativo** (`left_at is null`).
- Telefone só em `auth.users`; `profile_settings` privado; `get_last_seen` respeita privacidade e conversa em comum.
- Bucket `chat-media` privado; MIME e tamanho validados no banco antes do upload; sem binários em tabelas.
- Limite de taxa de envio no banco; limites de OTP no cliente (conforto) — **o limite real é do servidor**.
- App recusa iniciar com chave `service_role`, URL sem https (exceto localhost/emulador) e não loga dados pessoais.
- `allowBackup=false`, tráfego em claro desabilitado, fundo do `launch` sem flash.

## Pendente (com fase)
| Item | Fase |
|---|---|
| Exclusão de conta e dados pessoais (Edge Function + rotina) | 8 |
| Auditoria de dependências, ofuscação/minificação com regras | 8 |
| Notificações sem conteúdo na tela de bloqueio | 6 |
| Tokens de chamada curtos e restritos à sala; TURN | 7 |
| Limpeza de anexos órfãos | 5 |
| Armazenamento seguro de credenciais além da sessão do Supabase | 8 |
| Política de privacidade / termos (LGPD) | 9 |

## Criptografia ponta a ponta: **não existe**
Há TLS em trânsito e controle de acesso no servidor; o servidor consegue ler as mensagens. Não anuncie E2EE.
Se for desejável no futuro, usar um protocolo mantido por especialistas (ex.: Signal/libsignal ou MLS) com gestão de chaves,
verificação de identidade e rotação, cobrindo todos os tipos de mensagem — jamais um protocolo próprio.
