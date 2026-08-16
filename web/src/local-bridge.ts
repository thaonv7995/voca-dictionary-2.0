// v2: the backend that serves this SPA is also the API origin (same-origin), and requests are
// authenticated with the end-user's JWT (from auth-store) instead of the v1 shared bridge token.
import { useAuthStore } from "./lib/auth-store";

export const DEFAULT_LOCAL_BRIDGE_ORIGIN = "";

export function resolvedLocalBridgeOrigin(_stored?: string): string {
  return "";
}

export function bridgeUrl(origin: string, pathname: string): string {
  const suffix = pathname.startsWith("/") ? pathname : `/${pathname}`;
  return `${origin}${suffix}`;
}

/** Returns the end-user JWT as a Bearer header (used for all /api/* calls). */
export function bridgeAuthorizationHeader(_token?: string): HeadersInit {
  const jwt = useAuthStore.getState().accessToken;
  return jwt ? { Authorization: `Bearer ${jwt}` } : {};
}

export function defaultVocaApiToken(): string {
  return "";
}

/** Persist a card's level to the backend so all clients (web/iOS) see the same state. */
export async function patchBridgeCardLevel(
  _bridgeOrigin: string,
  cardId: string,
  level: "new" | "learning" | "known" | "mastered",
  _options?: { authToken?: string },
): Promise<void> {
  const response = await fetch(`/api/cards/${encodeURIComponent(cardId)}/level`, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      ...bridgeAuthorizationHeader(),
    },
    body: JSON.stringify({ level }),
  });
  if (!response.ok) {
    const payload = (await response.json().catch(() => ({}))) as { error?: { message?: string } };
    throw new Error(payload?.error?.message || `PATCH ${response.status}`);
  }
}
