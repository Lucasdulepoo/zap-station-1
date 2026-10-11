-- ZAP STATION — migração 0006: Row Level Security e privilégios
-- Princípio: negar por padrão. `anon` não recebe nenhum privilégio; `authenticated`
-- recebe apenas as colunas e operações listadas, sempre filtradas por políticas RLS.
-- Operações privilegiadas (grupos, chamadas, notificações) ficam com service_role
-- via Edge Functions.

-- Remove os privilégios padrão herdados e passa a conceder explicitamente.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

grant usage on schema public to anon, authenticated;

-- Funções chamadas por políticas e pelo aplicativo.
grant execute on function
  public.is_active_member(uuid, uuid),
  public.is_group_admin(uuid, uuid),
  public.shares_conversation_with(uuid),
  public.is_blocked_between(uuid, uuid),
  public.can_send_message(uuid, uuid),
  public.try_uuid(text),
  public.get_last_seen(uuid),
  public.create_direct_conversation(uuid),
  public.mark_conversation_delivered(uuid, bigint),
  public.mark_conversation_read(uuid, bigint),
  public.register_device(text, text, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_path, about) on public.profiles to authenticated;

create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.shares_conversation_with(id));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- profile_settings (privado)
-- ---------------------------------------------------------------------------
alter table public.profile_settings enable row level security;

grant select on public.profile_settings to authenticated;
grant update (privacy_last_seen, privacy_read_receipts, last_seen_at) on public.profile_settings to authenticated;

create policy profile_settings_select_own on public.profile_settings
  for select to authenticated
  using (user_id = auth.uid());

create policy profile_settings_update_own on public.profile_settings
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- conversations (somente leitura para o cliente; criação via RPC / backend)
-- ---------------------------------------------------------------------------
alter table public.conversations enable row level security;

grant select on public.conversations to authenticated;

create policy conversations_select on public.conversations
  for select to authenticated
  using (public.is_active_member(id));

-- ---------------------------------------------------------------------------
-- conversation_members
-- ---------------------------------------------------------------------------
alter table public.conversation_members enable row level security;

grant select on public.conversation_members to authenticated;
grant update (muted_until) on public.conversation_members to authenticated;

create policy conversation_members_select on public.conversation_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_active_member(conversation_id));

create policy conversation_members_update_own on public.conversation_members
  for update to authenticated
  using (user_id = auth.uid() and left_at is null)
  with check (user_id = auth.uid() and left_at is null);

-- ---------------------------------------------------------------------------
-- messages
-- ---------------------------------------------------------------------------
alter table public.messages enable row level security;

grant select on public.messages to authenticated;
grant insert (id, conversation_id, sender_id, type, body, reply_to_id, forwarded) on public.messages to authenticated;
grant update (body, deleted_at) on public.messages to authenticated;

create policy messages_select on public.messages
  for select to authenticated
  using (public.is_active_member(conversation_id));

create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and type <> 'system'
    and public.can_send_message(conversation_id)
  );

create policy messages_update_own on public.messages
  for update to authenticated
  using (sender_id = auth.uid() and public.is_active_member(conversation_id))
  with check (sender_id = auth.uid() and public.is_active_member(conversation_id));

-- ---------------------------------------------------------------------------
-- message_receipts
-- ---------------------------------------------------------------------------
alter table public.message_receipts enable row level security;

grant select on public.message_receipts to authenticated;
grant insert (message_id, user_id, delivered_at, read_at) on public.message_receipts to authenticated;
grant update (delivered_at, read_at) on public.message_receipts to authenticated;

create policy message_receipts_select on public.message_receipts
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.messages m
      where m.id = message_receipts.message_id and m.sender_id = auth.uid()
    )
  );

create policy message_receipts_insert_own on public.message_receipts
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.messages m
      where m.id = message_receipts.message_id
        and m.sender_id is distinct from auth.uid()
    )
  );

create policy message_receipts_update_own on public.message_receipts
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- attachments
-- ---------------------------------------------------------------------------
alter table public.attachments enable row level security;

grant select, delete on public.attachments to authenticated;
grant insert (id, conversation_id, owner_id, storage_path, kind, mime_type, size_bytes, duration_ms, width, height)
  on public.attachments to authenticated;
grant update (message_id, status, duration_ms, width, height) on public.attachments to authenticated;

create policy attachments_select on public.attachments
  for select to authenticated
  using (public.is_active_member(conversation_id));

create policy attachments_insert on public.attachments
  for insert to authenticated
  with check (
    owner_id = auth.uid()
    and public.can_send_message(conversation_id)
  );

create policy attachments_update_own on public.attachments
  for update to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    and (
      message_id is null
      or exists (
        select 1 from public.messages m
        where m.id = attachments.message_id
          and m.conversation_id = attachments.conversation_id
          and m.sender_id = auth.uid()
      )
    )
  );

-- Cancelar upload: só enquanto o anexo ainda não pertence a uma mensagem.
create policy attachments_delete_pending_own on public.attachments
  for delete to authenticated
  using (owner_id = auth.uid() and message_id is null);

-- ---------------------------------------------------------------------------
-- media_limits (leitura pública autenticada, escrita só no backend)
-- ---------------------------------------------------------------------------
alter table public.media_limits enable row level security;
grant select on public.media_limits to authenticated;

create policy media_limits_select on public.media_limits
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- calls (somente leitura do próprio histórico; escrita só pelo backend)
-- ---------------------------------------------------------------------------
alter table public.calls enable row level security;
grant select on public.calls to authenticated;

create policy calls_select_participant on public.calls
  for select to authenticated
  using (caller_id = auth.uid() or callee_id = auth.uid());

-- ---------------------------------------------------------------------------
-- devices (escrita via register_device)
-- ---------------------------------------------------------------------------
alter table public.devices enable row level security;
grant select, delete on public.devices to authenticated;

create policy devices_select_own on public.devices
  for select to authenticated using (user_id = auth.uid());

create policy devices_delete_own on public.devices
  for delete to authenticated using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- blocks (o bloqueado não enxerga o bloqueio)
-- ---------------------------------------------------------------------------
alter table public.blocks enable row level security;
grant select, delete on public.blocks to authenticated;
grant insert (blocker_id, blocked_id) on public.blocks to authenticated;

create policy blocks_select_own on public.blocks
  for select to authenticated using (blocker_id = auth.uid());

create policy blocks_insert_own on public.blocks
  for insert to authenticated with check (blocker_id = auth.uid());

create policy blocks_delete_own on public.blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- ---------------------------------------------------------------------------
-- reports
-- ---------------------------------------------------------------------------
alter table public.reports enable row level security;
grant select on public.reports to authenticated;
grant insert (reporter_id, reported_user_id, conversation_id, message_id, reason, details)
  on public.reports to authenticated;

create policy reports_select_own on public.reports
  for select to authenticated using (reporter_id = auth.uid());

-- Só é possível denunciar mensagens/conversas que o usuário consegue ler.
create policy reports_insert_own on public.reports
  for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and (message_id is null or exists (select 1 from public.messages m where m.id = reports.message_id))
    and (conversation_id is null or public.is_active_member(conversation_id))
  );

-- ---------------------------------------------------------------------------
-- group_events (escrita só pelo backend)
-- ---------------------------------------------------------------------------
alter table public.group_events enable row level security;
grant select on public.group_events to authenticated;

create policy group_events_select on public.group_events
  for select to authenticated
  using (public.is_active_member(conversation_id));
