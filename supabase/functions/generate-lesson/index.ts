import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get("AI_API_KEY");
    const endpoint = Deno.env.get("AI_API_URL") ?? "https://api.openai.com/v1/chat/completions";
    const model = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";
    if (!apiKey) throw new Error("AI_API_KEY is not configured in Supabase Edge Function secrets.");
    const { request: lessonRequest, child } = await request.json();

    const videoDurationSeconds = Number(lessonRequest?.video_duration_seconds ?? 60);
    // Runway caps every single generation at 10 seconds, so reaching the
    // requested video length means chaining that many separate scenes —
    // each one is its own billed Runway render call.
    const sceneCount = Math.max(1, Math.round(videoDurationSeconds / 10));
    const contentType = String(lessonRequest?.content_type ?? "Story");

    // Spelling out one placeholder object per required scene (rather than a
    // single example the model can pattern-match as "just return one") is
    // what actually gets the scene count honored — a single-item example in
    // the schema template tends to get echoed back verbatim regardless of
    // what the surrounding prose says.
    const sceneStubs = Array.from(
      { length: sceneCount },
      (_, index) =>
        `{"scene_number":${index + 1},"duration_seconds":8,"narration":"","visual_prompt":"","educational_objective":""}`,
    ).join(",");

    const prompt = `Create a safe, strengths-based special education lesson package for a Filipino child. Never diagnose or provide medical advice. Use age-appropriate, respectful, and encouraging language tailored to the child's learning needs (e.g. short sentences and simple vocabulary for Dyslexia; short sections and frequent interaction for ADHD; simple vocabulary and repetition for Speech Delay).
Child profile: ${JSON.stringify(child)}
Lesson request: ${JSON.stringify(lessonRequest)}
Preferred content type: ${contentType}.
The animated video should last about ${videoDurationSeconds} seconds, split into exactly ${sceneCount} short scenes suitable for a video generation API. Each scene is its own separate video generation call, so the story's action MUST be divided across all ${sceneCount} scenes — never collapse the whole song/story into a single scene.
Return JSON only with this exact shape:
{"title":"","summary":"","objectives":[""],"story":"","video_script":[${sceneStubs}],"flashcards":[{"front":"","back":"","image_description":""}],"quiz":[{"question":"","options":["","",""],"correct_index":0,"explanation":"","difficulty":""}],"memory_game":[{"left":"","right":"","image_description":"","educational_connection":""}],"matching_activity":[{"left":"","right":"","image_description":"","educational_connection":""}],"daily_activity":"","parent_tips":[""]}.
The video_script array above already has ${sceneCount} slots (scene_number 1 through ${sceneCount}) — fill in every one of them with its own distinct narration line and visual_prompt continuing the story; do not merge scenes together or return fewer than ${sceneCount} entries.
Include 2-4 objectives, 5 flashcards, 5 quiz questions, 4 pairs per game, exactly ${sceneCount} video scenes (each 6-10 seconds, with a short child-friendly narration line and a detailed, child-safe visual_prompt describing a colorful animated cartoon scene for an AI video generator), and 4 parent tips. Visual prompts must never include real people, on-screen text, logos, or copyrighted characters. Respect the requested language and duration.`;
    const aiResponse = await fetch(endpoint, {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, temperature: 0.6, response_format: { type: "json_object" }, messages: [{ role: "system", content: "You are an inclusive Filipino special education curriculum designer." }, { role: "user", content: prompt }] }),
    });
    if (!aiResponse.ok) throw new Error(`AI provider error: ${aiResponse.status} ${await aiResponse.text()}`);
    const payload = await aiResponse.json();
    const content = JSON.parse(payload.choices[0].message.content);
    const returnedScenes = Array.isArray(content?.video_script) ? content.video_script.length : 0;
    if (returnedScenes !== sceneCount) {
      console.error(
        `Scene count mismatch: requested ${sceneCount} scenes for a ${videoDurationSeconds}s video, model returned ${returnedScenes}.`,
      );
    }
    return new Response(JSON.stringify(content), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});

