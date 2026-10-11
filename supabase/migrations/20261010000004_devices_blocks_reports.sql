-- ZAP STATION — migração 0004: dispositivos (push), bloqueios e denúncias

create table public.devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  platform     text not null default 'android' check (platform in ('android')),
  fcm_token    text not null unique check (char_length(fcm_token) between 20 and 4096),
  app_version  text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index devices_user_idx on public.devices (user_id);

create trigger devices_set_updated_at
  before update on public.devices
  for each row execute function public.set_updated_at();

create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index blocks_blocked_idx on public.blocks (blocked_id);

create table public.reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reported_user_id uuid references public.profiles (id) on delete set null,
  conversation_id  uuid references public.conversations (id) on delete set null,
  message_id       uuid references public.messages (id) on delete set null,
  reason           text not null check (reason in ('spam', 'abuse', 'harassment', 'illegal', 'impersonation', 'other')),
  details          text check (details is null or char_length(details) <= 1000),
  status           text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (reported_user_id is not null or conversation_id is not null or message_id is not null)
);

create index reports_reporter_idx on public.reports (reporter_id, created_at desc);
create index reports_status_idx on public.reports (status, created_at desc);

create trigger reports_set_updated_at
  before update on public.reports
  for each row execute function public.set_updated_at();
