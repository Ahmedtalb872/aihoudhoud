-- Delivery mode: a package-delivery service exclusive to motorcycle
-- captains, added as another mode of the same `trips` table (service_type)
-- rather than a separate table/app. Car captains never see delivery
-- requests, and motorcycle captains only see them once they explicitly
-- opt in via captains.delivery_mode_enabled.

alter table public.captains
  add column if not exists vehicle_category text not null default 'car'
    check (vehicle_category in ('car', 'motorcycle')),
  add column if not exists delivery_mode_enabled boolean not null default false;

alter table public.trips
  add column if not exists service_type text not null default 'ride'
    check (service_type in ('ride', 'delivery')),
  add column if not exists recipient_name text,
  add column if not exists recipient_phone text,
  add column if not exists package_description text;

-- Captains can see unclaimed searching trips - but a delivery request only
-- shows up for a captain who is a motorcycle captain with delivery mode on.
drop policy if exists "captains_view_searching_trips" on public.trips;
create policy "captains_view_searching_trips"
  on public.trips for select
  to authenticated
  using (
    status = 'searching'
    and captain_id is null
    and (
      service_type = 'ride'
      or exists (
        select 1 from public.captains c
        where c.id = auth.uid()
          and c.vehicle_category = 'motorcycle'
          and c.delivery_mode_enabled = true
      )
    )
  );

-- Same eligibility check on the claim policy, so a car captain (or a
-- motorcycle captain with delivery mode off) can't accept one either, even
-- if they somehow have the trip id.
drop policy if exists "captains_claim_searching_trip" on public.trips;
create policy "captains_claim_searching_trip"
  on public.trips for update
  to authenticated
  using (
    status = 'searching'
    and captain_id is null
    and (
      service_type = 'ride'
      or exists (
        select 1 from public.captains c
        where c.id = auth.uid()
          and c.vehicle_category = 'motorcycle'
          and c.delivery_mode_enabled = true
      )
    )
  )
  with check (
    (captain_id = auth.uid())
    or (status = 'searching' and captain_id is null)
  );
