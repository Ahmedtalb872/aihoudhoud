-- captainCancelActiveTrip() used to mark the trip 'cancelled' outright -
-- a permanent dead end that the customer's request also died with, even
-- though they still wanted a ride and another nearby captain could easily
-- have taken over. RLS also structurally couldn't have supported anything
-- else: "captains_update_own_trip" (0006_trips_captain_access.sql) requires
-- captain_id = auth.uid() in its WITH CHECK clause too, so a captain could
-- never have cleared their own captain_id via a plain client-side update
-- even if the Dart side had tried to.
--
-- This RPC lets a captain release a trip they haven't started yet (picked
-- up the passenger) back into the open pool instead - captain_id cleared,
-- status back to 'searching'. notify_new_trip_request() (0021) already
-- fires the same push captains get for a brand new request whenever a row
-- re-enters 'searching', so this alone is enough for it to actually reach
-- other online captains, no separate notification plumbing needed. A trip
-- already 'started' (or any other state) can't be released this way -
-- the customer is already in the vehicle by then, so "hand it to someone
-- else" no longer makes sense; captainCancelActiveTrip() itself already
-- hides its cancel button once a trip reaches that point.
create or replace function public.captain_release_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
  v_row public.trips;
begin
  update public.trips
    set captain_id = null,
        status = 'searching',
        accepted_at = null,
        arrived_at = null
    where id = p_trip_id
      and captain_id = v_captain_id
      and status in ('accepted', 'arrived')
    returning * into v_row;

  if not found then
    raise exception 'TRIP_NOT_RELEASABLE';
  end if;

  return v_row;
end;
$$;

grant execute on function public.captain_release_trip(uuid) to authenticated;
