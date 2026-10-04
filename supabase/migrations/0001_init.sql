-- الهدهد (Alhudhud) — initial schema
-- Run this in the Supabase SQL editor, or via `supabase db push`.

create extension if not exists "pgcrypto";

create type user_type as enum ('customer', 'captain');
create type vehicle_type as enum ('economy', 'comfort', 'family');
create type trip_status as enum ('pending', 'searching', 'accepted', 'en_route', 'arrived', 'started', 'completed', 'cancelled');
create type transaction_type as enum ('charge', 'payment', 'refund', 'reward', 'withdraw', 'commission', 'transfer');
create type document_status as enum ('under_review', 'accepted', 'rejected', 'expired');

-- One row per auth.users entry
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  phone text not null unique,
  user_type user_type not null,
  avatar_url text,
  rating numeric(3, 2) not null default 5.0,
  trips_count integer not null default 0,
  wallet_balance numeric(10, 2) not null default 0,
  is_online boolean not null default false,
  acceptance_rate numeric(5, 2) default 100,
  cancellation_rate numeric(5, 2) default 0,
  created_at timestamptz not null default now()
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.profiles (id) on delete cascade,
  brand text not null,
  model text not null,
  year integer not null,
  color text not null,
  plate text not null,
  seats integer not null default 4,
  vehicle_type vehicle_type not null default 'economy',
  created_at timestamptz not null default now()
);

create table public.captain_documents (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.profiles (id) on delete cascade,
  doc_key text not null,
  doc_name text not null,
  file_path text,
  status document_status not null default 'under_review',
  uploaded_at timestamptz not null default now(),
  unique (captain_id, doc_key)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles (id),
  captain_id uuid references public.profiles (id),
  vehicle_id uuid references public.vehicles (id),
  pickup_location text not null,
  destination_location text not null,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  dest_lat double precision not null,
  dest_lng double precision not null,
  distance numeric(6, 2) not null,
  duration integer not null,
  price numeric(10, 2) not null,
  payment_method text not null,
  status trip_status not null default 'pending',
  car_type vehicle_type not null,
  is_open_ride boolean not null default false,
  open_ride_timeout integer not null default 45,
  net_earnings numeric(10, 2),
  commission numeric(10, 2),
  created_at timestamptz not null default now()
);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  trip_id uuid references public.trips (id),
  amount numeric(10, 2) not null,
  type transaction_type not null,
  title text not null,
  is_credit boolean not null,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  content text not null,
  is_location boolean not null default false,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

-- Single row per captain, overwritten on every location ping
create table public.captain_locations (
  captain_id uuid primary key references public.profiles (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  updated_at timestamptz not null default now()
);

-- Auto-create the profile row right after Supabase Auth creates the user
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, user_type)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce((new.raw_user_meta_data ->> 'user_type')::user_type, 'customer')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.captain_documents enable row level security;
alter table public.trips enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.notifications enable row level security;
alter table public.messages enable row level security;
alter table public.captain_locations enable row level security;

-- profiles: publicly readable (needed to show captain/customer info on a shared trip), owner-writable
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- vehicles: publicly readable (needed on the customer side), captain-writable
create policy "vehicles_select_all" on public.vehicles for select using (true);
create policy "vehicles_modify_own" on public.vehicles for all
  using (auth.uid() = captain_id) with check (auth.uid() = captain_id);

-- captain_documents: visible/writable only by the owning captain
create policy "captain_documents_own" on public.captain_documents for all
  using (auth.uid() = captain_id) with check (auth.uid() = captain_id);

-- trips: visible/writable only by the customer or captain on that trip
create policy "trips_select_participants" on public.trips for select
  using (auth.uid() = customer_id or auth.uid() = captain_id);
create policy "trips_insert_customer" on public.trips for insert
  with check (auth.uid() = customer_id);
create policy "trips_update_participants" on public.trips for update
  using (auth.uid() = customer_id or auth.uid() = captain_id);

-- wallet_transactions / notifications: owner only
create policy "wallet_transactions_own" on public.wallet_transactions for all
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
create policy "notifications_own" on public.notifications for all
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- messages: only participants of the related trip
create policy "messages_select_participants" on public.messages for select
  using (
    exists (
      select 1 from public.trips t
      where t.id = trip_id and (t.customer_id = auth.uid() or t.captain_id = auth.uid())
    )
  );
create policy "messages_insert_participants" on public.messages for insert
  with check (
    auth.uid() = sender_id and exists (
      select 1 from public.trips t
      where t.id = trip_id and (t.customer_id = auth.uid() or t.captain_id = auth.uid())
    )
  );

-- captain_locations: captain owns/writes their row; a customer may read it only while on an active trip with that captain
create policy "captain_locations_select" on public.captain_locations for select
  using (
    auth.uid() = captain_id or exists (
      select 1 from public.trips t
      where t.captain_id = captain_locations.captain_id
        and t.customer_id = auth.uid()
        and t.status in ('accepted', 'en_route', 'arrived', 'started')
    )
  );
create policy "captain_locations_modify_own" on public.captain_locations for all
  using (auth.uid() = captain_id) with check (auth.uid() = captain_id);
