-- The captain app has been writing arrived_at/boarded_at/started_at/
-- completed_at/final_price/cancelled_at/cancelled_by/cancellation_reason on
-- every trip status change since these flows were built (see
-- AppStateProvider.captainArriveAtPickup/captainStartActiveTrip/
-- captainCompleteActiveTrip/cancel-trip), but no migration ever added these
-- columns to public.trips. Supabase rejects an update that references an
-- unknown column - as one statement, so `status` itself never landed either
-- - and that failure was silently swallowed by the .catchError((_) {}) on
-- every one of those calls. Net effect: a trip's status (and therefore the
-- live open-ride meter, which only restores when status = 'started') never
-- actually persisted past "accepted", so restoreActiveTripIfAny() had
-- nothing real to restore after a connectivity drop or app relaunch and the
-- trip/meter appeared to reset to zero.
alter table public.trips
  add column if not exists arrived_at timestamptz,
  add column if not exists boarded_at timestamptz,
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists final_price numeric(10, 2),
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by text,
  add column if not exists cancellation_reason text;
