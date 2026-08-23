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
let refreshInFlight: Promise<boolean> | null = null;

async function doRefresh(): Promise<boolean> {
  const rt = useAuthStore.getState().refreshToken;
  if (!rt) return false;
  try {
    const res = await fetch("/api/auth/refresh", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: rt }),
    });
    if (res.ok) {
      useAuthStore.getState().setAuth(await res.json());
      return true;
    }
  } catch {
    return false; // offline: keep the session, let the caller surface a network error
  }
  // Rejected — but if another tab rotated the token while this was in flight, its refresh is the
  // one that landed. Adopt the credentials it stored rather than logging everyone out.
  const current = useAuthStore.getState().refreshToken;
  return current !== null && current !== rt;
}

function tryRefresh(): Promise<boolean> {
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
  if (opts.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  return fetch(path, { ...opts, headers });
}

/**
 * Authenticated request returning the raw Response — for non-JSON payloads (TTS audio, the
 * Markdown API docs, SSE streams). Attaches the JWT, and on 401 refreshes once and retries.
 * Throws ApiError(401) after clearing the session when the refresh itself is dead.
 */
export async function apiFetch(path: string, opts: RequestInit = {}): Promise<Response> {
  const sentToken = useAuthStore.getState().accessToken;
  const res = await send(path, opts, sentToken);
  if (res.status !== 401 || NO_REFRESH_PATHS.has(pathOf(path))) return res;

  // A concurrent request may already have rotated the token while this one was in flight —
  // retry with the new one rather than burning another rotation.
  const current = useAuthStore.getState().accessToken;
  const refreshed = current !== sentToken && current !== null ? true : await tryRefresh();
  if (refreshed) {
    const retried = await send(path, opts, useAuthStore.getState().accessToken);
    if (retried.status !== 401) return retried;
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
