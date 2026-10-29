-- Lets a captain record which mobile-payment service and phone number the
-- company should use to pay them out (salary settlements, bonuses/rewards)
-- - captured once in the app instead of the company having to ask every
-- captain individually each time a payment is due.

alter table public.captains
  add column if not exists payout_method text,
  add column if not exists payout_phone text;

alter table public.captains drop constraint if exists captains_payout_method_check;
alter table public.captains
  add constraint captains_payout_method_check
  check (payout_method is null or payout_method in ('bankily', 'masrvi', 'sedad', 'other'));
