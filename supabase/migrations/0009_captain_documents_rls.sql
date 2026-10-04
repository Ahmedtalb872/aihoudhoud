-- public.captain_documents has row level security enabled but had zero
-- policies on it (confirmed empty table + Supabase Studio's "Add RLS
-- policy" prompt) - that silently blocks every insert/select from the app
-- for every role except service_role, which is why documents a captain
-- uploads never actually land in this table even though the app reports
-- "uploaded" (the client-side error is swallowed into a generic warning).

drop policy if exists "captains_manage_own_documents" on public.captain_documents;
create policy "captains_manage_own_documents"
  on public.captain_documents
  for all
  to authenticated
  using (captain_id = auth.uid())
  with check (captain_id = auth.uid());
