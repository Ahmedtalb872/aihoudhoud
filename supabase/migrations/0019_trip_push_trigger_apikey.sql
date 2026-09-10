-- net.http_post from notify_new_trip_request() was hitting Supabase's edge
-- gateway with only a Content-Type + our own x-internal-secret header,
-- which the gateway rejects outright (401 INVALID_CREDENTIALS) before the
-- request ever reaches send-trip-push's code - the gateway always requires
-- a valid apikey/Authorization header regardless of that function's
-- "Verify JWT" setting, which only controls whether it must be a genuine
-- user JWT. The anon key is safe to embed here (it's the same public key
-- already shipped inside the Flutter client via env.json) - x-internal-
-- secret still does the real authorization check inside the function.
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
        'apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhkanh0bnp3eHFrcmloaHZzc2VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4MzkyOTAsImV4cCI6MjA5OTQxNTI5MH0.1bDOUcN5g6I4VWTA4HE8wXhSz30CsAXyCOAkSRvgnhs',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhkanh0bnp3eHFrcmloaHZzc2VqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4MzkyOTAsImV4cCI6MjA5OTQxNTI5MH0.1bDOUcN5g6I4VWTA4HE8wXhSz30CsAXyCOAkSRvgnhs',
        'x-internal-secret', 'b6b513f32e7d1c9f2d7a03b4cf3b5d098e955ea510b5fe8c'
      ),
      body := jsonb_build_object('trip_id', new.id)
    );
  end if;
  return new;
end;
$$;
