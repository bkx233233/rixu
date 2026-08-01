-- 日序第一版数据库结构。所有业务数据均绑定登录账号。
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  height_cm numeric(5, 2) check (height_cm is null or height_cm > 0),
  target_weight_kg numeric(5, 2) check (target_weight_kg is null or target_weight_kg > 0),
  default_fitness_status text not null default 'rest'
    check (default_fitness_status in ('training', 'rest')),
  timezone text not null default 'Asia/Shanghai',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 日程是可重复的计划；某日的完成状态保存在 task_occurrences。
create table public.schedule_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  note text not null default '',
  is_task boolean not null default true,
  start_at timestamptz not null,
  end_at timestamptz,
  recurrence_type text not null default 'none'
    check (recurrence_type in ('none', 'daily', 'weekly', 'monthly')),
  recurrence_weekdays smallint[] not null default '{}',
  recurrence_until date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_at is null or end_at > start_at),
  check (recurrence_weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[])
);

create index schedule_events_user_start_idx on public.schedule_events(user_id, start_at);

create table public.task_occurrences (
  id uuid primary key default gen_random_uuid(),
  schedule_event_id uuid not null references public.schedule_events(id) on delete cascade,
  occurrence_date date not null,
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'skipped')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (schedule_event_id, occurrence_date)
);

create index task_occurrences_date_idx on public.task_occurrences(occurrence_date);

-- 周目标和月目标不与带时间的日程混用。
create table public.period_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  period_type text not null check (period_type in ('week', 'month')),
  title text not null check (char_length(title) between 1 and 120),
  start_date date not null,
  end_date date not null,
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'abandoned')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index period_goals_user_period_idx on public.period_goals(user_id, period_type, start_date);

create table public.daily_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  review_date date not null,
  summary text not null default '',
  mood_score smallint check (mood_score is null or mood_score between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, review_date)
);

-- 当天状态优先于个人资料中的默认健身状态。
create table public.fitness_day_statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  status text not null check (status in ('training', 'rest')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_date)
);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  status text not null default 'planned'
    check (status in ('planned', 'completed', 'cancelled')),
  note text not null default '',
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index workout_sessions_user_date_idx on public.workout_sessions(user_id, local_date);

create table public.workout_exercise_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_name text not null check (char_length(exercise_name) between 1 and 120),
  position smallint not null check (position >= 0),
  sets_count smallint check (sets_count is null or sets_count >= 0),
  repetitions smallint check (repetitions is null or repetitions >= 0),
  weight_kg numeric(6, 2) check (weight_kg is null or weight_kg >= 0),
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, position)
);

create table public.nutrition_targets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  calorie_kcal integer check (calorie_kcal is null or calorie_kcal > 0),
  protein_g numeric(6, 2) check (protein_g is null or protein_g >= 0),
  carbohydrate_g numeric(6, 2) check (carbohydrate_g is null or carbohydrate_g >= 0),
  fat_g numeric(6, 2) check (fat_g is null or fat_g >= 0),
  updated_at timestamptz not null default now()
);

-- 每条饮食记录保存营养快照，后续食物库变化不会篡改历史数据。
create table public.meal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  food_name text not null check (char_length(food_name) between 1 and 120),
  amount numeric(8, 2) not null check (amount > 0),
  unit text not null check (char_length(unit) between 1 and 20),
  calorie_kcal numeric(8, 2) not null check (calorie_kcal >= 0),
  protein_g numeric(8, 2) not null default 0 check (protein_g >= 0),
  carbohydrate_g numeric(8, 2) not null default 0 check (carbohydrate_g >= 0),
  fat_g numeric(8, 2) not null default 0 check (fat_g >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index meal_entries_user_date_idx on public.meal_entries(user_id, local_date, meal_type);

-- 仅保存真实填写的称重记录；缺失日期不插入任何估算数据。
create table public.body_weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  weight_kg numeric(5, 2) not null check (weight_kg > 0),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, local_date)
);

create index body_weight_entries_user_date_idx on public.body_weight_entries(user_id, local_date);

-- 注册后由数据库创建资料，避免客户端伪造数据归属。
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger schedule_events_set_updated_at before update on public.schedule_events for each row execute procedure public.set_updated_at();
create trigger task_occurrences_set_updated_at before update on public.task_occurrences for each row execute procedure public.set_updated_at();
create trigger period_goals_set_updated_at before update on public.period_goals for each row execute procedure public.set_updated_at();
create trigger daily_reviews_set_updated_at before update on public.daily_reviews for each row execute procedure public.set_updated_at();
create trigger fitness_day_statuses_set_updated_at before update on public.fitness_day_statuses for each row execute procedure public.set_updated_at();
create trigger workout_sessions_set_updated_at before update on public.workout_sessions for each row execute procedure public.set_updated_at();
create trigger workout_exercise_logs_set_updated_at before update on public.workout_exercise_logs for each row execute procedure public.set_updated_at();
create trigger nutrition_targets_set_updated_at before update on public.nutrition_targets for each row execute procedure public.set_updated_at();
create trigger meal_entries_set_updated_at before update on public.meal_entries for each row execute procedure public.set_updated_at();
create trigger body_weight_entries_set_updated_at before update on public.body_weight_entries for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.schedule_events enable row level security;
alter table public.task_occurrences enable row level security;
alter table public.period_goals enable row level security;
alter table public.daily_reviews enable row level security;
alter table public.fitness_day_statuses enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_exercise_logs enable row level security;
alter table public.nutrition_targets enable row level security;
alter table public.meal_entries enable row level security;
alter table public.body_weight_entries enable row level security;

create policy "用户管理自己的资料" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "用户管理自己的日程" on public.schedule_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的日程完成状态" on public.task_occurrences for all using (exists (select 1 from public.schedule_events where id = schedule_event_id and user_id = auth.uid())) with check (exists (select 1 from public.schedule_events where id = schedule_event_id and user_id = auth.uid()));
create policy "用户管理自己的周期目标" on public.period_goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的每日总结" on public.daily_reviews for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的训练状态" on public.fitness_day_statuses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的训练记录" on public.workout_sessions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的训练动作" on public.workout_exercise_logs for all using (exists (select 1 from public.workout_sessions where id = session_id and user_id = auth.uid())) with check (exists (select 1 from public.workout_sessions where id = session_id and user_id = auth.uid()));
create policy "用户管理自己的营养目标" on public.nutrition_targets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的饮食记录" on public.meal_entries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "用户管理自己的体重记录" on public.body_weight_entries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 这些表的变更会推送到同账号的其他在线设备。
alter publication supabase_realtime add table public.schedule_events, public.task_occurrences, public.period_goals, public.daily_reviews, public.fitness_day_statuses, public.workout_sessions, public.meal_entries, public.body_weight_entries;
