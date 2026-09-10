-- credit_captain_wallet_from_bpay (0014_bpay_transactions.sql) and
-- debit_captain_wallet (0026_debit_captain_wallet.sql) both end with:
--   insert into public.wallet_transactions (profile_id, amount, type, title, is_credit)
-- public.wallet_transactions is not this app's table - it's the shared
-- wallets ledger created in app-driver-customer's
-- 20260712000020_create_wallet_transactions.sql, with a completely
-- different shape: (id, wallet_id references wallets(id), user_id, type,
-- amount, balance_before, balance_after, is_credit, reference_type,
-- reference_id, description, created_by, created_at). It has no
-- profile_id or title column at all.
--
-- That insert has therefore been throwing "column ... does not exist" on
-- every single call since both functions were written - same root cause,
-- same shape, as the missing profiles.wallet_balance column
-- e28434c already found and worked around (this went undetected in that
-- pass because it only checked profiles/captains, not
-- wallet_transactions). Because the insert is the last statement in a
-- plpgsql function with no exception handling, that failure rolled back
-- the whole call - including the wallet_balance update just above it -
-- so even after adding the missing column, every Bpay recharge still
-- silently failed to actually credit anything, and every trip's
-- commission debit still silently failed to persist.
--
-- Fix: give this ledger (profiles.wallet_balance - a captain-owes-company
-- prepaid balance, unrelated to public.wallets.balance, which tracks net
-- trip earnings credited by captain_end_trip) its own small table instead
-- of forcing mismatched data into wallets' ledger. A wallet_id borrowed
-- from public.wallets would describe a change to the wrong balance
-- entirely, which is worse than just fixing the insert target.

create table if not exists public.captain_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(10, 2) not null check (amount > 0),
  type text not null check (type in ('bpay_recharge', 'commission')),
  title text not null,
  is_credit boolean not null,
  created_at timestamptz not null default now()
);

alter table public.captain_wallet_ledger enable row level security;

drop policy if exists "captains_view_own_wallet_ledger" on public.captain_wallet_ledger;
create policy "captains_view_own_wallet_ledger"
  on public.captain_wallet_ledger
  for select
  using (captain_id = auth.uid());

create or replace function public.credit_captain_wallet_from_bpay(
  p_captain_id uuid,
  p_amount numeric,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set wallet_balance = wallet_balance + p_amount
  where id = p_captain_id;

  insert into public.captain_wallet_ledger (captain_id, amount, type, title, is_credit)
  values (p_captain_id, p_amount, 'bpay_recharge', p_title, true);
end;
$$;

revoke execute on function public.credit_captain_wallet_from_bpay(uuid, numeric, text) from public, authenticated;
grant execute on function public.credit_captain_wallet_from_bpay(uuid, numeric, text) to service_role;

create or replace function public.debit_captain_wallet(
  p_amount numeric,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  update public.profiles
  set wallet_balance = wallet_balance - p_amount
  where id = uid;

  insert into public.captain_wallet_ledger (captain_id, amount, type, title, is_credit)
  values (uid, p_amount, 'commission', p_title, false);
end;
$$;

revoke all on function public.debit_captain_wallet(numeric, text) from public;
grant execute on function public.debit_captain_wallet(numeric, text) to authenticated;
