-- Runway's rendered clips are silent. Each scene now also gets a narrated
-- voice track (Gemini TTS) rendered once and persisted here, so playback
-- never has to re-synthesize speech on every view.
alter table public.generated_video_scenes
  add column if not exists narration_audio_url text;
