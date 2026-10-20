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
