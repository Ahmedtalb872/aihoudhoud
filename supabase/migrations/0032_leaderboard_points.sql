-- Replaces the captain app's leaderboard, which showed a hardcoded list of
-- ten made-up names/trip-counts (see lib/features/captain/leaderboard_screen.dart's
-- _kDummyLeaderboard) with a real one: points earned from actually
-- completed trips, shown as a daily top-3 (every captain sees this every
-- day) and a fuller weekly ranking (Monday-Sunday, matching the decision
-- to run the weekly prize week that way) that's what the end-of-week
-- prize winners are picked from.
--
-- points_per_trip, how many names the weekly list shows, and how many of
-- them actually win a prize are explicitly left to management to decide
-- and adjust - not hardcoded in the app. Change them any time with:
--
--   update public.leaderboard_settings set
--     points_per_trip = 1,              -- points awarded per completed trip
--     weekly_leaderboard_size = 10,      -- how many captains the weekly list shows
--     weekly_prize_winners_count = 3,    -- how many of those actually get a prize
--     weekly_prize_description = null;   -- optional note shown above the weekly list
--
-- (only one row ever exists - the `where true` matches it regardless of
-- its id).
create table if not exists public.leaderboard_settings (
  id boolean primary key default true check (id),
  points_per_trip numeric(10, 2) not null default 1,
  weekly_leaderboard_size int not null default 10,
  weekly_prize_winners_count int not null default 3,
  weekly_prize_description text
);

insert into public.leaderboard_settings (id)
values (true)
on conflict (id) do nothing;

alter table public.leaderboard_settings enable row level security;

drop policy if exists "leaderboard_settings_select_all" on public.leaderboard_settings;
create policy "leaderboard_settings_select_all"
  on public.leaderboard_settings for select
  to authenticated
  using (true);
-- No insert/update/delete policy for ordinary captains - only the
-- management SQL above (run with the service role, which bypasses RLS
-- entirely) can change these numbers.

-- Today's top captains by points (completed-trip count × points_per_trip).
-- Mauritania has no UTC offset or DST, so now()'s UTC "today" already is
-- the local day - no timezone conversion needed. security definer because
-- an ordinary captain's own RLS only lets them see their own trips/profile
-- (captains_view_own_trips, trips_select_participants) - this needs to
-- read across every captain's completed trips, but only ever returns a
-- name/count/points triple, never anything else off either row.
create or replace function public.get_daily_leaderboard(p_limit int default 3)
returns table (
  captain_id uuid,
  full_name text,
  trips_count bigint,
  points numeric
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.captain_id,
    coalesce(p.full_name, 'كابتن') as full_name,
    count(*) as trips_count,
    count(*) * (select s.points_per_trip from public.leaderboard_settings s limit 1) as points
  from public.trips t
  join public.profiles p on p.id = t.captain_id
  where t.status = 'completed'
    and t.completed_at >= date_trunc('day', now())
    and t.completed_at < date_trunc('day', now()) + interval '1 day'
  group by t.captain_id, p.full_name
  order by points desc, trips_count desc
  limit greatest(p_limit, 0);
$$;

grant execute on function public.get_daily_leaderboard(int) to authenticated;

-- This week's top captains (Monday 00:00 through the following Monday
-- 00:00, exclusive) - date_trunc('week', ...) already starts on Monday by
-- Postgres's own ISO-8601 convention, matching the Monday-Sunday week
-- management settled on. List length comes from
-- leaderboard_settings.weekly_leaderboard_size, not a hardcoded number.
create or replace function public.get_weekly_leaderboard()
returns table (
  captain_id uuid,
  full_name text,
  trips_count bigint,
  points numeric
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.captain_id,
    coalesce(p.full_name, 'كابتن') as full_name,
    count(*) as trips_count,
    count(*) * (select s.points_per_trip from public.leaderboard_settings s limit 1) as points
  from public.trips t
  join public.profiles p on p.id = t.captain_id
  where t.status = 'completed'
    and t.completed_at >= date_trunc('week', now())
    and t.completed_at < date_trunc('week', now()) + interval '7 days'
  group by t.captain_id, p.full_name
  order by points desc, trips_count desc
  limit (select greatest(s.weekly_leaderboard_size, 0) from public.leaderboard_settings s limit 1);
$$;

grant execute on function public.get_weekly_leaderboard() to authenticated;
