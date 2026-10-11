-- ZAP STATION — migração 0001: perfis e configurações privadas
-- Depende do schema `auth` do Supabase (auth.users).

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Dados do perfil visíveis a quem compartilha uma conversa com o usuário.
-- O telefone NÃO é copiado para cá: ele permanece apenas em auth.users.
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(btrim(display_name)) between 1 and 60),
  avatar_path  text,
  about        text check (about is null or char_length(about) <= 140),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Configurações privadas: nunca legíveis por outros usuários.
create table public.profile_settings (
  user_id               uuid primary key references public.profiles (id) on delete cascade,
  privacy_last_seen     text not null default 'contacts'
                        check (privacy_last_seen in ('everyone', 'contacts', 'nobody')),
  privacy_read_receipts boolean not null default true,
  last_seen_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger profile_settings_set_updated_at
  before update on public.profile_settings
  for each row execute function public.set_updated_at();

-- Cria perfil e configurações vazios quando um usuário é criado no Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  insert into public.profile_settings (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
