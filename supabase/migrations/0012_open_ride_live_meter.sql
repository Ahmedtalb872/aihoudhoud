-- Persists the live open-ride meter (distance driven so far, banked
-- waiting-time seconds, and the last known GPS point) on the trip row
-- itself, so it survives the captain app being killed and relaunched
-- mid-ride (e.g. after a connectivity drop) instead of the fare meter
-- silently restarting from zero - and so the gap covered while the app was
-- down gets measured from the last known point instead of being dropped.
alter table public.trips
  add column if not exists live_distance_km numeric not null default 0,
  add column if not exists live_idle_seconds numeric not null default 0,
  add column if not exists live_last_lat double precision,
  add column if not exists live_last_lng double precision;
