-- captain_locations was defined in 0001_init.sql but is missing from the
-- live database (never actually created there, even though every later
-- migration/feature that reads or writes it - online-presence tracking in
-- AppStateProvider, the 2km pending-ride radius, the send-trip-push Edge
-- Function's distance filter - assumed it existed). Recreated here,
-- idempotently, so re-running this migration is harmless if the table
-- does turn out to already exist by the time this runs.

create table if not exists public.captain_locations (
  captain_id uuid primary key references public.profiles (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  updated_at timestamptz not null default now()
);

alter table public.captain_locations enable row level security;

drop policy if exists "captain_locations_select" on public.captain_locations;
create policy "captain_locations_select" on public.captain_locations for select
  using (
    auth.uid() = captain_id or exists (
      select 1 from public.trips t
      where t.captain_id = captain_locations.captain_id
        and t.customer_id = auth.uid()
        and t.status in ('accepted', 'arrived', 'in_progress', 'boarded')
    )
  );

drop policy if exists "captain_locations_modify_own" on public.captain_locations;
create policy "captain_locations_modify_own" on public.captain_locations for all
  using (auth.uid() = captain_id) with check (auth.uid() = captain_id);
