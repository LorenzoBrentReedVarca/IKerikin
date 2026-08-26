-- The `lesson-videos` bucket was referenced by generate-video-scenes'
-- persistToStorage helper from the start but never actually created, so
-- every scene (video and now narration audio) has been silently falling
-- back to Runway's temporary, expiring signed CDN URL instead of a
-- permanent Supabase Storage URL.
insert into storage.buckets (id, name, public)
values ('lesson-videos', 'lesson-videos', true)
on conflict (id) do nothing;

-- Public read (URLs are unguessable UUIDs, matching how child-photos is
-- already exposed); only the service role (used by the edge function) may
-- write.
create policy "lesson videos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'lesson-videos');
