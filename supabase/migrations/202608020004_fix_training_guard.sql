-- 修复训练保护函数的变量命名，避免与 PostgreSQL 内置 session_user 产生冲突。
drop trigger if exists prevent_rest_day_workout on public.workout_sessions;
drop trigger if exists prevent_rest_day_exercise on public.workout_exercise_logs;
drop function if exists public.prevent_rest_day_workout();
drop function if exists public.prevent_rest_day_exercise();

create function public.prevent_rest_day_workout()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_day_status text;
  v_default_status text;
begin
  select fds.status into v_day_status
  from public.fitness_day_statuses as fds
  where fds.user_id = new.user_id and fds.local_date = new.local_date;

  select p.default_fitness_status into v_default_status
  from public.profiles as p
  where p.id = new.user_id;

  if coalesce(v_day_status, v_default_status, 'rest') <> 'training' then
    raise exception '休息中不能添加训练动作。';
  end if;
  return new;
end;
$$;

create trigger prevent_rest_day_workout
before insert on public.workout_sessions
for each row execute procedure public.prevent_rest_day_workout();

create function public.prevent_rest_day_exercise()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
  v_local_date date;
  v_day_status text;
  v_default_status text;
begin
  select ws.user_id, ws.local_date
    into v_user_id, v_local_date
  from public.workout_sessions as ws
  where ws.id = new.session_id;

  select fds.status into v_day_status
  from public.fitness_day_statuses as fds
  where fds.user_id = v_user_id and fds.local_date = v_local_date;

  select p.default_fitness_status into v_default_status
  from public.profiles as p
  where p.id = v_user_id;

  if coalesce(v_day_status, v_default_status, 'rest') <> 'training' then
    raise exception '休息中不能添加训练动作。';
  end if;
  return new;
end;
$$;

create trigger prevent_rest_day_exercise
before insert on public.workout_exercise_logs
for each row execute procedure public.prevent_rest_day_exercise();
