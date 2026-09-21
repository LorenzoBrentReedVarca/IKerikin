-- The onboarding tutorial's narration audio is shared, static app content
-- (not tied to any single child), so it lives at `lesson-videos/tutorial/*`
-- instead of the per-child `{child_id}/...` paths the existing lesson-video
-- policies check ownership against. Those policies reject this prefix
-- outright since no `children` row ever matches "tutorial". Read access is
-- already public via migration 007's bucket-wide select policy.
create policy "authenticated users can upload tutorial narration"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'lesson-videos' and (storage.foldername(name))[1] = 'tutorial');

create policy "authenticated users can update tutorial narration"
  on storage.objects for update to authenticated
  using (bucket_id = 'lesson-videos' and (storage.foldername(name))[1] = 'tutorial');
