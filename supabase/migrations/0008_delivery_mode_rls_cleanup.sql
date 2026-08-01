-- Migration 0006 added "captains_view_searching_trips" and
-- "captains_claim_searching_trip" on public.trips, with no awareness of
-- service_type or captain approval (delivery mode didn't exist yet).
-- Migration 0007 added a new, stricter SELECT policy ("Open trip requests
-- are visible to active captains") plus the captain_accept_trip() RPC for
-- claiming - but since Postgres combines multiple permissive policies with
-- OR, the old 0006 policies were still silently letting ANY authenticated
-- captain see and directly claim a delivery trip (or an unapproved
-- captain's, or a car captain's), regardless of the new checks. Drop them
-- now that the RPC is the only accept path and the new SELECT policy
-- covers the same ground (plus service_type/approval).

drop policy if exists "captains_view_searching_trips" on public.trips;
drop policy if exists "captains_claim_searching_trip" on public.trips;
