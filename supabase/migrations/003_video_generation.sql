-- Adds structured video-script fields to lesson requests and introduces the
-- animated lesson video generation pipeline (jobs + per-scene renders).
alter table public.lesson_requests
  add column if not exists video_duration_seconds integer not null default 60
    check (video_duration_seconds in (60, 180, 300)),
  add column if not exists content_type text not null default 'Story'
    check (content_type in ('Story', 'Educational Adventure', 'Cartoon Lesson', 'Interactive Lesson'));

create type public.video_generation_status as enum ('queued', 'generating', 'processing', 'completed', 'failed');

create table public.video_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  provider text not null default 'runway',
  status public.video_generation_status not null default 'queued',
  video_url text,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.generated_video_scenes (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.video_generation_jobs(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  scene_number integer not null check (scene_number > 0),
  provider text not null default 'runway',
  generation_status public.video_generation_status not null default 'queued',
  generation_job_id text,
  video_url text,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, scene_number)
);

create index video_generation_jobs_lesson_idx on public.video_generation_jobs(lesson_id, created_at desc);
create index generated_video_scenes_job_idx on public.generated_video_scenes(job_id, scene_number);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

create trigger video_generation_jobs_touch before update on public.video_generation_jobs
  for each row execute procedure public.touch_updated_at();
create trigger generated_video_scenes_touch before update on public.generated_video_scenes
  for each row execute procedure public.touch_updated_at();

alter table public.video_generation_jobs enable row level security;
alter table public.generated_video_scenes enable row level security;

-- Parents may only see/manage video generation for their own children's lessons.
create policy "parents manage own video jobs" on public.video_generation_jobs
  for all using (
    exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid())
    or public.is_admin()
  )
  with check (
    exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid())
    or public.is_admin()
  );

create policy "parents manage own video scenes" on public.generated_video_scenes
  for all using (
    exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid())
    or public.is_admin()
  )
  with check (
    exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid())
    or public.is_admin()
  );

-- Storage bucket for finalized lesson videos (combined scene renders).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lesson-videos', 'lesson-videos', true, 104857600, array['video/mp4'])
on conflict (id) do nothing;

create policy "public lesson videos" on storage.objects for select using (bucket_id = 'lesson-videos');
create policy "parents upload own lesson videos" on storage.objects for insert to authenticated
  with check (bucket_id = 'lesson-videos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "parents update own lesson videos" on storage.objects for update to authenticated
  using (bucket_id = 'lesson-videos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "parents delete own lesson videos" on storage.objects for delete to authenticated
  using (bucket_id = 'lesson-videos' and (storage.foldername(name))[1] = auth.uid()::text);
