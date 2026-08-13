-- The wallet recharge flow moved to a single Bankily/Bpay-style form
-- (amount + payer's own Bankily number + Bankily's verification code)
-- instead of a generic "amount + free-text reference" form for any of
-- several providers - payer_phone captures the number the captain paid
-- from, which the future live Bpay verification API call will need.
alter table public.wallet_recharge_requests
  add column if not exists payer_phone text;
