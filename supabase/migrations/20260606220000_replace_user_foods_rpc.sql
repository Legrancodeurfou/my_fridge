-- Replace the authenticated user's foods atomically.

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
  from jsonb_to_recordset(p_foods) as item(
    name text,
    emoji text,
    category text,
    quantity integer,
    amount numeric,
    unit text,
    expiration_date date
  );
end;
$$;

revoke all on function public.replace_user_foods(jsonb) from public;
grant execute on function public.replace_user_foods(jsonb) to authenticated;
