-- This project has moved to Supabase's new API key system (Publishable/
-- Secret keys) - the legacy JWT-format anon key we were sending is no
-- longer accepted by the edge gateway at all (confirmed: even Supabase's
-- own "Test" tool got 401 INVALID_CREDENTIALS with it, both as anon and
-- postgres role). Swap to the new publishable key, which is the direct
-- equivalent of the old anon key (safe to embed - it's meant for
-- client-side use, same as the old one was).
create or replace function public.notify_new_trip_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'searching'
     and (tg_op = 'INSERT' or old.status is distinct from 'searching') then
    perform net.http_post(
      url := 'https://hdjxtnzwxqkrihhvssej.supabase.co/functions/v1/send-trip-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
        'Authorization', 'Bearer sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
        'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
      ),
      body := jsonb_build_object('trip_id', new.id)
    );
  end if;
  return new;
end;
$$;
