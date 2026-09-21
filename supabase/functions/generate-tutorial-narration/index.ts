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
 * Synthesizes calm, reassuring speech for the app's parent-facing onboarding
 * tutorial. Same Gemini native-TTS technique as the story and video-scene
 * narration, but the prompt is tuned for an adult audience (slower, steadier,
 * no "storytelling" energy) since this is guidance for parents, not a
 * children's story.
 */
async function synthesizeNarration(text: string): Promise<Uint8Array | null> {
  const apiKey = Deno.env.get("AI_API_KEY");
  if (!apiKey || !text.trim()) return null;
  const model = Deno.env.get("GEMINI_TTS_MODEL") ?? "gemini-2.5-flash-preview-tts";
  const voice = Deno.env.get("GEMINI_TTS_TUTORIAL_VOICE") ?? Deno.env.get("GEMINI_TTS_VOICE") ?? "Kore";
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `Say in a calm, warm, reassuring voice for a busy parent, speaking clearly and at an easy, unhurried pace: ${text}`,
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
    const { step_id, text } = await request.json();
    const stepId = String(step_id ?? "").replace(/[^a-z0-9-]/gi, "");
    const stepText = String(text ?? "");
    if (!stepId) throw new Error("step_id is required.");
    if (!stepText.trim()) throw new Error("There is no narration text for this step.");

    const wav = await synthesizeNarration(stepText);
    if (!wav) throw new Error("Voice synthesis is unavailable right now.");

    const supabase = supabaseClientFor(request);
    const path = `tutorial/${stepId}.wav`;
    const { error: uploadError } = await supabase.storage
      .from("lesson-videos")
      .upload(path, wav, { contentType: "audio/wav", upsert: true });
    if (uploadError) throw new Error(uploadError.message);

    const url = supabase.storage.from("lesson-videos").getPublicUrl(path).data.publicUrl;
    return json({ narration_url: url });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
