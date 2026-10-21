-- Reference snapshot of the MyFinanceTracker finance schema after
-- Backend/migrations/2026-10-21_drop_finance_quick_add.sql.
-- finance_quick_add_transactions is not part of this schema.
-- CoachPlanner tables are not included. Do not apply this file.
-- Apply the migration instead. anon is granted nothing.
-- set_updated_at() is the same function CoachPlanner already uses.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.finance_cash_flow_items (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text,
  amount double precision not null default 0,
  is_owed_to_me boolean not null default false,
  is_settled boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.finance_net_income (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  value double precision not null default 0,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.finance_predefined_transactions (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  description text,
  amount double precision not null default 0,
  day_of_week text,
  is_income boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.finance_transactions (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  description text,
  amount double precision not null default 0,
  day_of_week text,
  is_completed boolean not null default false,
  is_income boolean not null default false,
  coaching_session_id uuid,
  coaching_week_start date,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists finance_cash_flow_items_workspace_id_idx
  on public.finance_cash_flow_items (workspace_id);
create index if not exists finance_net_income_workspace_id_idx
  on public.finance_net_income (workspace_id);
create index if not exists finance_predefined_transactions_workspace_id_idx
  on public.finance_predefined_transactions (workspace_id);
create index if not exists finance_transactions_workspace_id_idx
  on public.finance_transactions (workspace_id);

create unique index if not exists finance_transactions_coaching_session_once
  on public.finance_transactions (workspace_id, coaching_session_id, coaching_week_start)
  where deleted_at is null and coaching_session_id is not null;

drop trigger if exists finance_cash_flow_items_set_updated_at on public.finance_cash_flow_items;
create trigger finance_cash_flow_items_set_updated_at
  before update on public.finance_cash_flow_items
  for each row execute function public.set_updated_at();

drop trigger if exists finance_net_income_set_updated_at on public.finance_net_income;
create trigger finance_net_income_set_updated_at
  before update on public.finance_net_income
  for each row execute function public.set_updated_at();

drop trigger if exists finance_predefined_transactions_set_updated_at on public.finance_predefined_transactions;
create trigger finance_predefined_transactions_set_updated_at
  before update on public.finance_predefined_transactions
  for each row execute function public.set_updated_at();

drop trigger if exists finance_transactions_set_updated_at on public.finance_transactions;
create trigger finance_transactions_set_updated_at
  before update on public.finance_transactions
  for each row execute function public.set_updated_at();

alter table public.finance_cash_flow_items enable row level security;
alter table public.finance_net_income enable row level security;
alter table public.finance_predefined_transactions enable row level security;
alter table public.finance_transactions enable row level security;

drop policy if exists finance_cash_flow_items_owner on public.finance_cash_flow_items;
create policy finance_cash_flow_items_owner
  on public.finance_cash_flow_items
  for all
  to authenticated
  using (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  );

drop policy if exists finance_net_income_owner on public.finance_net_income;
create policy finance_net_income_owner
  on public.finance_net_income
  for all
  to authenticated
  using (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  );

drop policy if exists finance_predefined_transactions_owner on public.finance_predefined_transactions;
create policy finance_predefined_transactions_owner
  on public.finance_predefined_transactions
  for all
  to authenticated
  using (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  );

drop policy if exists finance_transactions_owner on public.finance_transactions;
create policy finance_transactions_owner
  on public.finance_transactions
  for all
  to authenticated
  using (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_user_id = auth.uid()
    )
  );

revoke all on table
  public.finance_cash_flow_items,
  public.finance_net_income,
  public.finance_predefined_transactions,
  public.finance_transactions
from anon;

grant select, insert, update, delete on table
  public.finance_cash_flow_items,
  public.finance_net_income,
  public.finance_predefined_transactions,
  public.finance_transactions
to authenticated, service_role;

create or replace function public.complete_finance_transaction(
  p_transaction_id uuid,
  p_add_to_cash_flow boolean default false,
  p_additional_cost double precision default 0,
  p_split_names text[] default null
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  t finance_transactions%rowtype;
  names text[];
  total double precision;
  added integer := 0;
begin
  select * into t from finance_transactions
  where id = p_transaction_id and deleted_at is null
  for update;

  if not found then
    raise exception 'Transaction % not found', p_transaction_id;
  end if;

  -- Already done: change nothing, so a repeated call can't add items twice.
  if t.is_completed then
    return 0;
  end if;

  update finance_transactions set is_completed = true where id = t.id;

  if p_add_to_cash_flow and t.is_income then
    total := t.amount + coalesce(p_additional_cost, 0);
    select coalesce(array_agg(btrim(n)), '{}') into names
    from unnest(coalesce(p_split_names, '{}')) n
    where btrim(n) <> '';

    if cardinality(names) = 0 then
      insert into finance_cash_flow_items (id, workspace_id, name, amount, is_owed_to_me)
      values (gen_random_uuid(), t.workspace_id, coalesce(t.description, 'Unnamed Transaction'), total, true);
      added := 1;
    else
      insert into finance_cash_flow_items (id, workspace_id, name, amount, is_owed_to_me)
      select gen_random_uuid(), t.workspace_id, n, total / cardinality(names), true
      from unnest(names) n;
      added := cardinality(names);
    end if;
  end if;

  return added;
end;
$$;

comment on function public.complete_finance_transaction(uuid, boolean, double precision, text[]) is
  'Same as ticking a transaction in MyFinanceTracker: marks it completed and, for income when asked, adds Who owes me cash-flow items (amount plus extra court cost, split equally between names, or one item for the full total). Does nothing if already completed.';

revoke all on function public.complete_finance_transaction(uuid, boolean, double precision, text[]) from public, anon;
grant execute on function public.complete_finance_transaction(uuid, boolean, double precision, text[]) to authenticated, service_role;

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

-- Reset: soft-delete every live transaction and set the canonical net income
-- to 0. Returns how many transactions were soft-deleted.
create or replace function public.reset_finance_week()
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  ws uuid;
  removed integer := 0;
  n integer;
  ni_id uuid;
begin
  if auth.uid() is null then
    raise exception 'reset_finance_week requires a signed-in user';
  end if;

  for ws in
    select w.id
    from public.workspaces w
    where w.owner_user_id = auth.uid()
      and (
        exists (select 1 from public.finance_transactions t where t.workspace_id = w.id)
        or exists (select 1 from public.finance_net_income n where n.workspace_id = w.id)
        or exists (select 1 from public.finance_predefined_transactions p where p.workspace_id = w.id)
        or exists (select 1 from public.finance_cash_flow_items c where c.workspace_id = w.id)
      )
    order by w.id
  loop
    -- Same lock as session import, so the two cannot interleave.
    perform pg_advisory_xact_lock(hashtext('finance_import:' || ws::text));

    -- Tombstone only. description, amount, day, is_completed, is_income,
    -- and the coaching link stay. set_updated_at() bumps updated_at.
    update public.finance_transactions
    set deleted_at = now()
    where workspace_id = ws
      and deleted_at is null;
    get diagnostics n = row_count;
    removed := removed + n;

    -- Newest live balance, then highest id text. Same choice as the app.
    select id into ni_id
    from public.finance_net_income
    where workspace_id = ws
      and deleted_at is null
    order by updated_at desc, id::text desc
    limit 1
    for update;

    if ni_id is null then
      insert into public.finance_net_income (id, workspace_id, value)
      values (gen_random_uuid(), ws, 0);
    else
      -- Already 0: leave updated_at alone, matching a second tap.
      update public.finance_net_income
      set value = 0
      where id = ni_id
        and value is distinct from 0;
    end if;
  end loop;

  return removed;
end;
$$;

comment on function public.reset_finance_week() is
  'Same as Reset in MyFinanceTracker: soft-deletes every live finance transaction, including completed and coaching-linked rows, and sets the canonical net income to 0. Does not change cash flow or predefined rows. A second call changes nothing.';

-- Initialize Week: reset, then copy live predefined transactions into new
-- unticked transactions. "Every day" becomes Monday–Sunday. A null day uses
-- p_unscheduled_day, or the English weekday in Australia/Perth when that
-- argument is null. Returns how many transactions were created.
create or replace function public.reinitialize_finance_week(p_unscheduled_day text default null)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  ws uuid;
  created integer := 0;
  n integer;
  total double precision;
  ni_id uuid;
  today_name text;
begin
  if auth.uid() is null then
    raise exception 'reinitialize_finance_week requires a signed-in user';
  end if;

  today_name := coalesce(
    p_unscheduled_day,
    (array['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'])[
      extract(dow from (now() at time zone 'Australia/Perth'))::integer + 1
    ]
  );

  perform public.reset_finance_week();

  for ws in
    select w.id
    from public.workspaces w
    where w.owner_user_id = auth.uid()
      and (
        exists (select 1 from public.finance_transactions t where t.workspace_id = w.id)
        or exists (select 1 from public.finance_net_income n where n.workspace_id = w.id)
        or exists (select 1 from public.finance_predefined_transactions p where p.workspace_id = w.id)
        or exists (select 1 from public.finance_cash_flow_items c where c.workspace_id = w.id)
      )
    order by w.id
  loop
    perform pg_advisory_xact_lock(hashtext('finance_import:' || ws::text));

    with inserted as (
      insert into public.finance_transactions (
        id, workspace_id, description, amount, day_of_week, is_completed, is_income
      )
      select
        gen_random_uuid(),
        p.workspace_id,
        p.description,
        p.amount,
        day.name,
        false,
        p.is_income
      from public.finance_predefined_transactions p
      join lateral (
        select unnest(
          case
            when p.day_of_week = 'Every day' then
              array['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
            else
              array[coalesce(p.day_of_week, today_name)]
          end
        ) as name
      ) day on true
      where p.workspace_id = ws
        and p.deleted_at is null
      returning amount, is_income
    )
    select
      count(*)::integer,
      coalesce(sum(case when is_income then amount else -amount end), 0)
    into n, total
    from inserted;

    created := created + n;

    if n > 0 and total is distinct from 0 then
      select id into ni_id
      from public.finance_net_income
      where workspace_id = ws
        and deleted_at is null
      order by updated_at desc, id::text desc
      limit 1
      for update;

      if ni_id is null then
        insert into public.finance_net_income (id, workspace_id, value)
        values (gen_random_uuid(), ws, total);
      else
        update public.finance_net_income
        set value = total
        where id = ni_id;
      end if;
    end if;
  end loop;

  return created;
end;
$$;

comment on function public.reinitialize_finance_week(text) is
  'Same as Initialize Week in MyFinanceTracker: soft-deletes live transactions, sets net income to 0, then inserts one unticked transaction per predefined day (Every day expands to Monday–Sunday) and sets net income to their signed sum. New rows have no coaching link. Safe to call twice: the second call retires the first call''s rows and recreates the same total.';

revoke all on function public.reset_finance_week() from public, anon;
revoke all on function public.reinitialize_finance_week(text) from public, anon;
grant execute on function public.reset_finance_week() to authenticated, service_role;
grant execute on function public.reinitialize_finance_week(text) to authenticated, service_role;
