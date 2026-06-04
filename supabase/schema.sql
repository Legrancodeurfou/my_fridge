-- My Fridge - Supabase schema MVP
-- À exécuter dans Supabase SQL Editor.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Users / profile cloud minimal
-- ---------------------------------------------------------------------------

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Foods
-- ---------------------------------------------------------------------------

create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  emoji text not null default '🍽️',
  category text not null default 'other',
  quantity integer not null default 1 check (quantity >= 1),
  amount numeric not null default 1 check (amount > 0),
  unit text not null default 'unité',
  expiration_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists foods_user_id_idx on public.foods(user_id);
create index if not exists foods_expiration_date_idx on public.foods(expiration_date);

create trigger foods_set_updated_at
before update on public.foods
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Shopping list
-- ---------------------------------------------------------------------------

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  amount numeric not null default 1 check (amount > 0),
  unit text not null default 'unité',
  is_checked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shopping_items_user_id_idx on public.shopping_items(user_id);

create trigger shopping_items_set_updated_at
before update on public.shopping_items
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Scan history
-- ---------------------------------------------------------------------------

create table if not exists public.scan_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  scanned_at timestamptz not null default now(),
  detected_count integer not null default 0 check (detected_count >= 0),
  validated_count integer not null default 0 check (validated_count >= 0),
  source text not null default 'gemini',
  status text not null default 'success',
  model text,
  products jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists scan_history_user_id_idx on public.scan_history(user_id);
create index if not exists scan_history_scanned_at_idx on public.scan_history(scanned_at desc);

-- ---------------------------------------------------------------------------
-- Favorite recipes
-- ---------------------------------------------------------------------------

create table if not exists public.favorite_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  recipe_name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, recipe_name)
);

create index if not exists favorite_recipes_user_id_idx on public.favorite_recipes(user_id);

-- ---------------------------------------------------------------------------
-- Recipe notes
-- ---------------------------------------------------------------------------

create table if not exists public.recipe_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  recipe_name text not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, recipe_name)
);

create index if not exists recipe_notes_user_id_idx on public.recipe_notes(user_id);

create trigger recipe_notes_set_updated_at
before update on public.recipe_notes
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.foods enable row level security;
alter table public.shopping_items enable row level security;
alter table public.scan_history enable row level security;
alter table public.favorite_recipes enable row level security;
alter table public.recipe_notes enable row level security;

-- Users
create policy "Users can read their own profile"
on public.users for select
using (auth.uid() = id);

create policy "Users can insert their own profile"
on public.users for insert
with check (auth.uid() = id);

create policy "Users can update their own profile"
on public.users for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Foods
create policy "Users can read their foods"
on public.foods for select
using (auth.uid() = user_id);

create policy "Users can insert their foods"
on public.foods for insert
with check (auth.uid() = user_id);

create policy "Users can update their foods"
on public.foods for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their foods"
on public.foods for delete
using (auth.uid() = user_id);

-- Shopping items
create policy "Users can read their shopping items"
on public.shopping_items for select
using (auth.uid() = user_id);

create policy "Users can insert their shopping items"
on public.shopping_items for insert
with check (auth.uid() = user_id);

create policy "Users can update their shopping items"
on public.shopping_items for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their shopping items"
on public.shopping_items for delete
using (auth.uid() = user_id);

-- Scan history
create policy "Users can read their scan history"
on public.scan_history for select
using (auth.uid() = user_id);

create policy "Users can insert their scan history"
on public.scan_history for insert
with check (auth.uid() = user_id);

create policy "Users can delete their scan history"
on public.scan_history for delete
using (auth.uid() = user_id);

-- Favorite recipes
create policy "Users can read their favorite recipes"
on public.favorite_recipes for select
using (auth.uid() = user_id);

create policy "Users can insert their favorite recipes"
on public.favorite_recipes for insert
with check (auth.uid() = user_id);

create policy "Users can delete their favorite recipes"
on public.favorite_recipes for delete
using (auth.uid() = user_id);

-- Recipe notes
create policy "Users can read their recipe notes"
on public.recipe_notes for select
using (auth.uid() = user_id);

create policy "Users can insert their recipe notes"
on public.recipe_notes for insert
with check (auth.uid() = user_id);

create policy "Users can update their recipe notes"
on public.recipe_notes for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their recipe notes"
on public.recipe_notes for delete
using (auth.uid() = user_id);
