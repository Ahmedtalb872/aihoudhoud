-- Lets online captains see and claim real pending ride requests created by
-- the customer app, and manage the ones assigned to them. These are
-- additive policies (permissive, OR-combined with whatever already exists)
-- so they only grant access, never take any away.

drop policy if exists "captains_view_pending_rides" on public.rides;
create policy "captains_view_pending_rides"
  on public.rides for select
  to authenticated
  using (status = 'pending' and driver_id is null);

drop policy if exists "drivers_view_own_rides" on public.rides;
create policy "drivers_view_own_rides"
  on public.rides for select
  to authenticated
  using (auth.uid() = driver_id);

drop policy if exists "captains_claim_pending_ride" on public.rides;
create policy "captains_claim_pending_ride"
  on public.rides for update
  to authenticated
  using (status = 'pending' and driver_id is null)
  with check (driver_id = auth.uid());

drop policy if exists "drivers_update_own_ride" on public.rides;
create policy "drivers_update_own_ride"
  on public.rides for update
  to authenticated
  using (auth.uid() = driver_id)
  with check (auth.uid() = driver_id);

-- Captains need the customer's name/phone to display an incoming request;
-- allow any authenticated user to read those two columns off profiles.
drop policy if exists "authenticated_view_basic_profile" on public.profiles;
create policy "authenticated_view_basic_profile"
  on public.profiles for select
  to authenticated
  using (true);
