-- Storage bucket for captain verification documents (ID, license, gray card, ...).
-- Private bucket: files are only reachable via signed URLs / the owning captain's session.
-- Run this in the Supabase SQL editor, or via `supabase db push`.

insert into storage.buckets (id, name, public)
values ('captain-documents', 'captain-documents', false)
on conflict (id) do nothing;

-- Each captain may only read/write objects stored under a path prefixed with
-- their own auth uid, e.g. "<captain_id>/national_id.jpg".
create policy "captain_documents_storage_own"
  on storage.objects for all
  using (
    bucket_id = 'captain-documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'captain-documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
