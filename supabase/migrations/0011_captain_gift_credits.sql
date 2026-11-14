-- Captain gift/incentive credits: 1 MRU is granted to a captain for every
-- trip they complete, tracked as individual credit rows (not a running
-- total) because each 1 MRU has its own independent 6-month expiry from
-- when it was earned. A captain can only move this balance into their main
-- wallet once the sum of still-valid, unredeemed credits reaches 10 MRU -
-- redemption happens through redeem_captain_gift_credits() below, which
-- enforces that minimum, rather than direct client writes.
create table if not exists public.captain_gift_credits (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.captains(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  amount numeric not null default 1,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '6 months'),
  redeemed_at timestamptz
);

alter table public.captain_gift_credits enable row level security;

-- Read-only for captains: rows are only ever written by the trigger below
-- (granting) or by redeem_captain_gift_credits() (redeeming), both of which
-- run as the function owner and so aren't gated by RLS.
create policy "captains_view_own_gift_credits"
  on public.captain_gift_credits
  for select
  using (captain_id = auth.uid());

-- Grants 1 MRU the moment a trip's status flips to 'completed'. Runs as a
-- trigger (not client-side code) so a captain can't fabricate credits by
-- calling the wrong endpoint.
create or replace function public.grant_captain_gift_credit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'completed'
     and old.status is distinct from 'completed'
     and new.captain_id is not null then
    insert into public.captain_gift_credits (captain_id, trip_id, amount)
    values (new.captain_id, new.id, 1);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_grant_captain_gift_credit on public.trips;
create trigger trg_grant_captain_gift_credit
  after update on public.trips
  for each row
  execute function public.grant_captain_gift_credit();

-- Sum of this captain's still-valid, unredeemed gift credits.
create or replace function public.get_captain_gift_balance()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(amount), 0)
  from public.captain_gift_credits
  where captain_id = auth.uid()
    and redeemed_at is null
    and expires_at > now();
$$;

-- Redeems (marks as redeemed) every still-valid credit for the calling
-- captain, but only if their total is already at least 10 MRU - otherwise
-- raises, leaving all credits untouched. Returns the redeemed total so the
-- caller knows how much to add to the main wallet.
create or replace function public.redeem_captain_gift_credits()
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
  v_total numeric;
begin
  select coalesce(sum(amount), 0) into v_total
  from public.captain_gift_credits
  where captain_id = v_captain_id
    and redeemed_at is null
    and expires_at > now();

  if v_total < 10 then
    raise exception 'رصيد الهدايا أقل من 10 أوقية، لا يمكن التحويل بعد.';
  end if;

  update public.captain_gift_credits
  set redeemed_at = now()
  where captain_id = v_captain_id
    and redeemed_at is null
    and expires_at > now();

  return v_total;
end;
$$;
