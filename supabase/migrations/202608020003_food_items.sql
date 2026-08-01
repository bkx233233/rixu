-- 用户自己维护常用食物。营养数据只来自用户输入，不内置未经核验的数据。
create table public.food_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  category text not null default '其他' check (char_length(category) between 1 and 30),
  default_amount numeric(8, 2) not null check (default_amount > 0),
  default_unit text not null check (char_length(default_unit) between 1 and 20),
  calorie_kcal numeric(8, 2) not null check (calorie_kcal >= 0),
  protein_g numeric(8, 2) not null default 0 check (protein_g >= 0),
  carbohydrate_g numeric(8, 2) not null default 0 check (carbohydrate_g >= 0),
  fat_g numeric(8, 2) not null default 0 check (fat_g >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);

create index food_items_user_name_idx on public.food_items(user_id, name);

alter table public.meal_entries
  add column food_item_id uuid references public.food_items(id) on delete set null;

create index meal_entries_food_item_idx on public.meal_entries(food_item_id);

create trigger food_items_set_updated_at
before update on public.food_items
for each row execute procedure public.set_updated_at();

alter table public.food_items enable row level security;

create policy "用户管理自己的常用食物"
on public.food_items for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

alter publication supabase_realtime add table public.food_items;
