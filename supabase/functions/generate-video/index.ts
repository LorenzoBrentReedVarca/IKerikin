import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, range",
  "Access-Control-Expose-Headers":
    "accept-ranges, content-length, content-range, content-type",
};

const apiUrl = Deno.env.get("VIDEO_API_URL") ?? "https://api.openai.com/v1";
const model = Deno.env.get("VIDEO_MODEL") ?? "sora-2";
const apiKey = Deno.env.get("VIDEO_API_KEY") ?? Deno.env.get("AI_API_KEY");

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function providerHeaders() {
  if (!apiKey) {
    throw new Error(
      "VIDEO_API_KEY or AI_API_KEY is not configured in Supabase secrets.",
    );
  }
  return { Authorization: `Bearer ${apiKey}` };
}

async function providerJson(path: string, init?: RequestInit) {
  const response = await fetch(`${apiUrl}${path}`, {
    ...init,
    headers: {
      ...providerHeaders(),
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });
  if (!response.ok) {
    throw new Error(
      `Video provider error: ${response.status} ${await response.text()}`,
    );
  }
  return await response.json();
}

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (request.method === "GET") {
      const url = new URL(request.url);
      const videoId = url.searchParams.get("video_id");
      if (url.searchParams.get("action") !== "content" || !videoId) {
        return json({ error: "A video_id is required." }, 400);
      }

      const range = request.headers.get("range");
      const response = await fetch(
        `${apiUrl}/videos/${encodeURIComponent(videoId)}/content`,
        {
          headers: {
            ...providerHeaders(),
            ...(range ? { Range: range } : {}),
          },
        },
      );
      if (!response.ok) {
        return json(
          { error: `Unable to load video content (${response.status}).` },
          response.status,
        );
      }

      const headers = new Headers(corsHeaders);
      for (const name of [
        "accept-ranges",
        "content-length",
        "content-range",
        "content-type",
      ]) {
        const value = response.headers.get(name);
        if (value) headers.set(name, value);
      }
      headers.set("Content-Type", response.headers.get("content-type") ?? "video/mp4");
      return new Response(response.body, { status: response.status, headers });
    }

    const body = await request.json();
    if (body.action === "create") {
      const title = String(body.title ?? "Personalized lesson");
      const summary = String(body.summary ?? "");
      const story = String(body.story ?? "").slice(0, 2400);
      const prompt = [
        "Create a warm, colorful 3D animated educational short for children.",
        "Use a fictional child character with no resemblance to a real person.",
        "No on-screen text, logos, copyrighted characters, frightening imagery, or unsafe actions.",
        "Show one clear learning action with gentle pacing, expressive gestures, natural sound, and an encouraging ending.",
        `Lesson title: ${title}.`,
        `Learning objective: ${summary}.`,
        `Story context: ${story}`,
      ].join(" ");
      return json(
        await providerJson("/videos", {
          method: "POST",
          body: JSON.stringify({
            model,
            prompt,
            size: "1280x720",
            seconds: "8",
          }),
        }),
      );
    }

    if (body.action === "status" && body.video_id) {
      return json(
        await providerJson(
          `/videos/${encodeURIComponent(String(body.video_id))}`,
        ),
      );
    }

    return json({ error: "Unsupported video action." }, 400);
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});
