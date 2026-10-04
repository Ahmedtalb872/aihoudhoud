-- The customer app actually writes ride requests to `public.trips`, not
-- `public.rides` (which turned out to be an unused/legacy table - migration
-- 0005's policies are harmless leftovers, not removed here). This migration
-- gives online captains real-time access to `trips`, and makes sure a
-- `captains` row exists for every captain account (trips.captain_id is a
-- foreign key to captains.id, not directly to auth.users/profiles).

-- Captains can see unclaimed searching trips.
drop policy if exists "captains_view_searching_trips" on public.trips;
create policy "captains_view_searching_trips"
  on public.trips for select
  to authenticated
  using (status = 'searching' and captain_id is null);

-- Captains can see their own assigned trips.
drop policy if exists "captains_view_own_trips" on public.trips;
create policy "captains_view_own_trips"
  on public.trips for select
  to authenticated
  using (captain_id = auth.uid());

-- Captains can claim a searching trip (atomic accept) or mark themselves as
-- having ignored one (append to ignored_by without claiming it).
drop policy if exists "captains_claim_searching_trip" on public.trips;
create policy "captains_claim_searching_trip"
  on public.trips for update
  to authenticated
  using (status = 'searching' and captain_id is null)
  with check (
    (captain_id = auth.uid())
    or (status = 'searching' and captain_id is null)
  );

-- Captains can update their own assigned trip (status progression).
drop policy if exists "captains_update_own_trip" on public.trips;
create policy "captains_update_own_trip"
  on public.trips for update
  to authenticated
  using (captain_id = auth.uid())
  with check (captain_id = auth.uid());

-- Captains need the customer's name/phone to display an incoming request;
-- allow any authenticated user to read those two columns off profiles
-- (customers.id references profiles.id, same as captains.id does).
drop policy if exists "authenticated_view_basic_profile" on public.profiles;
create policy "authenticated_view_basic_profile"
  on public.profiles for select
  to authenticated
  using (true);

-- A captain can read and update their own row (e.g. is_online, vehicle info
-- filled in after registration).
drop policy if exists "captains_view_own_row" on public.captains;
create policy "captains_view_own_row"
  on public.captains for select
  to authenticated
  using (id = auth.uid());

drop policy if exists "captains_update_own_row" on public.captains;
create policy "captains_update_own_row"
  on public.captains for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Extend the sign-up trigger to also create a bare `captains` row (status
-- defaults to 'pending') whenever a captain registers - vehicle/city details
-- get filled in later via an update once the registration form collects
-- them, and admin approval flips `captains.status` to 'approved'.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role, email, is_approved)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'role', 'customer'),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'customer') <> 'captain'
  );

  if coalesce(new.raw_user_meta_data ->> 'role', 'customer') = 'captain' then
    insert into public.captains (id) values (new.id)
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;
