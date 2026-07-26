-- IKeriKin production schema, row-level security, storage, and admin metrics.
create extension if not exists pgcrypto;

create type public.app_role as enum ('parent', 'child', 'administrator');
create type public.lesson_status as enum ('pending', 'generating', 'completed', 'failed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  display_name text not null default 'Parent',
  role public.app_role not null default 'parent',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.children (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 100),
  birthday date not null,
  gender text not null default 'Prefer not to say',
  preferred_language text not null default 'English',
  disabilities text[] not null default '{}',
  challenges text[] not null default '{}',
  interests text[] not null default '{}',
  learning_styles text[] not null default '{}',
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.lesson_requests (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  goal text not null check (char_length(goal) between 5 and 500),
  difficulty text not null check (difficulty in ('easy', 'medium', 'challenging')),
  language text not null,
  duration_minutes integer not null check (duration_minutes between 5 and 60),
  additional_notes text not null default '',
  created_at timestamptz not null default now()
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  request_data jsonb not null,
  content jsonb not null,
  status public.lesson_status not null default 'completed',
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  quiz_score integer not null check (quiz_score between 0 and 100),
  time_spent_minutes integer not null check (time_spent_minutes between 0 and 600),
  completed_at timestamptz not null default now(),
  unique (lesson_id, child_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id),
  lesson_id uuid references public.lessons(id) on delete set null,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved')),
  created_at timestamptz not null default now()
);

create index children_parent_idx on public.children(parent_id);
create index lesson_requests_child_idx on public.lesson_requests(child_id);
create index lessons_child_created_idx on public.lessons(child_id, created_at desc);
create index progress_child_completed_idx on public.lesson_progress(child_id, completed_at desc);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, 'Parent'), '@', 1)), 'parent');
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'administrator');
$$;

alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.lesson_requests enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.categories enable row level security;
alter table public.reports enable row level security;

create policy "profiles own read or admin" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles own update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "parents or admins manage children" on public.children for all using (parent_id = auth.uid() or public.is_admin()) with check (parent_id = auth.uid() or public.is_admin());
create policy "parents manage lesson requests" on public.lesson_requests for all using (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin()) with check (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin());
create policy "parents manage lessons" on public.lessons for all using (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin()) with check (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin());
create policy "parents manage progress" on public.lesson_progress for all using (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin()) with check (exists(select 1 from public.children c where c.id = child_id and c.parent_id = auth.uid()) or public.is_admin());
create policy "categories readable" on public.categories for select to authenticated using (true);
create policy "admins manage categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "users create and read reports" on public.reports for insert with check (reporter_id = auth.uid());
create policy "users read own reports" on public.reports for select using (reporter_id = auth.uid() or public.is_admin());
create policy "admins update reports" on public.reports for update using (public.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('child-photos', 'child-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "public child photos" on storage.objects for select using (bucket_id = 'child-photos');
create policy "parents upload own child photos" on storage.objects for insert to authenticated with check (bucket_id = 'child-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "parents update own child photos" on storage.objects for update to authenticated using (bucket_id = 'child-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "parents delete own child photos" on storage.objects for delete to authenticated using (bucket_id = 'child-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function public.admin_dashboard_metrics() returns jsonb language sql stable security definer set search_path = public as $$
  select case when public.is_admin() then jsonb_build_object(
    'users', (select count(*) from profiles),
    'children', (select count(*) from children),
    'lessons', (select count(*) from lessons),
    'completed_lessons', (select count(*) from lesson_progress),
    'open_reports', (select count(*) from reports where status = 'open')
  ) else (select jsonb_build_object('error', 'forbidden')) end;
$$;

insert into public.categories(name, description) values
('Daily Living', 'Independent routines and self-care'),
('Communication', 'Expressive and receptive communication'),
('Literacy', 'Reading and writing foundations'),
('Numeracy', 'Math concepts and problem solving'),
('Social Emotional', 'Emotions, relationships, and social skills')
on conflict (name) do nothing;
