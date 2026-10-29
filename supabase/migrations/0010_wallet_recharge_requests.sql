-- Wallet recharge requests: until we have merchant API access with Bankily/
-- Sedad/Click, a captain transfers money to our own account with one of
-- these providers *outside* the app, then submits the amount + the
-- transaction reference here for an admin to verify and credit manually.
-- Captains may insert and read their own requests but cannot update or
-- delete them - only an admin (via the service role, which bypasses RLS)
-- can flip `status` to approved/rejected, so a captain can never
-- self-approve their own recharge.
create table if not exists public.wallet_recharge_requests (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.captains(id) on delete cascade,
  bank text not null check (bank in ('bankily', 'sedad', 'click')),
  amount numeric not null check (amount > 0),
  transaction_reference text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.wallet_recharge_requests enable row level security;

create policy "captains_insert_own_recharge_requests"
  on public.wallet_recharge_requests
  for insert
  with check (captain_id = auth.uid());

create policy "captains_view_own_recharge_requests"
  on public.wallet_recharge_requests
  for select
  using (captain_id = auth.uid());
