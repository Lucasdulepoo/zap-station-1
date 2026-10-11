-- ZAP STATION — migração 0007: bucket privado de mídia e publicação Realtime

-- Bucket privado. Objetos ficam em "<conversation_id>/<attachment_id>[.ext]".
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media', 'chat-media', false, 104857600,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic',
    'video/mp4', 'video/quicktime', 'video/webm',
    'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/opus', 'audio/webm', 'audio/x-m4a',
    'application/pdf', 'application/zip', 'text/plain'
  ]
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Leitura: apenas participantes ativos da conversa dona da pasta.
create policy chat_media_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-media'
    and public.is_active_member(public.try_uuid((storage.foldername(name))[1]))
  );

-- Envio: só quem pode enviar na conversa E que já registrou o metadado em
-- public.attachments (garante validação de tipo/tamanho e rastreio de órfãos).
create policy chat_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.can_send_message(public.try_uuid((storage.foldername(name))[1]))
    and exists (
      select 1 from public.attachments a
      where a.storage_path = name
        and a.owner_id = auth.uid()
        and a.message_id is null
    )
  );

-- Remoção pelo cliente: apenas upload ainda pendente (cancelamento).
create policy chat_media_delete_pending on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'chat-media'
    and exists (
      select 1 from public.attachments a
      where a.storage_path = name
        and a.owner_id = auth.uid()
        and a.message_id is null
    )
  );

-- Realtime respeita RLS nas mudanças de Postgres.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime
      add table public.messages, public.message_receipts, public.conversation_members, public.calls;
  end if;
end;
$$;
