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
    const prompt = `Create a safe, strengths-based special education lesson for a Filipino child. Never diagnose or provide medical advice. Use age-appropriate, respectful language.\nChild profile: ${JSON.stringify(child)}\nLesson request: ${JSON.stringify(lessonRequest)}\nReturn JSON only with this exact shape: {"title":"","summary":"","story":"","flashcards":[{"front":"","back":""}],"quiz":[{"question":"","options":["","",""],"correct_index":0,"explanation":""}],"memory_game":[{"left":"","right":""}],"matching_activity":[{"left":"","right":""}],"daily_activity":"","parent_tips":[""]}. Include 5 flashcards, 5 quiz questions, 4 pairs per game, and 4 parent tips. Respect the requested language and duration.`;
    const aiResponse = await fetch(endpoint, {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, temperature: 0.6, response_format: { type: "json_object" }, messages: [{ role: "system", content: "You are an inclusive Filipino special education curriculum designer." }, { role: "user", content: prompt }] }),
    });
    if (!aiResponse.ok) throw new Error(`AI provider error: ${aiResponse.status} ${await aiResponse.text()}`);
    const payload = await aiResponse.json();
    const content = JSON.parse(payload.choices[0].message.content);
    return new Response(JSON.stringify(content), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
