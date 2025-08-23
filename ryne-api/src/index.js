var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.ts
function json(data, init) {
  const body = typeof data === "string" ? data : JSON.stringify(data);
  const headers = new Headers(init?.headers);
  if (!headers.has("content-type")) headers.set("content-type", "application/json");
  return new Response(body, { ...init, headers });
}
__name(json, "json");
function notFound() {
  return json({ ok: false, error: "Not Found" }, { status: 404 });
}
__name(notFound, "notFound");
async function handleGenerateSchedule(req, env) {
  const payload = await req.json().catch(() => ({}));
  return json({ ok: true, route: "POST /schedule/generate", env: env.ENV, payload });
}
__name(handleGenerateSchedule, "handleGenerateSchedule");
async function handleRequest(request, env, _ctx) {
  const url = new URL(request.url);
  const { pathname } = url;
  if (request.method === "GET" && pathname === "/health") {
    return json({ ok: true, service: "ryne-api", env: env.ENV, now: Date.now() });
  }
  if (request.method === "POST" && pathname === "/schedule/generate") {
    try {
      return await handleGenerateSchedule(request, env);
    } catch (err) {
      return json({ ok: false, error: err?.message ?? "Internal Error" }, { status: 500 });
    }
  }
  if (request.method === "GET" && pathname === "/") {
    return json({ ok: true, service: "ryne-api", ts: Date.now() });
  }
  return notFound();
}
__name(handleRequest, "handleRequest");
var index_default = { fetch: handleRequest };
export {
  index_default as default
};
//# sourceMappingURL=index.js.map
