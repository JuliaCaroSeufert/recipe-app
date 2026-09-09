-- FamilienRezepte — initial schema
-- Run this in the Supabase SQL editor (or via `supabase db push`).
-- Every row is scoped to the authenticated user via RLS. Anonymous sign-in
-- is enough for a single-user personal app; email auth can be added later
-- without schema changes.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums (kept as text + check constraints for easy evolution)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- recipes
-- ---------------------------------------------------------------------------
create table if not exists public.recipes (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  title             text not null,
  description       text,
  image_url         text,
  source_type       text not null default 'manual'
                      check (source_type in ('manual', 'pdf', 'instagram')),
  source_ref        text,
  servings          integer not null default 2 check (servings > 0),
  kcal_per_serving  integer check (kcal_per_serving is null or kcal_per_serving >= 0),
  prep_minutes      integer check (prep_minutes is null or prep_minutes >= 0),
  steps             jsonb not null default '[]'::jsonb,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists recipes_user_idx on public.recipes (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- tags  (e.g. "bake and dump", "dump and go", "unter 500 kcal")
-- ---------------------------------------------------------------------------
create table if not exists public.tags (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references auth.users (id) on delete cascade,
  name     text not null,
  kind     text check (kind is null or kind in ('method', 'diet', 'cuisine', 'custom')),
  unique (user_id, name)
);

create table if not exists public.recipe_tags (
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  tag_id    uuid not null references public.tags (id) on delete cascade,
  user_id   uuid not null references auth.users (id) on delete cascade,
  primary key (recipe_id, tag_id)
);

-- ---------------------------------------------------------------------------
-- ingredients  (canonical catalog used for shopping-list aggregation and,
--               later, REWE product matching)
-- ---------------------------------------------------------------------------
create table if not exists public.ingredients (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users (id) on delete cascade,
  name               text not null,
  category           text,               -- shopping-list grouping ("Molkerei", "Gemüse", ...)
  density_g_per_ml   numeric,            -- optional, for EL/TL/cup -> g conversion later
  rewe_product_id    text,               -- filled during the REWE phase
  unique (user_id, name)
);

-- ---------------------------------------------------------------------------
-- recipe_ingredients
-- ---------------------------------------------------------------------------
create table if not exists public.recipe_ingredients (
  id             uuid primary key default gen_random_uuid(),
  recipe_id      uuid not null references public.recipes (id) on delete cascade,
  ingredient_id  uuid not null references public.ingredients (id) on delete restrict,
  user_id        uuid not null references auth.users (id) on delete cascade,
  raw_text       text,                   -- original line, e.g. "200 g Feta, gewürfelt"
  quantity       numeric,
  unit           text,                   -- 'g' | 'ml' | 'Stück' | 'EL' | 'TL' | 'Prise' | 'Dose' | 'Bund' | null
  note           text,                   -- e.g. "gewürfelt"
  sort           integer not null default 0
);
create index if not exists recipe_ingredients_recipe_idx
  on public.recipe_ingredients (recipe_id, sort);

-- ---------------------------------------------------------------------------
-- meal_plans  (weekly plan)
-- ---------------------------------------------------------------------------
create table if not exists public.meal_plans (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  title          text not null,
  start_date     date,
  days           integer not null default 7 check (days between 1 and 14),
  meals_per_day  integer not null default 1 check (meals_per_day between 1 and 5),
  servings       integer not null default 2 check (servings > 0),  -- persons, set once per week
  status         text not null default 'draft' check (status in ('draft', 'confirmed')),
  filters        jsonb not null default '{}'::jsonb,               -- filter config used to generate
  created_at     timestamptz not null default now()
);
create index if not exists meal_plans_user_idx on public.meal_plans (user_id, created_at desc);

create table if not exists public.meal_plan_entries (
  id                 uuid primary key default gen_random_uuid(),
  plan_id            uuid not null references public.meal_plans (id) on delete cascade,
  recipe_id          uuid not null references public.recipes (id) on delete restrict,
  user_id            uuid not null references auth.users (id) on delete cascade,
  day_index          integer not null check (day_index >= 0),
  slot_index         integer not null default 0 check (slot_index >= 0),
  servings_override  integer check (servings_override is null or servings_override > 0),
  unique (plan_id, day_index, slot_index)
);

-- ---------------------------------------------------------------------------
-- shopping_lists  (generated when a plan is confirmed)
-- ---------------------------------------------------------------------------
create table if not exists public.shopping_lists (
  id          uuid primary key default gen_random_uuid(),
  plan_id     uuid not null unique references public.meal_plans (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  status      text not null default 'open' check (status in ('open', 'ordered')),
  created_at  timestamptz not null default now()
);

create table if not exists public.shopping_list_items (
  id               uuid primary key default gen_random_uuid(),
  list_id          uuid not null references public.shopping_lists (id) on delete cascade,
  ingredient_id    uuid not null references public.ingredients (id) on delete restrict,
  user_id          uuid not null references auth.users (id) on delete cascade,
  total_quantity   numeric,
  unit             text,
  checked          boolean not null default false,
  rewe_product_id  text,
  rewe_qty         integer
);
create index if not exists shopping_list_items_list_idx
  on public.shopping_list_items (list_id);

-- ---------------------------------------------------------------------------
-- updated_at trigger for recipes
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists recipes_set_updated_at on public.recipes;
create trigger recipes_set_updated_at
  before update on public.recipes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security — owner-only access on every table
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'recipes', 'tags', 'recipe_tags', 'ingredients', 'recipe_ingredients',
    'meal_plans', 'meal_plan_entries', 'shopping_lists', 'shopping_list_items'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists %I_owner_all on public.%I;', t, t);
    execute format(
      'create policy %I_owner_all on public.%I
         for all using (user_id = auth.uid()) with check (user_id = auth.uid());',
      t, t);
  end loop;
end $$;
