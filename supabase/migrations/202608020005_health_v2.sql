-- 日序 0.2：营养计算、每 100 克食物数据和完整记录维护。
-- 旧饮食记录保留当次营养快照，绝不重新计算历史数据。

alter table public.profiles
  add column if not exists sex text check (sex in ('male', 'female')),
  add column if not exists birth_date date,
  add column if not exists activity_level text check (activity_level in ('sedentary', 'light', 'moderate', 'high', 'athlete')),
  add column if not exists onboarding_completed boolean not null default false;

alter table public.nutrition_targets
  add column if not exists daily_calorie_deficit_kcal integer not null default 300
    check (daily_calorie_deficit_kcal between 0 and 1000),
  add column if not exists calculation_mode text not null default 'calculated'
    check (calculation_mode in ('calculated', 'manual'));

-- 旧数据不删除。仅当旧基准单位为 g 时才可精确迁移到每 100 克。
alter table public.food_items
  add column if not exists calories_per_100g numeric(8, 2),
  add column if not exists protein_per_100g numeric(8, 2),
  add column if not exists carbohydrate_per_100g numeric(8, 2),
  add column if not exists fat_per_100g numeric(8, 2),
  add column if not exists source_name text not null default '个人录入',
  add column if not exists source_version text;

update public.food_items
set calories_per_100g = round(calorie_kcal * 100 / default_amount, 2),
    protein_per_100g = round(protein_g * 100 / default_amount, 2),
    carbohydrate_per_100g = round(carbohydrate_g * 100 / default_amount, 2),
    fat_per_100g = round(fat_g * 100 / default_amount, 2)
where lower(default_unit) in ('g', 'gram', 'grams')
  and default_amount > 0
  and calories_per_100g is null;

alter table public.food_items
  add constraint food_items_per_100g_values_check check (
    (calories_per_100g is null and protein_per_100g is null and carbohydrate_per_100g is null and fat_per_100g is null)
    or (calories_per_100g >= 0 and protein_per_100g >= 0 and carbohydrate_per_100g >= 0 and fat_per_100g >= 0)
  );

-- 系统食物和个人食物分表，系统数据不会与用户的录入或权限混在一起。
create table if not exists public.system_food_items (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  category text not null default '其他' check (char_length(category) between 1 and 30),
  calories_per_100g numeric(8, 2) not null check (calories_per_100g >= 0),
  protein_per_100g numeric(8, 2) not null check (protein_per_100g >= 0),
  carbohydrate_per_100g numeric(8, 2) not null check (carbohydrate_per_100g >= 0),
  fat_per_100g numeric(8, 2) not null check (fat_per_100g >= 0),
  source_name text not null,
  source_version text not null,
  source_reference text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (name, source_name, source_version)
);

create index if not exists system_food_items_name_idx on public.system_food_items(name);
create trigger system_food_items_set_updated_at before update on public.system_food_items
for each row execute procedure public.set_updated_at();
alter table public.system_food_items enable row level security;
create policy "登录用户读取系统食物" on public.system_food_items for select using (auth.uid() is not null);

-- 所有新增记录都会收到实时事件；已登录设备可以局部刷新缓存。
alter publication supabase_realtime add table public.profiles, public.nutrition_targets, public.system_food_items;
