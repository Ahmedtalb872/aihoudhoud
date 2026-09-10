-- Delivery mode is no longer motorcycle-exclusive: any captain (car or
-- motorcycle) with accepts_delivery = true can see/accept delivery trips.
-- In exchange, a motorcycle captain now never sees/accepts a regular
-- 'ride' trip - motorcycles were never meant to carry passengers, that
-- restriction just wasn't enforced here before.
drop policy if exists "Open trip requests are visible to active captains" on public.trips;
create policy "Open trip requests are visible to active captains"
  on public.trips for select
  to authenticated
  using (
    status = 'searching'
    and captain_id is null
    and exists (
      select 1 from public.captains c
      where c.id = auth.uid()
        and c.status = 'approved'
        and (
          (service_type = 'ride' and c.vehicle_type <> 'motorcycle')
          or (service_type = 'delivery' and c.accepts_delivery)
        )
    )
  );

create or replace function public.captain_accept_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
  v_row public.trips;
begin
  if not exists (
    select 1 from public.captains
    where id = v_captain_id and status = 'approved' and is_online = true
  ) then
    raise exception 'Only an approved, online captain may accept a trip';
  end if;

  update public.trips
    set captain_id = v_captain_id, status = 'accepted', accepted_at = now()
    where id = p_trip_id
      and status = 'searching'
      and captain_id is null
      and (expires_at is null or expires_at > now())
      and (
        (
          service_type = 'ride'
          and exists (
            select 1 from public.captains c
            where c.id = v_captain_id and c.vehicle_type <> 'motorcycle'
          )
        )
        or (
          service_type = 'delivery'
          and exists (
            select 1 from public.captains c
            where c.id = v_captain_id and c.accepts_delivery
          )
        )
      )
    returning * into v_row;

  if not found then
    raise exception 'TRIP_UNAVAILABLE';
  end if;

  return v_row;
end;
$$;
