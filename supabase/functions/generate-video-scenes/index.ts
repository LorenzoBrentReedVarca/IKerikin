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

type Status = "queued" | "generating" | "processing" | "completed" | "failed";

interface Scene {
  scene_number: number;
  duration_seconds: number;
  narration: string;
  visual_prompt: string;
  educational_objective: string;
}

interface ProviderTaskResult {
  status: Status;
  videoUrl?: string;
  errorMessage?: string;
}

/**
 * Abstraction every video generation backend must implement. Swapping
 * providers (Runway -> another vendor) only requires a new class here and a
 * `VIDEO_PROVIDER` secret change — the Flutter app and database schema never
 * need to know which vendor rendered a scene.
 */
interface VideoProvider {
  readonly name: string;
  createSceneTask(scene: Scene): Promise<{ providerJobId: string }>;
  getTaskStatus(providerJobId: string): Promise<ProviderTaskResult>;
}

/** Runway ML API (https://docs.dev.runwayml.com) text-to-video provider. */
class RunwayProvider implements VideoProvider {
  readonly name = "runway";

  private readonly apiKey = Deno.env.get("RUNWAY_API_KEY");
  private readonly baseUrl =
    Deno.env.get("RUNWAY_API_URL") ?? "https://api.dev.runwayml.com";
  private readonly apiVersion = Deno.env.get("RUNWAY_VERSION") ?? "2024-11-06";
  private readonly model = Deno.env.get("RUNWAY_MODEL") ?? "gen4.5";
  private readonly ratio = Deno.env.get("RUNWAY_RATIO") ?? "1280:720";

  private headers() {
    if (!this.apiKey) {
      throw new Error("RUNWAY_API_KEY is not configured in Supabase Edge Function secrets.");
    }
    return {
      Authorization: `Bearer ${this.apiKey}`,
      "X-Runway-Version": this.apiVersion,
      "Content-Type": "application/json",
    };
  }

  async createSceneTask(scene: Scene): Promise<{ providerJobId: string }> {
    // Child-safe prompt: never depict real people, on-screen text, or logos.
    const promptText = [
      scene.visual_prompt,
      "Colorful, gentle, child-friendly educational cartoon animation style.",
      "No on-screen text, no logos, no real people.",
    ].filter(Boolean).join(" ").slice(0, 900);

    const duration = Math.min(10, Math.max(5, Math.round(scene.duration_seconds)));

    const response = await fetch(`${this.baseUrl}/v1/text_to_video`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        model: this.model,
        promptText,
        ratio: this.ratio,
        duration,
      }),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(body?.error ?? `Runway request failed (${response.status}).`);
    }
    return { providerJobId: body.id as string };
  }

  async getTaskStatus(providerJobId: string): Promise<ProviderTaskResult> {
    const response = await fetch(`${this.baseUrl}/v1/tasks/${providerJobId}`, {
      headers: this.headers(),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(body?.error ?? `Runway status check failed (${response.status}).`);
    }
    switch (body.status) {
      case "SUCCEEDED":
        return { status: "completed", videoUrl: body.output?.[0] as string | undefined };
      case "FAILED":
      case "CANCELLED":
        return {
          status: "failed",
          errorMessage: body.failure ?? "The video provider failed to render this scene.",
        };
      case "RUNNING":
        return { status: "processing" };
      default:
        return { status: "generating" };
    }
  }
}

