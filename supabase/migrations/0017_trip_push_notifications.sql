-- Captain device push token, used by the send-trip-push Edge Function to
-- ring/full-screen a captain for a new trip even when the app is
-- backgrounded or fully killed (see lib/core/services/push_notifications.dart)
-- - in-app Supabase Realtime alone only fires while some Dart code from the
-- app is actually running.
alter table public.captains
  add column if not exists fcm_token text;

-- Lets a Postgres trigger call an Edge Function directly (net.http_post)
-- instead of needing a Database Webhook configured by hand in the dashboard.
create extension if not exists pg_net with schema extensions;

-- Fires send-trip-push the moment a trip's status becomes 'searching' (a
-- fresh request, or one that opened back up after e.g. a captain who'd
-- claimed it went offline) - protected by a shared secret header since this
-- call has no user session to check a JWT against.
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
        'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
      ),
      body := jsonb_build_object('trip_id', new.id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_new_trip_request on public.trips;
create trigger trg_notify_new_trip_request
  after insert or update on public.trips
  for each row
  execute function public.notify_new_trip_request();
