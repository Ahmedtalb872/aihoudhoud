-- Minimal admin capability: a flag on profiles (off by default for every
-- account) that unlocks the in-app admin dashboard and lets that account's
-- session read every captain's row, not just its own - needed to list all
-- captains' payout info in one screen instead of one SQL query per captain.

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

drop policy if exists "admins_view_all_captains" on public.captains;
create policy "admins_view_all_captains"
  on public.captains for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.is_admin = true
    )
  );
