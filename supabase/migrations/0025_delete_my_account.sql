-- Real in-app account deletion: the settings screen's "حذف الحساب نهائياً"
-- button used to just log the captain out without deleting anything, which
-- would violate Play's data-deletion policy now that the store listing
-- declares an in-app deletion path. This RPC deletes the caller's auth
-- user (cascading to profiles -> captains/documents/locations/wallet/etc.)
-- after first detaching the rows that would block the cascade:
--
--   - trips have no cascade from profiles/captains by design; a deleted
--     captain's trips are kept but anonymized (captain_id nulled), and a
--     deleted customer's trips are removed outright (customer_id is NOT
--     NULL so they can't be anonymized) - matching delete-account.html's
--     "trip/financial records retained without personal identifiers".
--   - messages.sender_id has no cascade either; those rows are deleted.
--   - the captain's uploaded document files in the private
--     captain-documents bucket live under a '<uid>/...' prefix.
--
-- security definer (runs as the function owner) is what authorizes both
-- the auth.users delete and the storage.objects delete on the caller's
-- own data only - auth.uid() scopes every statement.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  update public.trips set captain_id = null where captain_id = uid;
  delete from public.trips where customer_id = uid;
  delete from public.messages where sender_id = uid;

  delete from storage.objects
  where bucket_id = 'captain-documents'
    and name like uid::text || '/%';

  delete from public.captains where id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
