-- The live `profiles` table uses a `role` text column (and has an `email`
-- column too), not the `user_type` enum column earlier migrations assumed.
-- Rewrite the signup trigger to match the actual table so new accounts stop
-- failing/behaving unpredictably at signup.
-- Run this in the Supabase SQL editor, or via `supabase db push`.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role, email, is_approved)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'role', 'customer'),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'role', 'customer') <> 'captain'
  );
  return new;
end;
$$;
