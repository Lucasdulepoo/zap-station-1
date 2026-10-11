-- ZAP STATION — migração 0003: recibos, anexos e chamadas

-- Um registro por (mensagem, destinatário). Serve igualmente para conversas
-- diretas e grupos: o estado agregado do remetente é derivado destas linhas.
create table public.message_receipts (
  message_id   uuid not null references public.messages (id) on delete cascade,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  delivered_at timestamptz,
  read_at      timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (message_id, user_id),
  -- "lido" implica "entregue" (normalizado por trigger).
  check (read_at is null or delivered_at is not null)
);

create index message_receipts_user_idx on public.message_receipts (user_id, message_id);

create trigger message_receipts_set_updated_at
  before update on public.message_receipts
  for each row execute function public.set_updated_at();

-- Limites configuráveis de tamanho por tipo de mídia (editáveis só pelo backend).
create table public.media_limits (
  kind      text primary key check (kind in ('image', 'video', 'voice', 'audio', 'document')),
  max_bytes bigint not null check (max_bytes > 0)
);

insert into public.media_limits (kind, max_bytes) values
  ('image',    20971520),   -- 20 MiB
  ('video',   104857600),   -- 100 MiB
  ('voice',    16777216),   -- 16 MiB
  ('audio',    52428800),   -- 50 MiB
  ('document', 52428800);   -- 50 MiB

-- Apenas metadados: o binário fica no Supabase Storage (bucket privado chat-media).
create table public.attachments (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  -- Nulo enquanto o upload ocorre; anexos órfãos são removidos por rotina de limpeza.
  message_id      uuid references public.messages (id) on delete cascade,
  owner_id        uuid default auth.uid() references public.profiles (id) on delete set null,
  bucket          text not null default 'chat-media' check (bucket = 'chat-media'),
  storage_path    text not null unique,
  kind            text not null check (kind in ('image', 'video', 'voice', 'audio', 'document')),
  mime_type       text not null,
  size_bytes      bigint not null check (size_bytes > 0),
  duration_ms     integer check (duration_ms is null or duration_ms >= 0),
  width           integer check (width is null or width > 0),
  height          integer check (height is null or height > 0),
  status          text not null default 'uploading' check (status in ('uploading', 'ready', 'failed')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- O caminho precisa começar pela pasta da conversa (base da política do Storage).
  constraint attachments_path_in_conversation check (storage_path like conversation_id::text || '/%'),
  constraint attachments_mime_allowed check (
    mime_type ~ '^(image/(jpeg|png|webp|gif|heic)|video/(mp4|quicktime|webm)|audio/(mpeg|mp4|aac|ogg|opus|webm|x-m4a)|application/(pdf|zip|msword|vnd\.openxmlformats-officedocument\.[a-z.]+)|text/plain)$'
  ),
  constraint attachments_kind_matches_mime check (
    (kind = 'image' and mime_type like 'image/%')
    or (kind = 'video' and mime_type like 'video/%')
    or (kind in ('voice', 'audio') and mime_type like 'audio/%')
    or (kind = 'document' and (mime_type like 'application/%' or mime_type = 'text/plain'))
  )
);

create index attachments_message_idx on public.attachments (message_id) where message_id is not null;
create index attachments_conversation_idx on public.attachments (conversation_id, created_at desc);
create index attachments_orphans_idx on public.attachments (created_at) where message_id is null;

create trigger attachments_set_updated_at
  before update on public.attachments
  for each row execute function public.set_updated_at();

-- Chamadas individuais. Criadas e atualizadas somente pelo backend
-- (Edge Function com service_role); o cliente apenas lê o próprio histórico.
create table public.calls (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  caller_id       uuid references public.profiles (id) on delete set null,
  callee_id       uuid references public.profiles (id) on delete set null,
  kind            text not null check (kind in ('voice', 'video')),
  status          text not null default 'ringing'
                  check (status in ('ringing', 'accepted', 'declined', 'missed', 'ended', 'failed', 'cancelled')),
  room_name       text not null unique,
  created_at      timestamptz not null default now(),
  answered_at     timestamptz,
  ended_at        timestamptz,
  end_reason      text,
  updated_at      timestamptz not null default now(),
  check (caller_id is distinct from callee_id)
);

create index calls_caller_idx on public.calls (caller_id, created_at desc);
create index calls_callee_idx on public.calls (callee_id, created_at desc);

create trigger calls_set_updated_at
  before update on public.calls
  for each row execute function public.set_updated_at();
