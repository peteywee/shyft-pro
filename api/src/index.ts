export interface Env {
  COMMIT_SHA?: string;
  ENV?: string;
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const now = new Date().toISOString();

    if (url.pathname === "/health") {
      return Response.json({ ok: true, ts: now });
    }
    if (url.pathname === "/version") {
      return Response.json({
        service: "ryne-api",
        env: env.ENV || "dev",
        commit: env.COMMIT_SHA || "local",
        ts: now,
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        service: "ryne-api",
        path: url.pathname,
        env: env.ENV || "dev",
        commit: env.COMMIT_SHA || "local",
        ts: now,
      }),
      { headers: { "content-type": "application/json" }, status: 200 }
    );
  },
} satisfies ExportedHandler<Env>;
