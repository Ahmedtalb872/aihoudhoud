-- Persists a completed trip's commission deduction server-side. Until now
-- _finalizeCompletedTrip() in AppStateProvider only subtracted the
-- commission from the in-memory _captainWalletBalance - nothing told the
-- server about it. The moment refreshWalletBalance() (added to sync a Bpay
-- recharge that settled while the app wasn't watching) re-reads
-- profiles.wallet_balance on the next app open or wallet-tab visit, it
-- would silently overwrite that local deduction with the stale
-- never-debited server value, making commissions vanish on their own.
--
-- Mirrors credit_captain_wallet_from_bpay's shape but subtracts, is scoped
-- to the caller's own row via auth.uid() (not a p_captain_id parameter -
-- a captain must never be able to debit someone else's wallet), and is
-- intentionally allowed to push wallet_balance negative: a captain who
-- collects a cash fare bigger than their remaining balance now owes the
-- company the difference, shown in the app as a negative balance rather
-- than silently capped at 0.

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

  insert into public.wallet_transactions (profile_id, amount, type, title, is_credit)
  values (uid, p_amount, 'commission', p_title, false);
end;
$$;

revoke all on function public.debit_captain_wallet(numeric, text) from public;
grant execute on function public.debit_captain_wallet(numeric, text) to authenticated;
