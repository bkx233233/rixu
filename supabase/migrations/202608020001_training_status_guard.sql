-- 休息日禁止新增训练会话，防止绕过前端灰显直接写入。
create or replace function public.prevent_rest_day_workout()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  day_status text;
  default_status text;
begin
  select status into day_status
  from public.fitness_day_statuses
  where user_id = new.user_id and local_date = new.local_date;

  select default_fitness_status into default_status
  from public.profiles
  where id = new.user_id;

  if coalesce(day_status, default_status, 'rest') <> 'training' then
    raise exception '休息中不能添加训练动作。';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_rest_day_workout on public.workout_sessions;
create trigger prevent_rest_day_workout
before insert on public.workout_sessions
for each row execute procedure public.prevent_rest_day_workout();

create or replace function public.prevent_rest_day_exercise()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  session_user uuid;
  session_date date;
  day_status text;
  default_status text;
begin
  select user_id, local_date into session_user, session_date
  from public.workout_sessions
  where id = new.session_id;

  select status into day_status
  from public.fitness_day_statuses
  where user_id = session_user and local_date = session_date;

  select default_fitness_status into default_status
  from public.profiles
  where id = session_user;

  if coalesce(day_status, default_status, 'rest') <> 'training' then
    raise exception '休息中不能添加训练动作。';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_rest_day_exercise on public.workout_exercise_logs;
create trigger prevent_rest_day_exercise
before insert on public.workout_exercise_logs
for each row execute procedure public.prevent_rest_day_exercise();
