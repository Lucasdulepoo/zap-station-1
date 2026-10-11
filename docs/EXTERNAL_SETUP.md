# Configurações externas necessárias

O que precisa existir fora do repositório, por fase. Nada disso foi criado ou testado neste ambiente.

## Fase 2 — obrigatório para o login funcionar
1. **Projeto Supabase** (supabase.com). Anote *Project URL* e a chave **anon** (Settings → API). Não use `service_role` no app.
2. **Provedor de SMS** em Authentication → Providers → Phone: Twilio (Verify ou Messaging Service), MessageBird, Vonage ou TextLocal. Sem isso o app **mostra erro** ao pedir código — por desenho, nenhum SMS é simulado.
   - Custo por SMS, verificação de remetente/país (ex.: Brasil exige sender registrado em alguns provedores) e limites de gasto ficam por sua conta.
3. **Limites de abuso** (Authentication → Rate Limits): SMS por hora, verificações por hora, intervalo mínimo de reenvio (60 s) e validade do OTP. O limite do app é só conforto; **o do servidor é o que protege**.
4. **Aplicar migrações**: `supabase link --project-ref <ref>` e `supabase db push` (ou colar os arquivos de `supabase/migrations` em ordem no SQL Editor).
5. Compilar o app com `SUPABASE_URL` e `SUPABASE_ANON_KEY` (README).

## Fase 5 — mídia
- Bucket `chat-media` é criado pela migração 0007 (privado). Conferir em Storage que continua **não público**.
- Agendar a rotina de limpeza de anexos órfãos (Edge Function `media-cleanup` + cron).

## Fase 6 — notificações
- **Projeto Firebase** + app Android `com.zapstation.app`; baixar `google-services.json` para `android/app/` (ignorado pelo Git).
- Conta de serviço (FCM HTTP v1) → `supabase secrets set FCM_SERVICE_ACCOUNT_JSON=...`.
- Webhook de banco → Edge Function `push-notify`.

## Fase 7 — chamadas
- **LiveKit Cloud** (ou servidor próprio com TURN): `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` via `supabase secrets set`.
- TURN: o LiveKit Cloud já inclui; em servidor próprio habilite o TURN embutido ou um coturn com credenciais temporárias.
- Teste obrigatório em **dois aparelhos reais** (áudio e vídeo) antes de considerar a fase concluída.

## Fase 9 — publicação
- **Keystore de release** (`docs/SIGNING.md`). Guarde cópia segura: perder a chave impede atualizar o app.
- Verificar disponibilidade do `applicationId` `com.zapstation.app` antes de publicar na Play Store (conta de desenvolvedor, política de privacidade, formulário de segurança de dados).
- Política de privacidade e termos de uso (exigidos pelas lojas e pela LGPD).
