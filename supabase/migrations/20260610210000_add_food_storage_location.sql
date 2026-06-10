-- Add stock locations without changing existing foods.

alter table public.foods
add column if not exists storage_location text;

update public.foods
set storage_location = 'fridge'
where storage_location is null
   or storage_location not in ('fridge', 'freezer', 'pantry', 'spices');

alter table public.foods
alter column storage_location set default 'fridge';

alter table public.foods
alter column storage_location set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'foods_storage_location_check'
      and conrelid = 'public.foods'::regclass
  ) then
    alter table public.foods
    add constraint foods_storage_location_check
    check (storage_location in ('fridge', 'freezer', 'pantry', 'spices'));
  end if;
end;
$$;

create or replace function public.replace_user_foods(p_foods jsonb)
returns void
language plpgsql
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Utilisateur non connecté.';
  end if;

  if p_foods is null or jsonb_typeof(p_foods) <> 'array' then
    raise exception 'Liste d''aliments invalide.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  delete from public.foods
  where user_id = current_user_id;

  insert into public.foods (
    user_id,
    name,
    emoji,
    category,
    storage_location,
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
    coalesce(item.storage_location, 'fridge'),
    item.quantity,
    item.amount,
    item.unit,
    item.expiration_date
  from jsonb_to_recordset(p_foods) as item(
    name text,
    emoji text,
    category text,
    storage_location text,
    quantity integer,
    amount numeric,
    unit text,
    expiration_date date
  );
end;
$$;

revoke all on function public.replace_user_foods(jsonb) from public;
grant execute on function public.replace_user_foods(jsonb) to authenticated;

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
    storage_location,
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
    coalesce(item.storage_location, 'fridge'),
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
    storage_location text,
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
