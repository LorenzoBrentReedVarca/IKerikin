-- Preserve every lesson attempt so score improvement and time totals remain accurate.
alter table public.lesson_progress
  drop constraint if exists lesson_progress_lesson_id_child_id_key;

create index if not exists lesson_progress_lesson_child_idx
  on public.lesson_progress (lesson_id, child_id, completed_at desc);