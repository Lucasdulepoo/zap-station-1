-- Fixtures determinísticas. Executadas como superusuário (ignoram RLS).
--   alice (a), bob (b), carol (c), dave (d)
--   c1: conversa direta alice-bob
--   c2: grupo "G" — alice (owner), bob (member), carol (member); dave NÃO é membro

insert into auth.users (id, phone) values
  ('00000000-0000-0000-0000-00000000000a', '+5511900000001'),
  ('00000000-0000-0000-0000-00000000000b', '+5511900000002'),
  ('00000000-0000-0000-0000-00000000000c', '+5511900000003'),
  ('00000000-0000-0000-0000-00000000000d', '+5511900000004');

update public.profiles set display_name = 'Alice' where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'Bob'   where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set display_name = 'Carol' where id = '00000000-0000-0000-0000-00000000000c';
update public.profiles set display_name = 'Dave'  where id = '00000000-0000-0000-0000-00000000000d';

insert into public.conversations (id, type, direct_key, created_by) values (
  '00000000-0000-0000-0000-0000000000c1', 'direct',
  least('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')
    || ':' ||
  greatest('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'),
  '00000000-0000-0000-0000-00000000000a');

insert into public.conversations (id, type, title, created_by) values (
  '00000000-0000-0000-0000-0000000000c2', 'group', 'G', '00000000-0000-0000-0000-00000000000a');

insert into public.conversation_members (conversation_id, user_id, role) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'member'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000b', 'member'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a', 'owner'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000b', 'member'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000c', 'member');

insert into public.messages (id, conversation_id, sender_id, body) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'oi bob'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000b', 'oi alice'),
  ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'mensagem de 20 minutos atras'),
  ('00000000-0000-0000-0000-0000000000e4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a', 'mensagem de 3 dias atras'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a', 'bem-vindos ao grupo');

update public.messages set created_at = now() - interval '20 minutes'
 where id = '00000000-0000-0000-0000-0000000000e3';
update public.messages set created_at = now() - interval '3 days'
 where id = '00000000-0000-0000-0000-0000000000e4';

-- Anexo pronto (já vinculado a nenhuma mensagem) + objeto no Storage.
insert into public.attachments (id, conversation_id, owner_id, storage_path, kind, mime_type, size_bytes, status) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000c1/fixture.jpg', 'image', 'image/jpeg', 1000, 'ready'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000c1/pending.jpg', 'image', 'image/jpeg', 1000, 'uploading');

insert into storage.objects (bucket_id, name, owner) values
  ('chat-media', '00000000-0000-0000-0000-0000000000c1/fixture.jpg', '00000000-0000-0000-0000-00000000000a');

-- Chamada alice -> bob.
insert into public.calls (id, conversation_id, caller_id, callee_id, kind, room_name) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'voice', 'room-fixture-1');
