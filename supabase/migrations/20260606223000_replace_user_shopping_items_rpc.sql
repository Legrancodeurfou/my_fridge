-- Replace the authenticated user's shopping items atomically.

create or replace function public.replace_user_shopping_items(p_items jsonb)
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
    raise exception 'Liste de courses invalide.';
  end if;

  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  delete from public.shopping_items
  where user_id = current_user_id;

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
  from jsonb_to_recordset(p_items) as item(
    name text,
    amount numeric,
    unit text,
    is_checked boolean
  );
end;
$$;

revoke all on function public.replace_user_shopping_items(jsonb) from public;
grant execute on function public.replace_user_shopping_items(jsonb)
to authenticated;
