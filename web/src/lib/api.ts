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

async function tryRefresh(): Promise<boolean> {
  const rt = useAuthStore.getState().refreshToken;
  if (!rt) return false;
  const res = await fetch("/api/auth/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refreshToken: rt }),
  });
  if (!res.ok) return false;
  useAuthStore.getState().setAuth(await res.json());
  return true;
}

/** Authenticated JSON request with one automatic token refresh + retry on 401. */
export async function api<T>(path: string, opts: RequestInit = {}, retry = true): Promise<T> {
  const token = useAuthStore.getState().accessToken;
  const headers = new Headers(opts.headers);
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (opts.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");

  const res = await fetch(path, { ...opts, headers });

  if (res.status === 401 && retry) {
    if (await tryRefresh()) return api<T>(path, opts, false);
    useAuthStore.getState().clear();
    throw new ApiError(401, "UNAUTHORIZED", "Phiên đăng nhập đã hết hạn.");
  }
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
