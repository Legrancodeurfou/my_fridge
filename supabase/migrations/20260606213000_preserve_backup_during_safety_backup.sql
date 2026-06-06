-- Preserve a selected backup while creating the safety backup that precedes
-- its restoration. The trigger still keeps at most three rows per user.

create or replace function public.prune_cloud_backups()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  preserved_backup_id uuid := nullif(
    current_setting('my_fridge.preserve_backup_id', true),
    ''
  )::uuid;
begin
  perform pg_advisory_xact_lock(hashtext(new.user_id::text));

  delete from public.cloud_backups
  where user_id = new.user_id
    and id not in (
      select id
      from public.cloud_backups
      where user_id = new.user_id
      order by
        case when id = preserved_backup_id then 0 else 1 end,
        created_at desc,
        id desc
      limit 3
    );

  return new;
end;
$$;

create or replace function public.create_cloud_backup(
  p_reason text,
  p_payload jsonb,
  p_preserve_backup_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  created_backup public.cloud_backups;
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecté.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  if jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Payload de sauvegarde invalide.';
  end if;

  if p_preserve_backup_id is not null and not exists (
    select 1
    from public.cloud_backups
    where id = p_preserve_backup_id
      and user_id = current_user_id
  ) then
    raise exception 'Sauvegarde à préserver introuvable.';
  end if;

  perform set_config(
    'my_fridge.preserve_backup_id',
    coalesce(p_preserve_backup_id::text, ''),
    true
  );

  insert into public.cloud_backups (user_id, reason, payload)
  values (
    current_user_id,
    coalesce(nullif(trim(p_reason), ''), 'Sauvegarde manuelle'),
    p_payload
  )
  returning * into created_backup;

  return jsonb_build_object(
    'id', created_backup.id,
    'created_at', created_backup.created_at,
    'reason', created_backup.reason
  );
end;
$$;

revoke all on function public.create_cloud_backup(text, jsonb, uuid)
from public;
grant execute on function public.create_cloud_backup(text, jsonb, uuid)
to authenticated;
