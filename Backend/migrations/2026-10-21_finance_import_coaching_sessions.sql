-- Import CoachPlanner coaching sessions into MyFinanceTracker as income,
-- straight from Supabase, skipping sessions already imported for that week.

alter table public.finance_transactions
  add column if not exists coaching_session_id uuid,
  add column if not exists coaching_week_start date;

create unique index if not exists finance_transactions_coaching_session_once
  on public.finance_transactions (workspace_id, coaching_session_id, coaching_week_start)
  where deleted_at is null and coaching_session_id is not null;

-- Preview: a week's live coaching sessions as they'd appear in the finance app.
create or replace function public.coaching_sessions_for_finance(p_week_start date)
returns table (
  session_id uuid,
  week_start date,
  day_of_week text,
  session_name text,
  session_fee double precision,
  start_time timestamptz,
  already_imported boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    c.id,
    c.week_start,
    (array['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'])[c.day_of_week],
    coalesce(
      (select string_agg(st.name, ', ' order by lower(st.name))
       from coaching_session_students cs
       join students st on st.id = cs.student_id
       where cs.session_id = c.id),
      c.venue || ' coaching'
    ),
    c.session_fee::double precision,
    c.start_time,
    exists (
      select 1 from finance_transactions f
      where f.workspace_id = c.workspace_id
        and f.coaching_session_id = c.id
        and f.coaching_week_start = c.week_start
        and f.deleted_at is null
    )
  from coaching_sessions c
  where c.week_start = p_week_start and c.deleted_at is null
  order by c.start_time;
$$;

-- Import: adds each not-yet-imported session with a fee as an unticked income
-- transaction and adds the total to net income. Safe to call twice.
create or replace function public.import_coaching_sessions_to_finance(
  p_week_start date,
  p_session_ids uuid[] default null
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  ws uuid;
  added integer := 0;
  n integer;
  total double precision;
  ni_id uuid;
begin
  for ws in
    select distinct c.workspace_id from coaching_sessions c
    where c.week_start = p_week_start and c.deleted_at is null
  loop
    -- Serialise imports per workspace so two taps can't double-count.
    perform pg_advisory_xact_lock(hashtext('finance_import:' || ws::text));

    with candidates as (
      select s.* from public.coaching_sessions_for_finance(p_week_start) s
      join coaching_sessions c on c.id = s.session_id
      where c.workspace_id = ws
        and not s.already_imported
        and s.session_fee > 0
        and (p_session_ids is null or s.session_id = any(p_session_ids))
    ), ins as (
      insert into finance_transactions
        (id, workspace_id, description, amount, day_of_week, is_completed, is_income,
         coaching_session_id, coaching_week_start)
      select gen_random_uuid(), ws, session_name, session_fee, day_of_week, false, true,
             session_id, week_start
      from candidates
      returning amount
    )
    select count(*), coalesce(sum(amount), 0) into strict n, total from ins;
    added := added + n;

    if n > 0 then
      select id into ni_id from finance_net_income
      where workspace_id = ws and deleted_at is null
      order by updated_at desc limit 1
      for update;

      if ni_id is null then
        insert into finance_net_income (id, workspace_id, value)
        values (gen_random_uuid(), ws, total);
      else
        update finance_net_income set value = value + total where id = ni_id;
      end if;
    end if;
  end loop;

  return added;
end;
$$;

revoke all on function public.coaching_sessions_for_finance(date) from public, anon;
revoke all on function public.import_coaching_sessions_to_finance(date, uuid[]) from public, anon;
grant execute on function public.coaching_sessions_for_finance(date) to authenticated, service_role;
grant execute on function public.import_coaching_sessions_to_finance(date, uuid[]) to authenticated, service_role;