function createProvider(): VideoProvider {
  const name = Deno.env.get("VIDEO_PROVIDER") ?? "runway";
  switch (name) {
    case "runway":
      return new RunwayProvider();
    default:
      throw new Error(`Unsupported VIDEO_PROVIDER "${name}".`);
  }
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

/** Best-effort copy of a provider's (possibly temporary) video URL into permanent Supabase Storage. */
async function persistToStorage(
  supabase: ReturnType<typeof supabaseClientFor>,
  parentId: string,
  lessonId: string,
  sceneNumber: number,
  sourceUrl: string,
): Promise<string> {
  try {
    const response = await fetch(sourceUrl);
    if (!response.ok) return sourceUrl;
    const bytes = new Uint8Array(await response.arrayBuffer());
    const path = `${parentId}/${lessonId}/scene-${sceneNumber}.mp4`;
    const { error } = await supabase.storage
      .from("lesson-videos")
      .upload(path, bytes, { contentType: "video/mp4", upsert: true });
    if (error) return sourceUrl;
    return supabase.storage.from("lesson-videos").getPublicUrl(path).data.publicUrl;
  } catch (_error) {
    return sourceUrl;
  }
}

async function refreshJobStatus(
  supabase: ReturnType<typeof supabaseClientFor>,
  provider: VideoProvider,
  jobId: string,
) {
  const { data: job, error: jobError } = await supabase
    .from("video_generation_jobs")
    .select()
    .eq("id", jobId)
    .single();
  if (jobError) throw new Error(jobError.message);

  const { data: scenes, error: scenesError } = await supabase
    .from("generated_video_scenes")
    .select()
    .eq("job_id", jobId)
    .order("scene_number");
  if (scenesError) throw new Error(scenesError.message);

  for (const scene of scenes) {
    if (scene.generation_status === "completed" || scene.generation_status === "failed") continue;
    if (!scene.generation_job_id) continue;
    try {
      const result = await provider.getTaskStatus(scene.generation_job_id as string);
      const update: Record<string, unknown> = { generation_status: result.status };
      if (result.status === "completed" && result.videoUrl) {
        update.video_url = await persistToStorage(
          supabase,
          job.child_id as string,
          job.lesson_id as string,
          scene.scene_number as number,
          result.videoUrl,
        );
      }
      if (result.status === "failed") update.error_message = result.errorMessage;
      await supabase.from("generated_video_scenes").update(update).eq("id", scene.id);
      Object.assign(scene, update);
    } catch (error) {
      await supabase
        .from("generated_video_scenes")
        .update({
          generation_status: "failed",
          error_message: error instanceof Error ? error.message : "Unknown provider error.",
        })
        .eq("id", scene.id);
    }
  }

  const refreshed = (await supabase
    .from("generated_video_scenes")
    .select()
    .eq("job_id", jobId)
    .order("scene_number")).data ?? [];

  let jobStatus: Status = "generating";
  const failed = refreshed.find((s) => s.generation_status === "failed");
  const allCompleted = refreshed.length > 0 && refreshed.every((s) => s.generation_status === "completed");
  if (failed) {
    jobStatus = "failed";
  } else if (allCompleted) {
    jobStatus = "completed";
  } else if (refreshed.some((s) => s.generation_status === "processing")) {
    jobStatus = "processing";
  }

  await supabase
    .from("video_generation_jobs")
    .update({
      status: jobStatus,
      error_message: failed ? (failed.error_message as string | null) : null,
    })
    .eq("id", jobId);

  return { jobId, scenes: refreshed };
}

async function respondWithJob(supabase: ReturnType<typeof supabaseClientFor>, jobId: string) {
  const { data: job, error: jobError } = await supabase
    .from("video_generation_jobs")
    .select()
    .eq("id", jobId)
    .single();
  if (jobError) throw new Error(jobError.message);
  const { data: scenes, error: scenesError } = await supabase
    .from("generated_video_scenes")
    .select()
    .eq("job_id", jobId)
    .order("scene_number");
  if (scenesError) throw new Error(scenesError.message);
  return json({ job, scenes });
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const provider = createProvider();
    const supabase = supabaseClientFor(request);
    const body = await request.json();

    if (body.action === "create") {
      const lessonId = String(body.lesson_id);
      const childId = String(body.child_id);
      const scenes = (body.scenes as Scene[] | undefined) ?? [];
      if (scenes.length === 0) throw new Error("The lesson has no video scenes to render.");

      const { data: job, error: jobError } = await supabase
        .from("video_generation_jobs")
        .insert({ lesson_id: lessonId, child_id: childId, provider: provider.name, status: "queued" })
        .select()
        .single();
      if (jobError) throw new Error(jobError.message);

      const rows = scenes.map((scene) => ({
        job_id: job.id,
        lesson_id: lessonId,
        child_id: childId,
        scene_number: scene.scene_number,
        provider: provider.name,
        generation_status: "queued" as Status,
      }));
      const { data: sceneRows, error: insertError } = await supabase
        .from("generated_video_scenes")
        .insert(rows)
        .select();
      if (insertError) throw new Error(insertError.message);

      for (const row of sceneRows) {
        const scene = scenes.find((s) => s.scene_number === row.scene_number)!;
        try {
          const { providerJobId } = await provider.createSceneTask(scene);
          await supabase
            .from("generated_video_scenes")
            .update({ generation_status: "generating", generation_job_id: providerJobId })
            .eq("id", row.id);
        } catch (error) {
          await supabase
            .from("generated_video_scenes")
            .update({
              generation_status: "failed",
              error_message: error instanceof Error ? error.message : "Unknown provider error.",
            })
            .eq("id", row.id);
        }
      }

      const { data: refreshedScenes } = await supabase
        .from("generated_video_scenes")
        .select()
        .eq("job_id", job.id);
      const anyFailed = (refreshedScenes ?? []).every((s) => s.generation_status === "failed");
      await supabase
        .from("video_generation_jobs")
        .update({ status: anyFailed ? "failed" : "generating" })
        .eq("id", job.id);

      return await respondWithJob(supabase, job.id as string);
    }

    if (body.action === "status" && body.job_id) {
      await refreshJobStatus(supabase, provider, String(body.job_id));
      return await respondWithJob(supabase, String(body.job_id));
    }

    if (body.action === "retry" && body.job_id) {
      const jobId = String(body.job_id);
      const scenes = (body.scenes as Scene[] | undefined) ?? [];
      const { data: failedScenes, error } = await supabase
        .from("generated_video_scenes")
        .select()
        .eq("job_id", jobId)
        .eq("generation_status", "failed");
      if (error) throw new Error(error.message);

      for (const row of failedScenes ?? []) {
        try {
          // The client resends the lesson's original video script on retry so
          // the exact narration/visual prompts don't need to be persisted here.
          const scene = scenes.find((s) => s.scene_number === row.scene_number) ?? {
            scene_number: row.scene_number,
            duration_seconds: 8,
            narration: "",
            visual_prompt: "A colorful, friendly educational cartoon scene.",
            educational_objective: "",
          };
          const { providerJobId } = await provider.createSceneTask(scene);
          await supabase
            .from("generated_video_scenes")
            .update({
              generation_status: "generating",
              generation_job_id: providerJobId,
              error_message: null,
              video_url: null,
            })
            .eq("id", row.id);
        } catch (retryError) {
          await supabase
            .from("generated_video_scenes")
            .update({
              error_message: retryError instanceof Error ? retryError.message : "Retry failed.",
            })
            .eq("id", row.id);
        }
      }

      await supabase
        .from("video_generation_jobs")
        .update({ status: "generating", error_message: null })
        .eq("id", jobId);

      return await respondWithJob(supabase, jobId);
    }


    return json({ error: "Unsupported video generation action." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unknown error" }, 500);
  }
});
