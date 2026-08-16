// The backend wraps every JSON API response in a consistent { status, code, message, data }
// envelope (so third parties hitting /v1 get a professional, uniform contract). This interceptor
// transparently unwraps that envelope back to the shape the web already consumes — raw `data` on
// success, `{ error: { code, message } }` on failure — so no call site needs to change.
//
// Only same-origin /api and /v1 JSON responses are touched; SSE (LLM proxy), audio bytes and the
// Markdown docs are non-JSON and pass through untouched.

const originalFetch = window.fetch.bind(window);

window.fetch = (async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
  const res = await originalFetch(input, init);
  try {
    const rawUrl = typeof input === "string" ? input : input instanceof URL ? input.href : (input as Request).url;
    const path = new URL(rawUrl, window.location.origin).pathname;
    const isApi = path.startsWith("/api/") || path.startsWith("/v1/");
    const contentType = res.headers.get("content-type") || "";
    if (isApi && contentType.includes("application/json")) {
      const env = await res.clone().json();
      if (env && typeof env === "object" && "data" in env && "code" in env && "status" in env) {
        const legacy = res.ok ? env.data : { error: { code: env.code, message: env.message } };
        const body = legacy === undefined ? "null" : JSON.stringify(legacy);
        return new Response(body, {
          status: res.status,
          statusText: res.statusText,
          headers: { "content-type": "application/json" },
        });
      }
    }
  } catch {
    /* not an envelope / not JSON — return the original response unchanged */
  }
  return res;
}) as typeof window.fetch;
