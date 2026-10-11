-- ZAP STATION — migração 0005: funções auxiliares, gatilhos de integridade e RPCs
-- Todas as funções SECURITY DEFINER fixam search_path e derivam a identidade de auth.uid();
-- nunca confiam em um user id enviado pelo cliente.

create or replace function public.try_uuid(p_text text)
returns uuid
language plpgsql
immutable
as $$
begin
  return p_text::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.is_active_member(p_conversation uuid, p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members m
    where m.conversation_id = p_conversation
      and m.user_id = p_user
      and m.left_at is null
  );
$$;

create or replace function public.is_group_admin(p_conversation uuid, p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members m
    where m.conversation_id = p_conversation
      and m.user_id = p_user
      and m.left_at is null
      and m.role in ('admin', 'owner')
  );
$$;

create or replace function public.shares_conversation_with(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members a
    join public.conversation_members b on b.conversation_id = a.conversation_id
    where a.user_id = auth.uid() and a.left_at is null
      and b.user_id = p_other and b.left_at is null
  );
$$;

-- Verdadeiro se qualquer um dos dois bloqueou o outro.
create or replace function public.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = p_a and blocked_id = p_b)
       or (blocker_id = p_b and blocked_id = p_a)
  );
$$;

-- Regra única de "pode enviar", usada por RLS de mensagens, anexos e Storage.
create or replace function public.can_send_message(p_conversation uuid, p_user uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_type text;
  v_only_admins boolean;
  v_role text;
  v_other uuid;
begin
  if p_user is null then
    return false;
  end if;

  select c.type, c.only_admins_can_send
    into v_type, v_only_admins
  from public.conversations c
  where c.id = p_conversation;

  if not found then
    return false;
  end if;

  select m.role into v_role
  from public.conversation_members m
  where m.conversation_id = p_conversation
    and m.user_id = p_user
    and m.left_at is null;

  if v_role is null then
    return false;
  end if;

  if v_type = 'group' then
    return (not v_only_admins) or v_role in ('admin', 'owner');
  end if;

  select m.user_id into v_other
  from public.conversation_members m
  where m.conversation_id = p_conversation
    and m.user_id <> p_user
  limit 1;

  if v_other is null then
    return false;
  end if;

  return not public.is_blocked_between(p_user, v_other);
end;
$$;

-- Última visualização com respeito à privacidade: nulo quando oculta ou sem conversa em comum.
create or replace function public.get_last_seen(p_user uuid)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_privacy text;
  v_last timestamptz;
begin
  if auth.uid() is null then
    return null;
  end if;

  select s.privacy_last_seen, s.last_seen_at into v_privacy, v_last
  from public.profile_settings s
  where s.user_id = p_user;

  if not found then
    return null;
  end if;

  if p_user = auth.uid() then
    return v_last;
  end if;

  if v_privacy = 'nobody' or not public.shares_conversation_with(p_user) then
    return null;
  end if;

  return v_last;
end;
$$;

-- ---------------------------------------------------------------------------
-- Gatilhos de mensagens
-- ---------------------------------------------------------------------------

create or replace function public.messages_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recent integer;
begin
  -- Limite de taxa: no máximo 30 mensagens por remetente em 10 segundos.
  if new.sender_id is not null then
    select count(*) into v_recent
    from public.messages m
    where m.sender_id = new.sender_id
      and m.created_at > now() - interval '10 seconds';
    if v_recent >= 30 then
      raise exception 'rate_limit_exceeded' using errcode = '53400';
    end if;
  end if;

  -- A resposta citada precisa pertencer à mesma conversa.
  if new.reply_to_id is not null then
    if not exists (
      select 1 from public.messages r
      where r.id = new.reply_to_id and r.conversation_id = new.conversation_id
    ) then
      raise exception 'reply_to_other_conversation' using errcode = '23514';
    end if;
  end if;

  new.edited_at := null;
  new.deleted_at := null;
  new.updated_at := now();
  return new;
end;
$$;

create trigger messages_before_insert
  before insert on public.messages
  for each row execute function public.messages_before_insert();

-- Regras documentadas de edição e exclusão (aplicadas ao papel `authenticated`):
--   * Só o texto (type = 'text') pode ser editado, até 15 minutos após o envio.
--   * A exclusão "para todos" é permitida até 48 horas após o envio e apaga o corpo.
--   * Mensagem excluída não pode mais ser alterada.
--   * Colunas estruturais são imutáveis.
create or replace function public.messages_before_update()
returns trigger
language plpgsql
as $$
begin
  if current_user <> 'authenticated' then
    new.updated_at := now();
    return new;
  end if;

  if new.id <> old.id
     or new.seq <> old.seq
     or new.conversation_id <> old.conversation_id
     or new.sender_id is distinct from old.sender_id
     or new.type <> old.type
     or new.reply_to_id is distinct from old.reply_to_id
     or new.forwarded <> old.forwarded
     or new.created_at <> old.created_at
     or new.edited_at is distinct from old.edited_at then
    raise exception 'immutable_column' using errcode = '42501';
  end if;

  if old.deleted_at is not null then
    raise exception 'message_already_deleted' using errcode = '42501';
  end if;

  if new.deleted_at is not null then
    if now() - old.created_at > interval '48 hours' then
      raise exception 'delete_window_expired' using errcode = '42501';
    end if;
    new.deleted_at := now();
    new.body := null;
  elsif new.body is distinct from old.body then
    if old.type <> 'text' then
      raise exception 'only_text_is_editable' using errcode = '42501';
    end if;
    if now() - old.created_at > interval '15 minutes' then
      raise exception 'edit_window_expired' using errcode = '42501';
    end if;
    new.edited_at := now();
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger messages_before_update
  before update on public.messages
  for each row execute function public.messages_before_update();

create or replace function public.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
     set last_message_id = new.id,
         last_activity_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function public.messages_after_insert();

-- ---------------------------------------------------------------------------
-- Gatilhos de recibos e anexos
-- ---------------------------------------------------------------------------

create or replace function public.message_receipts_normalize()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    -- Monotônico: um recibo nunca volta atrás.
    new.delivered_at := coalesce(old.delivered_at, new.delivered_at);
    new.read_at := coalesce(old.read_at, new.read_at);
  end if;
  if new.read_at is not null and new.delivered_at is null then
    new.delivered_at := new.read_at;
  end if;
  return new;
end;
$$;

create trigger message_receipts_normalize
  before insert or update on public.message_receipts
  for each row execute function public.message_receipts_normalize();

create or replace function public.attachments_enforce_limits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max bigint;
begin
  select l.max_bytes into v_max from public.media_limits l where l.kind = new.kind;
  if v_max is not null and new.size_bytes > v_max then
    raise exception 'attachment_too_large' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger attachments_enforce_limits
  before insert on public.attachments
  for each row execute function public.attachments_enforce_limits();

-- ---------------------------------------------------------------------------
-- RPCs chamadas pelo aplicativo
-- ---------------------------------------------------------------------------

create or replace function public.create_direct_conversation(p_other uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_key text;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_other is null or p_other = v_uid then
    raise exception 'invalid_other_user' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles where id = p_other) then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
  if public.is_blocked_between(v_uid, p_other) then
    raise exception 'blocked' using errcode = '42501';
  end if;

  v_key := least(v_uid::text, p_other::text) || ':' || greatest(v_uid::text, p_other::text);

  select id into v_id from public.conversations where direct_key = v_key;
  if v_id is not null then
    return v_id;
  end if;

  insert into public.conversations (type, direct_key, created_by)
  values ('direct', v_key, v_uid)
  on conflict (direct_key) do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.conversations where direct_key = v_key;
    return v_id;
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
  values (v_id, v_uid, 'member'), (v_id, p_other, 'member');

  return v_id;
end;
$$;

-- Marca como entregues as mensagens de outros até p_up_to_seq.
create or replace function public.mark_conversation_delivered(p_conversation uuid, p_up_to_seq bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_active_member(p_conversation, v_uid) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  insert into public.message_receipts (message_id, user_id, delivered_at)
  select m.id, v_uid, now()
  from public.messages m
  where m.conversation_id = p_conversation
    and m.seq <= p_up_to_seq
    and m.sender_id is distinct from v_uid
  on conflict (message_id, user_id) do nothing;
end;
$$;

-- Marca como lidas as mensagens de outros até p_up_to_seq.
-- Respeita a preferência de confirmação de leitura: com ela desligada, apenas
-- last_read_seq (contador local de não lidas) avança e nenhum read_at é gravado.
create or replace function public.mark_conversation_read(p_conversation uuid, p_up_to_seq bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_share boolean;
  v_prev bigint;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not public.is_active_member(p_conversation, v_uid) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  select coalesce(s.privacy_read_receipts, true) into v_share
  from public.profile_settings s where s.user_id = v_uid;
  v_share := coalesce(v_share, true);

  select last_read_seq into v_prev
  from public.conversation_members
  where conversation_id = p_conversation and user_id = v_uid;

  update public.conversation_members
     set last_read_seq = greatest(last_read_seq, p_up_to_seq)
   where conversation_id = p_conversation and user_id = v_uid;

  insert into public.message_receipts (message_id, user_id, delivered_at, read_at)
  select m.id, v_uid, now(), case when v_share then now() end
  from public.messages m
  where m.conversation_id = p_conversation
    and m.seq <= p_up_to_seq
    and m.seq > v_prev
    and m.sender_id is distinct from v_uid
  on conflict (message_id, user_id) do update
    set delivered_at = coalesce(public.message_receipts.delivered_at, excluded.delivered_at),
        read_at = coalesce(public.message_receipts.read_at, excluded.read_at);
end;
$$;

-- Registra o token FCM do aparelho. Se o token já pertencia a outro usuário
-- (aparelho compartilhado ou conta trocada), ele é reatribuído.
create or replace function public.register_device(p_token text, p_platform text default 'android', p_app_version text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  delete from public.devices where fcm_token = p_token and user_id <> v_uid;

  insert into public.devices (user_id, platform, fcm_token, app_version, last_seen_at)
  values (v_uid, p_platform, p_token, p_app_version, now())
  on conflict (fcm_token) do update
    set app_version = excluded.app_version,
        last_seen_at = now();
end;
$$;
