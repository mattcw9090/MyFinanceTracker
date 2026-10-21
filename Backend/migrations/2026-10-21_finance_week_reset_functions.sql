-- Draft only. Do not apply until the app is changed to call these functions.
-- Mirrors MyFinanceTracker Reset and Initialize Week for workspaces owned
-- by auth.uid(). Soft-deletes, so sync can download tombstones. Calling
-- either function twice does not double net income or revive old rows.

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
        or exists (select 1 from public.finance_quick_add_transactions q where q.workspace_id = w.id)
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
  'Same as Reset in MyFinanceTracker: soft-deletes every live finance transaction, including completed and coaching-linked rows, and sets the canonical net income to 0. Does not change cash flow, quick add, or predefined rows. A second call changes nothing.';

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
        or exists (select 1 from public.finance_quick_add_transactions q where q.workspace_id = w.id)
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
