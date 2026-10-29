-- Schedules the daily morning/evening motivational push (see
-- supabase/functions/send-motivation-push) via pg_cron, replacing the
-- client-side flutter_local_notifications schedule that silently stopped
-- firing for captains whose phone had rebooted or whose battery manager
-- force-stopped the app in the background - see that function's header
-- comment for the full explanation. Mauritania is UTC+0 year-round, so
-- these UTC cron times need no conversion.
--
-- Reuses the same shared secret and publishable key already used by
-- notify_new_trip_request (migration 0020) to call an Edge Function from
-- Postgres via pg_net.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'motivation-push-morning',
  '0 8 * * *',
  $$
  select net.http_post(
    url := 'https://hdjxtnzwxqkrihhvssej.supabase.co/functions/v1/send-motivation-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
      'Authorization', 'Bearer sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
      'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
    ),
    body := jsonb_build_object('period', 'morning')
  );
  $$
);

select cron.schedule(
  'motivation-push-evening',
  '0 19 * * *',
  $$
  select net.http_post(
    url := 'https://hdjxtnzwxqkrihhvssej.supabase.co/functions/v1/send-motivation-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
      'Authorization', 'Bearer sb_publishable_K63bm3UI9aVz6U7z03agDQ_j8_LkL8v',
      'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
    ),
    body := jsonb_build_object('period', 'evening')
  );
  $$
);
