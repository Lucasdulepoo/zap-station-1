-- ZAP STATION — migração 0002: conversas, membros e mensagens

create table public.conversations (
  id                        uuid primary key default gen_random_uuid(),
  type                      text not null check (type in ('direct', 'group')),
  -- Para conversas diretas: "<menor uuid>:<maior uuid>". Impede duplicatas.
  direct_key                text unique,
  title                     text check (title is null or char_length(btrim(title)) between 1 and 100),
  avatar_path               text,
  created_by                uuid references public.profiles (id) on delete set null,
  only_admins_can_send      boolean not null default false,
  only_admins_can_edit_info boolean not null default true,
  last_message_id           uuid,
  last_activity_at          timestamptz not null default now(),
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  constraint conversations_shape check (
    (type = 'direct' and direct_key is not null and title is null)
    or (type = 'group' and direct_key is null and title is not null)
  )
);

create index conversations_last_activity_idx on public.conversations (last_activity_at desc);

create trigger conversations_set_updated_at
  before update on public.conversations
  for each row execute function public.set_updated_at();

create table public.conversation_members (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  role            text not null default 'member' check (role in ('member', 'admin', 'owner')),
  joined_at       timestamptz not null default now(),
  -- left_at nulo = participante ativo. Preenchido ao sair ou ser removido.
  left_at         timestamptz,
  removed_by      uuid references public.profiles (id) on delete set null,
  muted_until     timestamptz,
  -- Maior seq lido por este usuário; base do contador de não lidas.
  last_read_seq   bigint not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  primary key (conversation_id, user_id),
  check (left_at is null or left_at >= joined_at)
);

create index conversation_members_active_user_idx
  on public.conversation_members (user_id) where left_at is null;
create index conversation_members_active_conv_idx
  on public.conversation_members (conversation_id) where left_at is null;

create trigger conversation_members_set_updated_at
  before update on public.conversation_members
  for each row execute function public.set_updated_at();

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  -- Ordem total no servidor; usada para paginação por cursor e contagem de não lidas.
  seq             bigint generated always as identity,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  -- Nulo para mensagens de sistema ou após exclusão da conta do remetente.
  sender_id       uuid default auth.uid() references public.profiles (id) on delete set null,
  type            text not null default 'text'
                  check (type in ('text', 'image', 'video', 'voice', 'audio', 'document', 'system')),
  body            text check (body is null or char_length(body) <= 4000),
  reply_to_id     uuid references public.messages (id) on delete set null,
  forwarded       boolean not null default false,
  edited_at       timestamptz,
  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint messages_text_has_body check (
    type <> 'text'
    or deleted_at is not null
    or (body is not null and char_length(btrim(body)) > 0)
  )
);

create index messages_conversation_seq_idx on public.messages (conversation_id, seq desc);
create index messages_sender_created_idx on public.messages (sender_id, created_at desc);
create index messages_reply_to_idx on public.messages (reply_to_id) where reply_to_id is not null;

-- Eventos importantes de grupo (histórico de alterações). Escritos apenas pelo backend.
create table public.group_events (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  actor_id        uuid references public.profiles (id) on delete set null,
  event_type      text not null check (event_type in (
                    'group_created', 'member_added', 'member_removed', 'member_left',
                    'role_changed', 'title_changed', 'avatar_changed', 'settings_changed')),
  target_user_id  uuid references public.profiles (id) on delete set null,
  metadata        jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create index group_events_conversation_idx on public.group_events (conversation_id, created_at desc);
