import { useAuthStore } from "./auth-store";

export class ApiError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

// These issue or exchange credentials, so a 401 from them is a real answer ("wrong password",
// "refresh token expired"), not an expired access token. Refreshing + retrying would both loop
// and replace the backend's message with a misleading "session expired".
const NO_REFRESH_PATHS = new Set(["/api/auth/login", "/api/auth/register", "/api/auth/refresh"]);

function pathOf(url: string): string {
  try {
    return new URL(url, window.location.origin).pathname;
  } catch {
    return url;
  }
}

// Refresh tokens rotate (UserService.refresh deletes the old row), so two concurrent refreshes
// mean the loser gets INVALID_REFRESH and logs the user out. The app polls the manifest every
// 15s alongside user-triggered calls, so concurrent 401s are the normal case, not the rare one.
// Everyone shares one in-flight attempt.
type RefreshOutcome = "refreshed" | "invalid" | "transient";

let refreshInFlight: Promise<RefreshOutcome> | null = null;

async function doRefresh(): Promise<RefreshOutcome> {
  const rt = useAuthStore.getState().refreshToken;
  if (!rt) return "invalid";
  let res: Response;
  try {
    res = await fetch("/api/auth/refresh", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: rt }),
    });
  } catch {
    return "transient"; // offline: keep the session, let the caller surface a network error
  }
  if (res.ok) {
    useAuthStore.getState().setAuth(await res.json());
    return "refreshed";
  }
  if (res.status >= 500) {
    return "transient";
  }
  // Rejected (401/403) — if another tab rotated the token while this was in flight, adopt its credentials.
  const current = useAuthStore.getState().refreshToken;
  return current !== null && current !== rt ? "refreshed" : "invalid";
}

function tryRefresh(): Promise<RefreshOutcome> {
  if (!refreshInFlight) {
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

function send(path: string, opts: RequestInit, token: string | null): Promise<Response> {
  const headers = new Headers(opts.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (opts.body && !(opts.body instanceof FormData) && !(opts.body instanceof Blob) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  return fetch(path, { ...opts, headers });
}

export async function logoutSession(): Promise<void> {
  const { refreshToken, accessToken } = useAuthStore.getState();
  if (refreshToken) {
    try {
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (accessToken) headers["Authorization"] = `Bearer ${accessToken}`;
      await fetch("/api/auth/logout", {
        method: "POST",
        headers,
        body: JSON.stringify({ refreshToken }),
      });
    } catch {
      /* best-effort server revocation */
    }
  }
  try {
    const preserve = new Set(["voca.theme", "voca.language"]);
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const key = localStorage.key(i);
      if (key && key.startsWith("voca.") && !preserve.has(key)) {
        localStorage.removeItem(key);
      }
    }
  } catch {
    /* ignore storage errors */
  }
  useAuthStore.getState().clear();
}

/**
 * Authenticated request returning the raw Response — for non-JSON payloads (TTS audio, the
 * Markdown API docs, SSE streams). Attaches the JWT, and on 401 refreshes once and retries.
 * Throws ApiError(401) after clearing the session only when the refresh token itself is rejected.
 */
export async function apiFetch(path: string, opts: RequestInit = {}): Promise<Response> {
  const sentToken = useAuthStore.getState().accessToken;
  const res = await send(path, opts, sentToken);
  if (res.status !== 401 || NO_REFRESH_PATHS.has(pathOf(path))) return res;

  // A concurrent request may already have rotated the token while this one was in flight —
  // retry with the new one rather than burning another rotation.
  const current = useAuthStore.getState().accessToken;
  const outcome: RefreshOutcome = current !== sentToken && current !== null ? "refreshed" : await tryRefresh();
  if (outcome === "refreshed") {
    const retried = await send(path, opts, useAuthStore.getState().accessToken);
    if (retried.status !== 401) return retried;
  } else if (outcome === "transient") {
    throw new ApiError(503, "NETWORK_ERROR", "Không kết nối được máy chủ để làm mới phiên.");
  }

  useAuthStore.getState().clear(); // flips the auth gate back to the login screen
  throw new ApiError(401, "UNAUTHORIZED", "Phiên đăng nhập đã hết hạn.");
}

/** Authenticated JSON request with one automatic token refresh + retry on 401. */
export async function api<T>(path: string, opts: RequestInit = {}): Promise<T> {
  const res = await apiFetch(path, opts);

  if (!res.ok) {
    let code = "ERROR";
    let message = res.statusText;
    try {
      const body = await res.json();
      if (body?.error) {
        code = body.error.code ?? code;
        message = body.error.message ?? message;
      }
    } catch {
      /* non-JSON error body */
    }
    throw new ApiError(res.status, code, message);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}
