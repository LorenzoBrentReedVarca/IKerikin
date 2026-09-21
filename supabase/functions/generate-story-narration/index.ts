import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Synthesizes natural, expressive speech via Gemini's native TTS endpoint —
 * the same technique already used for animated-video scene narration, reused
 * here to give the Story mode "Listen" button a real voice instead of the
 * robotic on-device screen-reader fallback.
 */
async function synthesizeNarration(text: string): Promise<Uint8Array | null> {
  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey || !text.trim()) return null;
  const model = Deno.env.get("GEMINI_TTS_MODEL") ?? "gemini-2.5-flash-preview-tts";
  const voice = Deno.env.get("GEMINI_TTS_VOICE") ?? "Kore";
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `Say in a warm, gentle, storytelling voice for a young child, with natural pauses between sentences: ${text}`,
            }],
          }],
          generationConfig: {
            responseModalities: ["AUDIO"],
            speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } },
          },
        }),
      },
    );
    if (!response.ok) {
      console.error("Gemini TTS request failed", response.status, await response.text());
      return null;
    }
    const body = await response.json();
    const base64: string | undefined = body?.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
    if (!base64) return null;
    const pcm = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
    return pcmToWav(pcm, 24000, 1, 16);
  } catch (error) {
    console.error("Gemini TTS error", error);
    return null;
  }
}

/** Prepends a standard 44-byte WAV header to raw PCM samples. */
function pcmToWav(pcm: Uint8Array, sampleRate: number, channels: number, bitDepth: number): Uint8Array {
  const blockAlign = channels * (bitDepth / 8);
  const byteRate = sampleRate * blockAlign;
  const buffer = new ArrayBuffer(44 + pcm.length);
  const view = new DataView(buffer);
  const writeString = (offset: number, value: string) => {
    for (let i = 0; i < value.length; i++) view.setUint8(offset + i, value.charCodeAt(i));
  };
  writeString(0, "RIFF");
  view.setUint32(4, 36 + pcm.length, true);
  writeString(8, "WAVE");
  writeString(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitDepth, true);
  writeString(36, "data");
  view.setUint32(40, pcm.length, true);
  new Uint8Array(buffer, 44).set(pcm);
  return new Uint8Array(buffer);
}

function supabaseClientFor(request: Request) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authorization = request.headers.get("Authorization") ?? "";
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { lesson_id, child_id, story } = await request.json();
    const lessonId = String(lesson_id ?? "");
    const childId = String(child_id ?? "");
    const storyText = String(story ?? "");
    if (!lessonId || !childId) throw new Error("lesson_id and child_id are required.");
    if (!storyText.trim()) throw new Error("There is no story text to narrate.");

    const wav = await synthesizeNarration(storyText);
    if (!wav) throw new Error("Voice synthesis is unavailable right now.");

    const supabase = supabaseClientFor(request);
    const path = `${childId}/${lessonId}/story-narration.wav`;
    const { error: uploadError } = await supabase.storage
      .from("lesson-videos")
      .upload(path, wav, { contentType: "audio/wav", upsert: true });
    if (uploadError) throw new Error(uploadError.message);

    const url = supabase.storage.from("lesson-videos").getPublicUrl(path).data.publicUrl;

    const { data: lesson, error: fetchError } = await supabase
      .from("lessons")
      .select("content")
      .eq("id", lessonId)
      .single();
    if (fetchError) throw new Error(fetchError.message);

    const content = { ...(lesson.content as Record<string, unknown>), story_narration_url: url };
    const { error: updateError } = await supabase
      .from("lessons")
      .update({ content })
      .eq("id", lessonId);
    if (updateError) throw new Error(updateError.message);

    return json({ story_narration_url: url });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
