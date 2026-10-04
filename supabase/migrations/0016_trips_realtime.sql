-- AppStateProvider._subscribeToPendingRides() calls
-- Supabase.instance.client.from('trips').stream(...) to alert an online
-- captain the instant a new ride request appears (see NewTripAlert.play()).
-- That only works if the `trips` table is part of the `supabase_realtime`
-- publication - Postgres Changes streams silently receive nothing
-- otherwise, with no error anywhere, which is exactly why a captain sitting
-- online never got the ringing alert for a new trip: the table was never
-- added to the publication in any migration.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'trips'
  ) then
    alter publication supabase_realtime add table public.trips;
  end if;
end $$;
