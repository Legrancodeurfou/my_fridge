-- My Fridge - restorable cloud backups
-- Run this migration in the Supabase SQL Editor before using the backup UI.

create table if not exists public.cloud_backups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  reason text not null default 'Sauvegarde manuelle',
  payload jsonb not null default '{}'::jsonb,
  check (jsonb_typeof(payload) = 'object')
);

create index if not exists cloud_backups_user_created_at_idx
on public.cloud_backups(user_id, created_at desc);

delete from public.cloud_backups
where id in (
  select id
  from (
    select
      id,
      row_number() over (
        partition by user_id
        order by created_at desc, id desc
      ) as backup_rank
    from public.cloud_backups
  ) ranked_backups
  where backup_rank > 3
);

alter table public.cloud_backups enable row level security;

drop policy if exists "Users can read their cloud backups"
on public.cloud_backups;
create policy "Users can read their cloud backups"
on public.cloud_backups for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert their cloud backups"
on public.cloud_backups;
create policy "Users can insert their cloud backups"
on public.cloud_backups for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update their cloud backups"
on public.cloud_backups;
create policy "Users can update their cloud backups"
on public.cloud_backups for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their cloud backups"
on public.cloud_backups;
create policy "Users can delete their cloud backups"
on public.cloud_backups for delete
using (auth.uid() = user_id);

create or replace function public.prune_cloud_backups()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.user_id::text));

  delete from public.cloud_backups
  where id in (
    select id
    from public.cloud_backups
    where user_id = new.user_id
    order by created_at desc, id desc
    offset 3
  );

  return new;
end;
$$;

drop trigger if exists cloud_backups_keep_latest_three
on public.cloud_backups;
create trigger cloud_backups_keep_latest_three
after insert on public.cloud_backups
for each row execute function public.prune_cloud_backups();

create or replace function public.restore_cloud_backup(p_backup_id uuid)
returns void
language plpgsql
set search_path = public
as $$
declare
  backup_payload jsonb;
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecté.';
  end if;

  select payload
  into backup_payload
  from public.cloud_backups
  where id = p_backup_id
    and user_id = current_user_id;

  if backup_payload is null then
    raise exception 'Sauvegarde introuvable.';
  end if;

  delete from public.foods where user_id = current_user_id;
  delete from public.shopping_items where user_id = current_user_id;
  delete from public.scan_history where user_id = current_user_id;
  delete from public.favorite_recipes where user_id = current_user_id;
  delete from public.recipe_notes where user_id = current_user_id;

  insert into public.foods (
    user_id,
    name,
    emoji,
    category,
    quantity,
    amount,
    unit,
    expiration_date
  )
  select
    current_user_id,
    item.name,
    item.emoji,
    item.category,
    item.quantity,
    item.amount,
    item.unit,
    item.expiration_date
  from jsonb_to_recordset(
    coalesce(backup_payload -> 'foods', '[]'::jsonb)
  ) as item(
    name text,
    emoji text,
    category text,
    quantity integer,
    amount numeric,
    unit text,
    expiration_date date
  );

  insert into public.shopping_items (
    user_id,
    name,
    amount,
    unit,
    is_checked
  )
  select
    current_user_id,
    item.name,
    item.amount,
    item.unit,
    item.is_checked
  from jsonb_to_recordset(
    coalesce(backup_payload -> 'shopping_items', '[]'::jsonb)
  ) as item(
    name text,
    amount numeric,
    unit text,
    is_checked boolean
  );

  insert into public.scan_history (
    user_id,
    scanned_at,
    detected_count,
    validated_count,
    source,
    status,
    model,
    products
  )
  select
    current_user_id,
    item.scanned_at,
    item.detected_count,
    item.validated_count,
    item.source,
    item.status,
    item.model,
    item.products
  from jsonb_to_recordset(
    coalesce(backup_payload -> 'scan_history', '[]'::jsonb)
  ) as item(
    scanned_at timestamptz,
    detected_count integer,
    validated_count integer,
    source text,
    status text,
    model text,
    products jsonb
  );

  insert into public.favorite_recipes (user_id, recipe_name)
  select current_user_id, item.recipe_name
  from jsonb_to_recordset(
    coalesce(backup_payload -> 'favorite_recipes', '[]'::jsonb)
  ) as item(recipe_name text);

  insert into public.recipe_notes (user_id, recipe_name, note)
  select current_user_id, item.recipe_name, item.note
  from jsonb_to_recordset(
    coalesce(backup_payload -> 'recipe_notes', '[]'::jsonb)
  ) as item(recipe_name text, note text);
end;
$$;

revoke all on function public.restore_cloud_backup(uuid) from public;
grant execute on function public.restore_cloud_backup(uuid) to authenticated;
grant select, insert, update, delete on table public.cloud_backups to authenticated;
grant execute on function public.restore_cloud_backup(uuid) to authenticated;
