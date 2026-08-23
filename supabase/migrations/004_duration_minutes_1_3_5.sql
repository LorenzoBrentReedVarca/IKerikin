-- Lessons are now offered in 1, 3, or 5 minute lengths only (matching the
-- Quick Lesson / Learning Adventure / Full Story video options), replacing
-- the old 5-60 minute range.
alter table public.lesson_requests
  drop constraint if exists lesson_requests_duration_minutes_check;

alter table public.lesson_requests
  add constraint lesson_requests_duration_minutes_check
  check (duration_minutes in (1, 3, 5));
