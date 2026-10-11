-- Testes de RLS, privilégios e regras de negócio do banco.
-- Cada bloco roda em uma transação revertida (rollback), então os testes são independentes.
-- Qualquer falha lança exceção e o runner (ON_ERROR_STOP) encerra com código != 0.

\set QUIET on
\set ON_ERROR_STOP on
\set VERBOSITY terse
\set a '00000000-0000-0000-0000-00000000000a'
\set b '00000000-0000-0000-0000-00000000000b'
\set c '00000000-0000-0000-0000-00000000000c'
\set d '00000000-0000-0000-0000-00000000000d'

-- Macros para trocar de identidade dentro de uma transação.
\set as_alice 'reset role; set local request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000a''; set local role authenticated'
\set as_bob   'reset role; set local request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000b''; set local role authenticated'
\set as_carol 'reset role; set local request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000c''; set local role authenticated'
\set as_dave  'reset role; set local request.jwt.claim.sub = ''00000000-0000-0000-0000-00000000000d''; set local role authenticated'
\set as_anon  'reset role; set local request.jwt.claim.sub = ''''; set local role anon'
\set as_admin 'reset role'

-- ===========================================================================
-- 1. Acesso anônimo
-- ===========================================================================
begin;
:as_anon;
do $$
declare t text;
begin
  foreach t in array array['profiles','profile_settings','conversations','conversation_members','messages',
                           'message_receipts','attachments','calls','devices','blocks','reports','group_events','media_limits']
  loop
    begin
      execute format('select count(*) from public.%I', t);
      raise exception 'FAIL: anon leu public.%', t;
    exception when insufficient_privilege then
      null;
    end;
  end loop;
  raise notice 'PASS: anon nao le nenhuma tabela publica';
end $$;
rollback;

-- ===========================================================================
-- 2. Isolamento entre conversas (usuário não participante)
-- ===========================================================================
begin;
:as_dave;
do $$
begin
  if (select count(*) from public.messages) <> 0 then raise exception 'FAIL: dave ve mensagens'; end if;
  if (select count(*) from public.conversations) <> 0 then raise exception 'FAIL: dave ve conversas'; end if;
  if (select count(*) from public.conversation_members) <> 0 then raise exception 'FAIL: dave ve membros'; end if;
  if (select count(*) from public.attachments) <> 0 then raise exception 'FAIL: dave ve anexos'; end if;
  if (select count(*) from public.calls) <> 0 then raise exception 'FAIL: dave ve chamadas'; end if;
  if (select count(*) from public.message_receipts) <> 0 then raise exception 'FAIL: dave ve recibos'; end if;
  if (select count(*) from storage.objects) <> 0 then raise exception 'FAIL: dave ve objetos de storage'; end if;
  raise notice 'PASS: nao participante nao consulta mensagens, membros, anexos, chamadas, recibos nem arquivos';
end $$;
rollback;

begin;
:as_carol;
do $$
begin
  -- carol está no grupo c2 mas NÃO na conversa direta c1.
  if (select count(*) from public.messages where conversation_id = '00000000-0000-0000-0000-0000000000c1') <> 0 then
    raise exception 'FAIL: carol le mensagens da conversa direta alheia';
  end if;
  if (select count(*) from public.messages where conversation_id = '00000000-0000-0000-0000-0000000000c2') <> 1 then
    raise exception 'FAIL: carol deveria ler o grupo do qual participa';
  end if;
  begin
    insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'intruso');
    raise exception 'FAIL: carol enviou em conversa alheia';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.mark_conversation_read('00000000-0000-0000-0000-0000000000c1', 999);
    raise exception 'FAIL: carol marcou como lida conversa alheia';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: nao membro nao le nem escreve em conversa alheia (RLS + RPC)';
end $$;
rollback;

-- ===========================================================================
-- 3. Mensagens: envio, identidade, idempotência, colunas protegidas
-- ===========================================================================
begin;
:as_alice;
do $$
declare
  v_id uuid := '00000000-0000-0000-0000-0000000000aa';
  v_last uuid;
begin
  insert into public.messages (id, conversation_id, body)
  values (v_id, '00000000-0000-0000-0000-0000000000c1', 'ola');
  if not exists (select 1 from public.messages where id = v_id and sender_id = auth.uid()) then
    raise exception 'FAIL: remetente deveria vir de auth.uid()';
  end if;
  select last_message_id into v_last from public.conversations where id = '00000000-0000-0000-0000-0000000000c1';
  if v_last is distinct from v_id then raise exception 'FAIL: last_message_id nao atualizado'; end if;
  raise notice 'PASS: envio ok, remetente derivado do JWT e ultima mensagem atualizada';

  begin
    insert into public.messages (id, conversation_id, body)
    values (v_id, '00000000-0000-0000-0000-0000000000c1', 'ola de novo');
    raise exception 'FAIL: id duplicado deveria ser rejeitado';
  exception when unique_violation then
    raise notice 'PASS: reenvio com mesmo id e rejeitado (idempotencia)';
  end;

  begin
    insert into public.messages (conversation_id, sender_id, body)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000b', 'sou o bob');
    raise exception 'FAIL: alice se passou por bob';
  exception when insufficient_privilege then
    raise notice 'PASS: nao e possivel forjar sender_id';
  end;

  begin
    insert into public.messages (conversation_id, type, body)
    values ('00000000-0000-0000-0000-0000000000c1', 'system', 'aviso falso');
    raise exception 'FAIL: cliente criou mensagem de sistema';
  exception when insufficient_privilege then
    raise notice 'PASS: cliente nao cria mensagens de sistema';
  end;

  begin
    insert into public.messages (conversation_id, body, created_at)
    values ('00000000-0000-0000-0000-0000000000c1', 'viagem no tempo', now() - interval '1 year');
    raise exception 'FAIL: cliente definiu created_at';
  exception when insufficient_privilege then
    raise notice 'PASS: cliente nao define created_at';
  end;

  begin
    insert into public.messages (conversation_id, body, reply_to_id)
    values ('00000000-0000-0000-0000-0000000000c1', 'resposta cruzada', '00000000-0000-0000-0000-0000000000f1');
    raise exception 'FAIL: resposta a mensagem de outra conversa aceita';
  exception when check_violation then
    raise notice 'PASS: resposta citada precisa ser da mesma conversa';
  end;

  insert into public.messages (conversation_id, body, reply_to_id)
  values ('00000000-0000-0000-0000-0000000000c1', 'resposta valida', '00000000-0000-0000-0000-0000000000e2');
  raise notice 'PASS: resposta citada na mesma conversa';
end $$;
rollback;

-- Limite de taxa
begin;
:as_alice;
do $$
declare i int;
begin
  begin
    for i in 1..31 loop
      insert into public.messages (conversation_id, body)
      values ('00000000-0000-0000-0000-0000000000c1', 'spam ' || i);
    end loop;
    raise exception 'FAIL: limite de taxa nao aplicado';
  exception when configuration_limit_exceeded then
    raise notice 'PASS: limite de 30 mensagens por 10 s aplicado';
  end;
end $$;
rollback;

-- ===========================================================================
-- 4. Edição e exclusão (regras documentadas)
-- ===========================================================================
begin;
:as_alice;
do $$
declare n int;
begin
  update public.messages set body = 'oi bob (editado)' where id = '00000000-0000-0000-0000-0000000000e1';
  if not exists (select 1 from public.messages
                  where id = '00000000-0000-0000-0000-0000000000e1' and edited_at is not null
                    and body = 'oi bob (editado)') then
    raise exception 'FAIL: edicao dentro da janela deveria marcar edited_at';
  end if;
  raise notice 'PASS: edicao propria dentro de 15 min marca edited_at';

  begin
    update public.messages set body = 'tarde demais' where id = '00000000-0000-0000-0000-0000000000e3';
    raise exception 'FAIL: edicao apos 15 min aceita';
  exception when insufficient_privilege then
    raise notice 'PASS: edicao apos 15 minutos e bloqueada';
  end;

  update public.messages set deleted_at = now() where id = '00000000-0000-0000-0000-0000000000e3';
  if not exists (select 1 from public.messages
                  where id = '00000000-0000-0000-0000-0000000000e3' and deleted_at is not null and body is null) then
    raise exception 'FAIL: exclusao para todos deveria apagar o corpo';
  end if;
  raise notice 'PASS: exclusao para todos apaga o corpo (dentro de 48h)';

  begin
    update public.messages set body = 'ressuscitei' where id = '00000000-0000-0000-0000-0000000000e3';
    raise exception 'FAIL: mensagem excluida foi alterada';
  exception when insufficient_privilege then
    raise notice 'PASS: mensagem excluida nao pode ser alterada';
  end;

  begin
    update public.messages set deleted_at = now() where id = '00000000-0000-0000-0000-0000000000e4';
    raise exception 'FAIL: exclusao apos 48h aceita';
  exception when insufficient_privilege then
    raise notice 'PASS: exclusao para todos apos 48 horas e bloqueada';
  end;

  begin
    update public.messages set sender_id = '00000000-0000-0000-0000-00000000000b'
     where id = '00000000-0000-0000-0000-0000000000e1';
    raise exception 'FAIL: sender_id alterado';
  exception when insufficient_privilege then
    raise notice 'PASS: colunas estruturais nao sao atualizaveis pelo cliente';
  end;
end $$;
:as_bob;
do $$
declare n int;
begin
  update public.messages set body = 'hackeado' where id = '00000000-0000-0000-0000-0000000000e1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: bob editou mensagem da alice'; end if;
  update public.messages set deleted_at = now() where id = '00000000-0000-0000-0000-0000000000e1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: bob excluiu mensagem da alice'; end if;
  raise notice 'PASS: so o remetente edita/exclui a propria mensagem';
end $$;
rollback;

-- ===========================================================================
-- 5. Bloqueio de usuários
-- ===========================================================================
begin;
:as_bob;
insert into public.blocks (blocker_id, blocked_id)
values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
do $$
begin
  begin
    insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'ainda falo?');
    raise exception 'FAIL: bloqueador enviou para bloqueado';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: bloqueador tambem nao envia ao bloqueado';
end $$;
:as_alice;
do $$
begin
  begin
    insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'me desbloqueie');
    raise exception 'FAIL: bloqueado conseguiu enviar';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_direct_conversation('00000000-0000-0000-0000-00000000000b');
    -- conversa já existe: retorno do id existente é aceitável apenas se não houver bloqueio
    raise exception 'FAIL: bloqueado reabriu conversa';
  exception when insufficient_privilege then null;
  end;
  if (select count(*) from public.blocks) <> 0 then raise exception 'FAIL: bloqueado enxerga o bloqueio'; end if;
  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/blk.jpg', 'image', 'image/jpeg', 10);
    raise exception 'FAIL: bloqueado registrou anexo';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: bloqueio impede mensagens, nova conversa e anexos; bloqueado nao ve o bloqueio';
end $$;
:as_carol;
do $$
begin
  begin
    insert into public.blocks (blocker_id, blocked_id)
    values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c');
    raise exception 'FAIL: carol criou bloqueio em nome da alice';
  exception when insufficient_privilege then
    raise notice 'PASS: nao e possivel criar bloqueio em nome de outro usuario';
  end;
end $$;
:as_bob;
delete from public.blocks where blocked_id = '00000000-0000-0000-0000-00000000000a';
:as_alice;
do $$
begin
  insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c1', 'voltamos');
  raise notice 'PASS: apos desbloquear o envio volta a funcionar';
end $$;
rollback;

-- ===========================================================================
-- 6. Grupos: permissões e remoção de membro
-- ===========================================================================
begin;
reset role;
update public.conversations set only_admins_can_send = true where id = '00000000-0000-0000-0000-0000000000c2';
:as_bob;
do $$
begin
  begin
    insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c2', 'posso?');
    raise exception 'FAIL: membro comum enviou em grupo restrito a admins';
  exception when insufficient_privilege then null;
  end;
end $$;
:as_alice;
do $$
begin
  insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c2', 'aviso do admin');
  raise notice 'PASS: grupo restrito a admins bloqueia membro comum e permite admin';
end $$;
rollback;

begin;
reset role;
update public.conversation_members set left_at = now()
 where conversation_id = '00000000-0000-0000-0000-0000000000c2' and user_id = '00000000-0000-0000-0000-00000000000c';
:as_carol;
do $$
begin
  if (select count(*) from public.messages where conversation_id = '00000000-0000-0000-0000-0000000000c2') <> 0 then
    raise exception 'FAIL: membro removido ainda le mensagens do grupo';
  end if;
  if (select count(*) from public.conversations where id = '00000000-0000-0000-0000-0000000000c2') <> 0 then
    raise exception 'FAIL: membro removido ainda ve a conversa';
  end if;
  if (select count(*) from public.conversation_members where conversation_id = '00000000-0000-0000-0000-0000000000c2') <> 1 then
    raise exception 'FAIL: membro removido ve a lista de participantes';
  end if;
  begin
    insert into public.messages (conversation_id, body) values ('00000000-0000-0000-0000-0000000000c2', 'ainda estou aqui');
    raise exception 'FAIL: membro removido enviou mensagem';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.conversation_members set role = 'owner'
     where conversation_id = '00000000-0000-0000-0000-0000000000c2' and user_id = '00000000-0000-0000-0000-00000000000c';
    raise exception 'FAIL: usuario alterou o proprio papel';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: membro removido perde leitura e escrita; nao altera o proprio papel';
end $$;
rollback;

begin;
:as_bob;
do $$
declare n int;
begin
  begin
    update public.conversation_members set role = 'admin'
     where conversation_id = '00000000-0000-0000-0000-0000000000c2' and user_id = '00000000-0000-0000-0000-00000000000b';
    raise exception 'FAIL: membro se promoveu a admin';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.conversation_members (conversation_id, user_id)
    values ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000d');
    raise exception 'FAIL: membro adicionou participante diretamente';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.conversations set title = 'sequestrado' where id = '00000000-0000-0000-0000-0000000000c2';
    raise exception 'FAIL: cliente alterou conversa';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: cliente nao se promove, nao adiciona membros nem edita grupo (so via backend)';
end $$;
rollback;

-- ===========================================================================
-- 7. Conversas diretas via RPC
-- ===========================================================================
begin;
:as_alice;
do $$
declare v1 uuid; v2 uuid; v3 uuid;
begin
  v1 := public.create_direct_conversation('00000000-0000-0000-0000-00000000000b');
  if v1 <> '00000000-0000-0000-0000-0000000000c1' then raise exception 'FAIL: deveria reutilizar a conversa existente'; end if;
  v2 := public.create_direct_conversation('00000000-0000-0000-0000-00000000000c');
  v3 := public.create_direct_conversation('00000000-0000-0000-0000-00000000000c');
  if v2 <> v3 then raise exception 'FAIL: conversa duplicada para o mesmo par'; end if;
  if (select count(*) from public.conversation_members where conversation_id = v2) <> 2 then
    raise exception 'FAIL: conversa direta deve ter 2 membros';
  end if;
  begin
    perform public.create_direct_conversation('00000000-0000-0000-0000-00000000000a');
    raise exception 'FAIL: conversa consigo mesmo';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.create_direct_conversation('00000000-0000-0000-0000-0000000000ff');
    raise exception 'FAIL: usuario inexistente aceito';
  exception when no_data_found then null;
  end;
  raise notice 'PASS: create_direct_conversation e idempotente, valida alvo e impede duplicatas';
end $$;
:as_bob;
do $$
begin
  if public.create_direct_conversation('00000000-0000-0000-0000-00000000000a') <> '00000000-0000-0000-0000-0000000000c1' then
    raise exception 'FAIL: ordem dos usuarios altera a conversa';
  end if;
  raise notice 'PASS: mesma conversa independente de quem inicia';
end $$;
rollback;

-- ===========================================================================
-- 8. Recibos de entrega e leitura
-- ===========================================================================
begin;
:as_bob;
do $$
declare v_max bigint;
begin
  select max(seq) into v_max from public.messages where conversation_id = '00000000-0000-0000-0000-0000000000c1';
  perform public.mark_conversation_read('00000000-0000-0000-0000-0000000000c1', v_max);
  if (select last_read_seq from public.conversation_members
       where conversation_id = '00000000-0000-0000-0000-0000000000c1' and user_id = auth.uid()) <> v_max then
    raise exception 'FAIL: last_read_seq nao avancou';
  end if;
  if (select count(*) from public.message_receipts where user_id = auth.uid() and read_at is not null) <> 3 then
    raise exception 'FAIL: esperava 3 recibos de leitura (mensagens da alice)';
  end if;
  begin
    update public.message_receipts set read_at = null, delivered_at = null where user_id = auth.uid();
    if (select count(*) from public.message_receipts where user_id = auth.uid() and read_at is null) <> 0 then
      raise exception 'FAIL: recibo regrediu';
    end if;
  end;
  raise notice 'PASS: leitura gera recibos so para mensagens de outros e nunca regride';
end $$;
:as_alice;
do $$
begin
  if (select count(*) from public.message_receipts) <> 3 then raise exception 'FAIL: remetente deveria ver os 3 recibos'; end if;
  begin
    insert into public.message_receipts (message_id, user_id, read_at)
    values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-00000000000a', now());
    raise exception 'FAIL: remetente criou recibo da propria mensagem';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.message_receipts (message_id, user_id, read_at)
    values ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-00000000000b', now());
    raise exception 'FAIL: recibo criado em nome de outro usuario';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: remetente ve recibos; ninguem forja recibo de outro';
end $$;
:as_carol;
do $$
begin
  if (select count(*) from public.message_receipts) <> 0 then raise exception 'FAIL: terceiro ve recibos'; end if;
  raise notice 'PASS: terceiros nao veem recibos';
end $$;
rollback;

begin;
reset role;
update public.profile_settings set privacy_read_receipts = false where user_id = '00000000-0000-0000-0000-00000000000b';
:as_bob;
do $$
declare v_max bigint;
begin
  select max(seq) into v_max from public.messages where conversation_id = '00000000-0000-0000-0000-0000000000c1';
  perform public.mark_conversation_read('00000000-0000-0000-0000-0000000000c1', v_max);
end $$;
reset role;
do $$
begin
  if (select count(*) from public.message_receipts where read_at is not null) <> 0 then
    raise exception 'FAIL: read_at gravado apesar da privacidade desligada';
  end if;
  if (select count(*) from public.message_receipts where delivered_at is not null) <> 3 then
    raise exception 'FAIL: entrega deveria ser registrada';
  end if;
  if (select last_read_seq from public.conversation_members
       where conversation_id = '00000000-0000-0000-0000-0000000000c1'
         and user_id = '00000000-0000-0000-0000-00000000000b') = 0 then
    raise exception 'FAIL: contador local de leitura deveria avancar';
  end if;
  raise notice 'PASS: com confirmacao de leitura desligada nao ha read_at, mas o contador de nao lidas avanca';
end $$;
rollback;

-- ===========================================================================
-- 9. Anexos e Storage
-- ===========================================================================
begin;
:as_alice;
do $$
begin
  insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
  values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/ok.jpg', 'image', 'image/jpeg', 2048);
  raise notice 'PASS: membro registra anexo valido';

  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/mal.exe', 'document', 'application/x-msdownload', 10);
    raise exception 'FAIL: tipo nao permitido aceito';
  exception when check_violation then
    raise notice 'PASS: tipo MIME fora da lista e rejeitado';
  end;

  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/x.jpg', 'image', 'video/mp4', 10);
    raise exception 'FAIL: kind/mime divergentes aceitos';
  exception when check_violation then
    raise notice 'PASS: kind e MIME precisam ser coerentes';
  end;

  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/big.jpg', 'image', 'image/jpeg', 30000000);
    raise exception 'FAIL: arquivo acima do limite aceito';
  exception when check_violation then
    raise notice 'PASS: limite de tamanho por tipo aplicado (imagem > 20 MiB rejeitada)';
  end;

  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2/escape.jpg', 'image', 'image/jpeg', 10);
    raise exception 'FAIL: caminho fora da pasta da conversa aceito';
  exception when check_violation then
    raise notice 'PASS: caminho precisa estar na pasta da conversa';
  end;
end $$;
:as_carol;
do $$
begin
  if (select count(*) from public.attachments) <> 0 then raise exception 'FAIL: carol ve anexos da conversa direta'; end if;
  begin
    insert into public.attachments (conversation_id, storage_path, kind, mime_type, size_bytes)
    values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1/c.jpg', 'image', 'image/jpeg', 10);
    raise exception 'FAIL: carol registrou anexo em conversa alheia';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: nao membro nao ve nem cria anexos';
end $$;
rollback;

begin;
:as_bob;
do $$
begin
  if (select count(*) from storage.objects where bucket_id = 'chat-media') <> 1 then
    raise exception 'FAIL: participante deveria ver o objeto da conversa';
  end if;
end $$;
:as_carol;
do $$
begin
  if (select count(*) from storage.objects) <> 0 then raise exception 'FAIL: nao participante ve arquivo privado'; end if;
  begin
    insert into storage.objects (bucket_id, name)
    values ('chat-media', '00000000-0000-0000-0000-0000000000c1/pending.jpg');
    raise exception 'FAIL: nao participante enviou arquivo para a conversa';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: arquivos privados respeitam a participacao na conversa';
end $$;
:as_alice;
do $$
begin
  insert into storage.objects (bucket_id, name)
  values ('chat-media', '00000000-0000-0000-0000-0000000000c1/pending.jpg');
  begin
    insert into storage.objects (bucket_id, name)
    values ('chat-media', '00000000-0000-0000-0000-0000000000c1/sem-metadado.jpg');
    raise exception 'FAIL: upload sem metadado registrado aceito';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: upload exige metadado previo em attachments';
end $$;
:as_bob;
do $$
begin
  begin
    insert into storage.objects (bucket_id, name)
    values ('chat-media', '00000000-0000-0000-0000-0000000000c1/pending.jpg');
    raise exception 'FAIL: bob enviou arquivo registrado pela alice';
  exception when insufficient_privilege then
    raise notice 'PASS: so o dono do anexo pendente envia o arquivo';
  end;
end $$;
rollback;

-- ===========================================================================
-- 10. Chamadas
-- ===========================================================================
begin;
:as_alice;
do $$
begin
  if (select count(*) from public.calls) <> 1 then raise exception 'FAIL: participante deveria ver a chamada'; end if;
  begin
    insert into public.calls (conversation_id, caller_id, callee_id, kind, room_name)
    values ('00000000-0000-0000-0000-0000000000c1', auth.uid(), '00000000-0000-0000-0000-00000000000b', 'video', 'room-x');
    raise exception 'FAIL: cliente criou chamada diretamente';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.calls set status = 'accepted';
    raise exception 'FAIL: cliente alterou chamada';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: chamadas so podem ser lidas pelos participantes; escrita apenas via backend';
end $$;
:as_carol;
do $$
begin
  if (select count(*) from public.calls) <> 0 then raise exception 'FAIL: terceiro ve chamadas'; end if;
  raise notice 'PASS: terceiros nao veem chamadas';
end $$;
rollback;

-- ===========================================================================
-- 11. Dispositivos, denúncias e perfis
-- ===========================================================================
begin;
:as_alice;
select public.register_device('token-fcm-aaaaaaaaaaaaaaaaaaaaaaaa', 'android', '0.1.0');
:as_bob;
select public.register_device('token-fcm-aaaaaaaaaaaaaaaaaaaaaaaa', 'android', '0.1.0');
do $$
begin
  if (select count(*) from public.devices) <> 1 then raise exception 'FAIL: bob deveria ter 1 dispositivo'; end if;
end $$;
:as_alice;
do $$
begin
  if (select count(*) from public.devices) <> 0 then raise exception 'FAIL: token continuou com a alice'; end if;
  begin
    insert into public.devices (user_id, fcm_token) values (auth.uid(), 'direto-sem-rpc-aaaaaaaaaaaaaaaaaaaa');
    raise exception 'FAIL: insert direto em devices';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: token FCM e reatribuido ao usuario atual e nao vaza para o anterior';
end $$;
rollback;

begin;
:as_bob;
do $$
begin
  insert into public.reports (message_id, reason) values ('00000000-0000-0000-0000-0000000000e1', 'abuse');
  begin
    insert into public.reports (reporter_id, message_id, reason)
    values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000e1', 'abuse');
    raise exception 'FAIL: denuncia em nome de outro usuario';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS: usuario denuncia mensagens que consegue ler, so em nome proprio';
end $$;
:as_carol;
do $$
begin
  begin
    insert into public.reports (message_id, reason) values ('00000000-0000-0000-0000-0000000000e1', 'spam');
    raise exception 'FAIL: denuncia de mensagem que carol nao pode ler';
  exception when insufficient_privilege then
    raise notice 'PASS: nao e possivel denunciar conteudo ao qual nao se tem acesso';
  end;
  if (select count(*) from public.reports) <> 0 then raise exception 'FAIL: carol ve denuncias alheias'; end if;
end $$;
rollback;

begin;
:as_dave;
do $$
declare n int;
begin
  if (select count(*) from public.profiles) <> 1 then raise exception 'FAIL: dave deveria ver somente o proprio perfil'; end if;
  update public.profiles set display_name = 'Dave 2' where id = auth.uid();
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL: dave nao atualizou o proprio perfil'; end if;
  update public.profiles set display_name = 'sequestrado' where id = '00000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL: dave alterou perfil alheio'; end if;
  begin
    update public.profiles set id = gen_random_uuid() where id = auth.uid();
    raise exception 'FAIL: id do perfil alterado';
  exception when insufficient_privilege then null;
  end;
  if (select count(*) from public.profile_settings) <> 1 then raise exception 'FAIL: configuracoes de outros visiveis'; end if;
  raise notice 'PASS: perfil visivel so para si e co-participantes; edicao apenas do proprio';
end $$;
:as_alice;
do $$
begin
  if (select count(*) from public.profiles where id = '00000000-0000-0000-0000-00000000000b') <> 1 then
    raise exception 'FAIL: alice deveria ver o perfil do bob (conversa em comum)';
  end if;
  if (select count(*) from public.profile_settings where user_id = '00000000-0000-0000-0000-00000000000b') <> 0 then
    raise exception 'FAIL: alice le configuracoes privadas do bob';
  end if;
  raise notice 'PASS: co-participantes veem perfil mas nao configuracoes privadas';
end $$;
rollback;

begin;
reset role;
update public.profile_settings set last_seen_at = now() where user_id = '00000000-0000-0000-0000-00000000000b';
:as_alice;
do $$
begin
  if public.get_last_seen('00000000-0000-0000-0000-00000000000b') is null then
    raise exception 'FAIL: ultima visualizacao deveria estar visivel a co-participante';
  end if;
end $$;
:as_dave;
do $$
begin
  if public.get_last_seen('00000000-0000-0000-0000-00000000000b') is not null then
    raise exception 'FAIL: estranho ve ultima visualizacao';
  end if;
end $$;
reset role;
update public.profile_settings set privacy_last_seen = 'nobody' where user_id = '00000000-0000-0000-0000-00000000000b';
:as_alice;
do $$
begin
  if public.get_last_seen('00000000-0000-0000-0000-00000000000b') is not null then
    raise exception 'FAIL: privacidade "nobody" ignorada';
  end if;
  raise notice 'PASS: ultima visualizacao respeita privacidade e participacao em conversa';
end $$;
rollback;

\echo ALL_TESTS_COMPLETED
