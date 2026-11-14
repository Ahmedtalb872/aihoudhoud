-- Manual admin approval gate for captains: a captain can register and pick their
-- documents, but cannot use the app until an admin reviews the application and
-- flips this flag on (from the Supabase Table Editor: profiles -> is_approved).
-- Run this in the Supabase SQL editor, or via `supabase db push`.

alter table public.profiles
  add column is_approved boolean not null default true;

-- New captains start unapproved; everyone else (existing rows, customers)
-- keeps the default `true` set above so nothing already live gets blocked.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, user_type, is_approved)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce((new.raw_user_meta_data ->> 'user_type')::user_type, 'customer'),
    coalesce((new.raw_user_meta_data ->> 'user_type')::user_type, 'customer') <> 'captain'
  );
  return new;
end;
$$;
