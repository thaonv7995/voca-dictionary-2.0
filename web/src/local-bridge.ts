// v2: the backend that serves this SPA is also the API origin (same-origin), and requests are
// authenticated with the end-user's JWT (from auth-store) instead of the v1 shared bridge token.
import { api } from "./lib/api";
import { useAuthStore } from "./lib/auth-store";

export const DEFAULT_LOCAL_BRIDGE_ORIGIN = "";

export function resolvedLocalBridgeOrigin(_stored?: string): string {
  return "";
}

export function bridgeUrl(origin: string, pathname: string): string {
  const suffix = pathname.startsWith("/") ? pathname : `/${pathname}`;
  return `${origin}${suffix}`;
}

/**
 * Returns the end-user JWT as a Bearer header. /api/* calls go through api()/apiFetch() instead —
 * this is only for the two leftover v1-bridge routes (/tts-cache, /v1/**), which are not on the
 * JWT realm and so must not get the 401-refresh-retry treatment.
 */
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
  await api(`/api/cards/${encodeURIComponent(cardId)}/level`, {
    method: "PATCH",
    body: JSON.stringify({ level }),
  });
}
