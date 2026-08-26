-- The bucket was originally restricted to video/mp4 only (migration 003).
-- It now also stores per-scene narration audio, so widen the allowlist.
update storage.buckets
set allowed_mime_types = array['video/mp4', 'audio/wav', 'audio/mpeg']
where id = 'lesson-videos';
