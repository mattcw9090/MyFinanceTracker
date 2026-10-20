-- MyFinanceTracker finance tables.
-- Idempotent. Does not insert, update, or delete rows, and does not alter
-- existing CoachPlanner tables.
-- Apply in the Supabase SQL editor for project bgpjpimhrnmthamzqsgv.
-- The app reads and writes these tables only with a signed-in user JWT.
-- The publishable key is only the apikey header. anon is granted nothing.
-- set_updated_at() is the same function CoachPlanner already uses. Replacing
-- it with this body keeps bot updates moving updated_at for last-write-wins.

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

create table if not exists public.finance_quick_add_transactions (
  id uuid primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  description text,
  amount double precision not null default 0,
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
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists finance_cash_flow_items_workspace_id_idx
  on public.finance_cash_flow_items (workspace_id);
create index if not exists finance_net_income_workspace_id_idx
  on public.finance_net_income (workspace_id);
create index if not exists finance_predefined_transactions_workspace_id_idx
  on public.finance_predefined_transactions (workspace_id);
create index if not exists finance_quick_add_transactions_workspace_id_idx
  on public.finance_quick_add_transactions (workspace_id);
create index if not exists finance_transactions_workspace_id_idx
  on public.finance_transactions (workspace_id);

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

drop trigger if exists finance_quick_add_transactions_set_updated_at on public.finance_quick_add_transactions;
create trigger finance_quick_add_transactions_set_updated_at
  before update on public.finance_quick_add_transactions
  for each row execute function public.set_updated_at();

drop trigger if exists finance_transactions_set_updated_at on public.finance_transactions;
create trigger finance_transactions_set_updated_at
  before update on public.finance_transactions
  for each row execute function public.set_updated_at();

alter table public.finance_cash_flow_items enable row level security;
alter table public.finance_net_income enable row level security;
alter table public.finance_predefined_transactions enable row level security;
alter table public.finance_quick_add_transactions enable row level security;
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

drop policy if exists finance_quick_add_transactions_owner on public.finance_quick_add_transactions;
create policy finance_quick_add_transactions_owner
  on public.finance_quick_add_transactions
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
  public.finance_quick_add_transactions,
  public.finance_transactions
from anon;

grant select, insert, update, delete on table
  public.finance_cash_flow_items,
  public.finance_net_income,
  public.finance_predefined_transactions,
  public.finance_quick_add_transactions,
  public.finance_transactions
to authenticated, service_role;
