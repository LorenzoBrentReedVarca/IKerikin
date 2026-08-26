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
    const { child } = await request.json();

    const lessonCount = 6;

    // Spelling out one placeholder per required lesson (rather than a single
    // example) is what actually gets the count honored by the model instead
    // of silently collapsing the array to one item.
    const lessonStubs = Array.from(
      { length: lessonCount },
      () => `{"goal":"","difficulty":"easy","content_type":"Story"}`,
    ).join(",");

    const prompt = `You are building a brand-new child's very first learning shelf. This family cannot afford a special education school, so this starter curriculum may be the only structured, personalized learning material this child gets — make it genuinely useful.
Child profile: ${JSON.stringify(child)}
Suggest exactly ${lessonCount} distinct, practical, confidence-building lesson goals for this child to learn first, based on their age, disabilities, challenges, and interests. Favor everyday living skills, communication, social skills, safety, and gentle early academics. Never diagnose, medicalize, or reference the disability directly in the goal text — write each goal the warm, plain way a parent would describe it (e.g. "Learn how to wash hands before eating", "Learn to say please and thank you", "Learn to recognize feelings like happy and sad"). Weave in the child's interests where it fits naturally (e.g. build the goal or its story around their favorite animal, character, or hobby) to keep it engaging. Vary the ${lessonCount} goals so no two teach the same skill, and vary "difficulty" and "content_type" across them so the shelf feels varied, not repetitive.
Return JSON only with this exact shape:
{"lessons":[${lessonStubs}]}
The "lessons" array above already has ${lessonCount} slots — fill in every one of them; do not merge lessons together or return fewer than ${lessonCount} entries. "difficulty" must be exactly one of "easy", "medium", "challenging" (default to "easy" for younger or more challenged learners). "content_type" must be exactly one of "Story", "Educational Adventure", "Cartoon Lesson", "Interactive Lesson". Each "goal" must be a short, specific, one-sentence learning goal in the requested language.`;

    const aiResponse = await fetch(endpoint, {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model, temperature: 0.8, response_format: { type: "json_object" }, messages: [{ role: "system", content: "You are an inclusive Filipino special education curriculum designer." }, { role: "user", content: prompt }] }),
    });
    if (!aiResponse.ok) throw new Error(`AI provider error: ${aiResponse.status} ${await aiResponse.text()}`);
    const payload = await aiResponse.json();
    const content = JSON.parse(payload.choices[0].message.content);
    const lessons = Array.isArray(content?.lessons) ? content.lessons.slice(0, lessonCount) : [];
    if (lessons.length !== lessonCount) {
      console.error(`Starter plan count mismatch: requested ${lessonCount}, model returned ${lessons.length}.`);
    }
    if (lessons.length === 0) throw new Error("The AI did not return any starter lessons.");
    return new Response(JSON.stringify({ lessons }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
