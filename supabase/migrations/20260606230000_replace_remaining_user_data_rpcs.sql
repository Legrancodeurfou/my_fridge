-- Replace the authenticated user's remaining synchronized data atomically.

create or replace function public.replace_user_scan_history(p_items jsonb)
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

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Historique des scans invalide.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  delete from public.scan_history
  where user_id = current_user_id;

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
  from jsonb_to_recordset(p_items) as item(
    scanned_at timestamptz,
    detected_count integer,
    validated_count integer,
    source text,
    status text,
    model text,
    products jsonb
  );
end;
$$;

revoke all on function public.replace_user_scan_history(jsonb) from public;
grant execute on function public.replace_user_scan_history(jsonb)
to authenticated;

create or replace function public.replace_user_favorite_recipes(p_items jsonb)
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

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Liste de recettes favorites invalide.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  delete from public.favorite_recipes
  where user_id = current_user_id;

  insert into public.favorite_recipes (user_id, recipe_name)
  select current_user_id, item.recipe_name
  from jsonb_to_recordset(p_items) as item(recipe_name text);
end;
$$;

revoke all on function public.replace_user_favorite_recipes(jsonb)
from public;
grant execute on function public.replace_user_favorite_recipes(jsonb)
to authenticated;

create or replace function public.replace_user_recipe_notes(p_items jsonb)
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

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Notes de recettes invalides.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  delete from public.recipe_notes
  where user_id = current_user_id;

  insert into public.recipe_notes (user_id, recipe_name, note)
  select current_user_id, item.recipe_name, item.note
  from jsonb_to_recordset(p_items) as item(
    recipe_name text,
    note text
  );
end;
$$;

revoke all on function public.replace_user_recipe_notes(jsonb) from public;
grant execute on function public.replace_user_recipe_notes(jsonb)
to authenticated;
