import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Meshy AI Text to 3D — https://docs.meshy.ai/en/api/text-to-3d
const apiUrl = Deno.env.get("MESHY_API_URL") ?? "https://api.meshy.ai";
const aiModel = Deno.env.get("MESHY_MODEL") ?? "latest";
const apiKey = Deno.env.get("MESHY_API_KEY");

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function meshyJson(path: string, init?: RequestInit) {
  if (!apiKey) {
    throw new Error("MESHY_API_KEY is not configured in Supabase secrets.");
  }
  const response = await fetch(`${apiUrl}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });
  if (!response.ok) {
    throw new Error(
      `Model provider error: ${response.status} ${await response.text()}`,
    );
  }
  return await response.json();
}

interface MeshyTask {
  id: string;
  type: string;
  status: string;
  progress?: number;
  task_error?: { message?: string };
  model_urls?: { glb?: string };
}

// Maps Meshy's task vocabulary onto the {id, status, progress} shape the Flutter app expects.
function toGeneration(task: MeshyTask, stageOffset: number) {
  const status = task.status === "SUCCEEDED"
    ? "completed"
    : task.status === "FAILED" || task.status === "CANCELED"
    ? "failed"
    : "in_progress";
  return {
    id: task.id,
    status,
    progress: status === "completed"
      ? 100
      : status === "failed"
      ? 0
      : stageOffset + Math.round((task.progress ?? 0) / 2),
    error: status === "failed"
      ? task.task_error?.message ?? "3D model generation failed."
      : null,
    model_url: status === "completed" ? task.model_urls?.glb : undefined,
  };
}

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await request.json();

    if (body.action === "create") {
      const title = String(body.title ?? "Personalized lesson");
      const summary = String(body.summary ?? "");
      const story = String(body.story ?? "").slice(0, 300);
      const preferences = body.child_preferences ?? {};
      const interests = Array.isArray(preferences.interests)
        ? preferences.interests.map(String).slice(0, 5).join(", ")
        : "";
      const prompt = [
        "A warm, friendly 3D character or scene for a children's educational lesson.",
        "A fictional character or object with no resemblance to a real person, gentle and non-frightening.",
        "No on-screen text, logos, or copyrighted characters.",
        interests ? `Inspired by these interests: ${interests}.` : "",
        `Lesson title: ${title}.`,
        `Learning objective: ${summary}.`,
        story ? `Story context: ${story}` : "",
      ].filter(Boolean).join(" ").slice(0, 600);

      const created = await meshyJson("/openapi/v2/text-to-3d", {
        method: "POST",
        body: JSON.stringify({
          mode: "preview",
          prompt,
          ai_model: aiModel,
          moderation: true,
        }),
      });
      return json({ id: created.result, status: "in_progress", progress: 0, error: null });
    }

    if (body.action === "status" && body.video_id) {
      const task = await meshyJson(
        `/openapi/v2/text-to-3d/${encodeURIComponent(String(body.video_id))}`,
      );

      // Preview (untextured mesh) must succeed before texturing starts in a second, refine task.
      if (task.type === "text-to-3d-preview") {
        if (task.status === "SUCCEEDED") {
          const refine = await meshyJson("/openapi/v2/text-to-3d", {
            method: "POST",
            body: JSON.stringify({
              mode: "refine",
              preview_task_id: task.id,
              enable_pbr: true,
            }),
          });
          return json({ id: refine.result, status: "in_progress", progress: 50, error: null });
        }
        return json(toGeneration(task, 0));
      }

      return json(toGeneration(task, 50));
    }

    return json({ error: "Unsupported model action." }, 400);
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});
