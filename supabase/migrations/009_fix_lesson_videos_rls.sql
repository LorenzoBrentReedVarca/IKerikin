-- The original policies required the upload path's first folder to equal
-- auth.uid() (the parent), but the edge function has always uploaded under
-- the child's id instead (`${child_id}/${lesson_id}/...`) — every upload
-- silently failed RLS and fell back to the provider's temporary signed URL.
-- Match the actual path convention: authorize by child ownership instead.
drop policy if exists "parents upload own lesson videos" on storage.objects;
drop policy if exists "parents update own lesson videos" on storage.objects;
drop policy if exists "parents delete own lesson videos" on storage.objects;

create policy "parents upload own lesson videos" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(name))[1] and c.parent_id = auth.uid()
    )
  );
create policy "parents update own lesson videos" on storage.objects for update to authenticated
  using (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(name))[1] and c.parent_id = auth.uid()
    )
  );
create policy "parents delete own lesson videos" on storage.objects for delete to authenticated
  using (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(name))[1] and c.parent_id = auth.uid()
    )
  );
