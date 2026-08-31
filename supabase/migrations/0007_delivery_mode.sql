-- Delivery mode: a package-delivery service exclusive to motorcycle
-- captains, added as another mode of the same `trips` table (service_type)
-- rather than a separate table/app.
--
-- This is what was actually applied on the database side - it differs from
-- an earlier draft of this file (there is no separate vehicle_category
-- column: 'motorcycle' is just another value of the existing
-- captains.vehicle_type; the delivery opt-in flag is captains.accepts_
-- delivery, not delivery_mode_enabled; and accepting a trip now goes
-- through the captain_accept_trip() RPC below instead of a plain client
-- UPDATE).

alter table public.pricing_config drop constraint if exists pricing_config_vehicle_type_check;
alter table public.pricing_config
  add constraint pricing_config_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

alter table public.trips drop constraint if exists trips_vehicle_type_check;
alter table public.trips
  add constraint trips_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

alter table public.captains drop constraint if exists captains_vehicle_type_check;
alter table public.captains
  add constraint captains_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

insert into public.pricing_config (
  vehicle_type, base_fare, price_per_km, price_per_minute,
  minimum_fare, waiting_fee_per_minute, cancellation_fee
) values (
  'motorcycle', 35, 15, 2, 70, 1, 0
)
on conflict (vehicle_type) do nothing;

alter table public.captains
  add column if not exists accepts_delivery boolean not null default false;

alter table public.trips
  add column if not exists service_type text not null default 'ride'
    check (service_type in ('ride', 'delivery'));

alter table public.trips add column if not exists recipient_name text;
alter table public.trips add column if not exists recipient_phone text;
alter table public.trips add column if not exists package_description text;

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
          service_type = 'ride'
          or (service_type = 'delivery' and c.vehicle_type = 'motorcycle' and c.accepts_delivery)
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
        service_type = 'ride'
        or (
          service_type = 'delivery'
          and exists (
            select 1 from public.captains c
            where c.id = v_captain_id
              and c.vehicle_type = 'motorcycle'
              and c.accepts_delivery
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

create or replace function public.customer_request_trip(
  p_pickup_address text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_trip_type text default 'normal',
  p_destination_address text default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null,
  p_vehicle_type text default 'economy',
  p_payment_method text default 'cash',
  p_customer_note text default null,
  p_timeout_seconds integer default 300,
  p_passenger_count integer default 1,
  p_service_type text default 'ride',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_package_description text default null
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_row public.trips;
  v_vehicle_type text := p_vehicle_type;
begin
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from public.customers where id = v_customer_id) then
    raise exception 'Only a customer account may request a trip';
  end if;
  if p_service_type not in ('ride', 'delivery') then
    raise exception 'Invalid service type: %', p_service_type;
  end if;
  if p_pickup_lat is null or p_pickup_lng is null then
    raise exception 'Pickup coordinates are required';
  end if;

  if p_service_type = 'delivery' then
    if p_recipient_name is null or btrim(p_recipient_name) = '' then
      raise exception 'Recipient name is required for a delivery';
    end if;
    if p_recipient_phone is null or btrim(p_recipient_phone) = '' then
      raise exception 'Recipient phone is required for a delivery';
    end if;
    if p_destination_lat is null or p_destination_lng is null then
      raise exception 'Delivery drop-off coordinates are required';
    end if;
    v_vehicle_type := 'motorcycle';
  else
    if p_trip_type not in ('normal', 'open') then
      raise exception 'Invalid trip type: %', p_trip_type;
    end if;
  end if;

  insert into public.trips (
    customer_id, status, trip_type,
    pickup_address, pickup_lat, pickup_lng,
    destination_address, destination_lat, destination_lng,
    vehicle_type, payment_method, customer_note, passenger_count,
    service_type, recipient_name, recipient_phone, package_description,
    requested_at, expires_at
  ) values (
    v_customer_id, 'searching',
    case when p_service_type = 'delivery' then 'normal' else p_trip_type end,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_destination_address, p_destination_lat, p_destination_lng,
    v_vehicle_type, p_payment_method, p_customer_note,
    greatest(coalesce(p_passenger_count, 1), 1),
    p_service_type,
    case when p_service_type = 'delivery' then p_recipient_name else null end,
    case when p_service_type = 'delivery' then p_recipient_phone else null end,
    case when p_service_type = 'delivery' then p_package_description else null end,
    now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  return v_row;
end;
$$;
