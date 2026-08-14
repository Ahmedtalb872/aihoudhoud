-- Live Bpay recharge transactions: each row is the durable record of a
-- merchant-initiated Bpay payment call made by the bpay-payment Edge
-- Function, which credits the captain's wallet automatically on success -
-- replacing the old manual-admin-review flow (wallet_recharge_requests).
-- Only the Edge Function (service role, bypasses RLS) ever writes here; a
-- captain can only read their own rows, never insert/update/delete.
create table if not exists public.bpay_transactions (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.captains(id) on delete cascade,
  operation_id text not null unique,
  amount numeric not null check (amount > 0),
  payer_phone text not null,
  status text not null check (status in ('success', 'failed', 'pending')),
  error_code integer,
  error_message text,
  transaction_id text,
  created_at timestamptz not null default now()
);

alter table public.bpay_transactions enable row level security;

create policy "captains_view_own_bpay_transactions"
  on public.bpay_transactions
  for select
  using (captain_id = auth.uid());

-- Atomically credits a captain's wallet and logs the ledger entry. Only
-- callable by the service role (the bpay-payment Edge Function) after a
-- confirmed successful Bpay payment - never directly by a captain, which is
-- why execute is revoked from public/authenticated below.
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

  insert into public.wallet_transactions (profile_id, amount, type, title, is_credit)
  values (p_captain_id, p_amount, 'charge', p_title, true);
end;
$$;

revoke execute on function public.credit_captain_wallet_from_bpay(uuid, numeric, text) from public, authenticated;
grant execute on function public.credit_captain_wallet_from_bpay(uuid, numeric, text) to service_role;
