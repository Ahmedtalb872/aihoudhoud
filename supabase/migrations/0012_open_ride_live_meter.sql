-- Persists the live open-ride meter (distance driven so far, and banked
-- waiting-time seconds) on the trip row itself, so it survives the captain
-- app being killed and relaunched mid-ride (e.g. after a connectivity drop)
-- instead of the fare meter silently restarting from zero.
alter table public.trips
  add column if not exists live_distance_km numeric not null default 0,
  add column if not exists live_idle_seconds numeric not null default 0;
