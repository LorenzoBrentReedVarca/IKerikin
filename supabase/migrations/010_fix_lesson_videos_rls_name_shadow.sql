-- Migration 009's subquery used a bare `name` inside `EXISTS (... from
-- children c where ...)`. Postgres resolved that to children.name (child's
-- display name, e.g. "Zeus") instead of the intended storage.objects.name
-- (the upload path), since the inner scope's matching column wins — so the
-- fixed policy was still comparing the wrong thing and still always false.
-- Qualify the outer reference explicitly this time.
drop policy if exists "parents upload own lesson videos" on storage.objects;
drop policy if exists "parents update own lesson videos" on storage.objects;
drop policy if exists "parents delete own lesson videos" on storage.objects;

create policy "parents upload own lesson videos" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(storage.objects.name))[1] and c.parent_id = auth.uid()
    )
  );
create policy "parents update own lesson videos" on storage.objects for update to authenticated
  using (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(storage.objects.name))[1] and c.parent_id = auth.uid()
    )
  );
create policy "parents delete own lesson videos" on storage.objects for delete to authenticated
  using (
    bucket_id = 'lesson-videos'
    and exists(
      select 1 from public.children c
      where c.id::text = (storage.foldername(storage.objects.name))[1] and c.parent_id = auth.uid()
    )
  );
