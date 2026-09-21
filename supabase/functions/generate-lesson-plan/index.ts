import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// `lesson_requests` CHECK-constrains difficulty and content_type to these
// exact sets and bounds goal length. The prompt below asks for valid values
// but cannot bind the model to them, and an off-list value fails the insert
// on the client — where both callers swallow the error, so it surfaces as
// the lesson shelf quietly not growing. Normalize before returning.
const DIFFICULTIES = ["easy", "medium", "challenging"];
const CONTENT_TYPES = ["Story", "Educational Adventure", "Cartoon Lesson", "Interactive Lesson"];
const MIN_GOAL_LENGTH = 5;
const MAX_GOAL_LENGTH = 500;

function normalizeLesson(raw: unknown) {
  const item = (raw ?? {}) as Record<string, unknown>;
  const goal = String(item.goal ?? "").trim();
  // Too short to satisfy the column's length check — drop it rather than
  // return a stub that fails the insert for the whole lesson.
  if (goal.length < MIN_GOAL_LENGTH) return null;
  const difficulty = String(item.difficulty ?? "");
  const contentType = String(item.content_type ?? "");
  return {
    goal: goal.length <= MAX_GOAL_LENGTH
      ? goal
      : `${goal.slice(0, MAX_GOAL_LENGTH - 1).trimEnd()}…`,
    difficulty: DIFFICULTIES.includes(difficulty) ? difficulty : "easy",
    content_type: CONTENT_TYPES.includes(contentType) ? contentType : "Story",
  };
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const apiKey = Deno.env.get("AI_API_KEY");
    const endpoint = Deno.env.get("AI_API_URL") ?? "https://api.openai.com/v1/chat/completions";
    const model = Deno.env.get("AI_MODEL") ?? "gpt-4o-mini";
    if (!apiKey) throw new Error("AI_API_KEY is not configured in Supabase Edge Function secrets.");
    const { child, count } = await request.json();

    const requested = Number(count);
    const lessonCount = Number.isFinite(requested)
      ? Math.min(6, Math.max(1, Math.round(requested)))
      : 6;

    // Spelling out one placeholder per required lesson (rather than a single
    // example) is what actually gets the count honored by the model instead
    // of silently collapsing the array to one item.
    const lessonStubs = Array.from(
      { length: lessonCount },
      () => `{"goal":"","difficulty":"easy","content_type":"Story"}`,
    ).join(",");

    // `count: 1` is the daily-refresh call (see the app's DailyLessonController) —
    // the child already has an ongoing shelf, so the framing and "vary against
    // each other" instructions below need to differ from the brand-new-profile
    // starter curriculum, even though both share this same endpoint and shape.
    const isDailyRefresh = lessonCount === 1;
    const intro = isDailyRefresh
      ? "You are choosing today's new lesson for a child who already has an ongoing learning shelf."
      : "You are building a brand-new child's very first learning shelf. This family cannot afford a special education school, so this starter curriculum may be the only structured, personalized learning material this child gets — make it genuinely useful.";
    const varietyNote = isDailyRefresh
      ? 'Pick a goal that likely has not been covered by this child\'s existing lessons yet, so each day feels new.'
      : `Vary the ${lessonCount} goals so no two teach the same skill, and vary "difficulty" and "content_type" across them so the shelf feels varied, not repetitive.`;

    const prompt = `${intro}
Child profile: ${JSON.stringify(child)}
Suggest exactly ${lessonCount} distinct, practical, confidence-building lesson goal${lessonCount === 1 ? "" : "s"} for this child to learn ${isDailyRefresh ? "next" : "first"}, based on their age, disabilities, challenges, and interests. Favor everyday living skills, communication, social skills, safety, and gentle early academics. Never diagnose, medicalize, or reference the disability directly in the goal text — write each goal the warm, plain way a parent would describe it (e.g. "Learn how to wash hands before eating", "Learn to say please and thank you", "Learn to recognize feelings like happy and sad"). Weave in the child's interests where it fits naturally (e.g. build the goal or its story around their favorite animal, character, or hobby) to keep it engaging. ${varietyNote}
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
    const returned = Array.isArray(content?.lessons) ? content.lessons.slice(0, lessonCount) : [];
    const lessons = returned.map(normalizeLesson).filter((item) => item !== null);
    if (lessons.length !== lessonCount) {
      console.error(
        `Lesson plan shortfall: requested ${lessonCount}, model returned ${returned.length}, ${lessons.length} usable after normalizing.`,
      );
    }
    if (lessons.length === 0) throw new Error("The AI did not return any usable starter lessons.");
    return new Response(JSON.stringify({ lessons }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
