-- The Flutter app subscribes to live updates on `children` via
-- supabase_flutter's `.stream()`, which requires the table to be part of
-- the `supabase_realtime` publication. It never was, so every subscription
-- attempt looped forever with "Unable to subscribe to changes" and the
-- child list never loaded.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'children'
  ) then
    alter publication supabase_realtime add table public.children;
  end if;
end $$;
