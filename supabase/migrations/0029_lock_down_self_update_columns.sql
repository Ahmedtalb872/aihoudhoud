-- profiles_update_own (0001_init.sql) and captains_update_own_row
-- (0006_trips_captain_access.sql) both grant `update ... using (auth.uid() =
-- id)` with no `with check` and no column restriction. RLS's using/with
-- check clauses only ever constrain *which rows* a statement can touch, not
-- *which columns* - so any authenticated captain can call the Supabase REST
-- API directly (no app change needed, just their own JWT) and set
-- profiles.wallet_balance to any value, profiles.is_admin = true, or
-- captains.status = 'approved', completely bypassing the manual document
-- review gate and every wallet/rating integrity check this app relies on.
--
-- RLS can't express "this column is server-only" - a BEFORE UPDATE trigger
-- can, by rejecting a change to a protected column unless it's happening
-- inside a security definer function (debit_captain_wallet,
-- credit_captain_wallet_from_bpay, admin tooling, etc.), which runs as the
-- function's owner - current_user reflects that owner during execution,
-- while a raw client UPDATE via PostgREST always runs as `authenticated`.
-- That's the signal this trigger keys off, not the row's owner (auth.uid()
-- already established that a captain edited their own row - the question
-- here is whether they used a real API or the raw table).

create or replace function public.reject_protected_column_self_edit()
returns trigger
language plpgsql
as $$
begin
  if current_user = 'authenticated' then
    if tg_table_name = 'profiles' then
      if new.wallet_balance is distinct from old.wallet_balance
        or new.is_admin is distinct from old.is_admin
        or new.rating is distinct from old.rating
        or new.trips_count is distinct from old.trips_count
        or new.acceptance_rate is distinct from old.acceptance_rate
        or new.cancellation_rate is distinct from old.cancellation_rate
      then
        raise exception 'protected_column_self_edit: profiles';
      end if;
    elsif tg_table_name = 'captains' then
      if new.status is distinct from old.status then
        raise exception 'protected_column_self_edit: captains';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reject_protected_profile_edit on public.profiles;
create trigger trg_reject_protected_profile_edit
  before update on public.profiles
  for each row
  execute function public.reject_protected_column_self_edit();

drop trigger if exists trg_reject_protected_captain_edit on public.captains;
create trigger trg_reject_protected_captain_edit
  before update on public.captains
  for each row
  execute function public.reject_protected_column_self_edit();
