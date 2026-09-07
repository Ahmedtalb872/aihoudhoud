-- Lets the admin dashboard (the separate app-driver-customer repo)'s live
-- trip-tracking map show a captain's real-time position while a trip is in
-- progress. captain_locations_select (0022) already lets the captain
-- themself and an active trip's own customer read a row, but an admin
-- session had no read access at all - using the same public.is_admin()
-- every other admin-only RLS policy on this shared database already relies
-- on (defined by app-driver-customer's own migrations, e.g.
-- 20260712000006_rls_policies.sql - not this repo's unrelated, apparently
-- unused profiles.is_admin column from 0024_admin_role.sql).
drop policy if exists "captain_locations_admin_select" on public.captain_locations;
create policy "captain_locations_admin_select"
  on public.captain_locations for select
  to authenticated
  using (public.is_admin());

-- Realtime only pushes changes for tables added to this publication - the
-- admin dashboard's trip detail panel subscribes via
-- `.from('captain_locations').stream(...)`, which is silent with no error
-- if the table was never added here.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'captain_locations'
  ) then
    alter publication supabase_realtime add table public.captain_locations;
  end if;
end $$;
