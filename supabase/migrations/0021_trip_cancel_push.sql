-- Also fires send-trip-push when a trip LEAVES 'searching' (customer
-- cancelled, it expired, or another captain claimed it first), passing
-- event_type: 'cancelled' so the function can tell captains who were
-- alerted for it to stop ringing - covers the case where the captain's app
-- was backgrounded/killed when the cancellation happened, which the
-- in-app Realtime-based stop (AppStateProvider._subscribeToPendingRides)
-- can't reach since no Dart code is running.
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
      body := jsonb_build_object('trip_id', new.id, 'event_type', 'new')
    );
  elsif tg_op = 'UPDATE'
        and old.status = 'searching'
        and new.status is distinct from 'searching' then
    perform net.http_post(
      url := 'https://hdjxtnzwxqkrihhvssej.supabase.co/functions/v1/send-trip-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
        'Authorization', 'Bearer sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
        'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
      ),
      body := jsonb_build_object('trip_id', new.id, 'event_type', 'cancelled')
    );
  end if;
  return new;
end;
$$;
