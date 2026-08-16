import { parseManifest, type Manifest } from "@voca/core/data/schema";
import { bridgeAuthorizationHeader } from "../local-bridge";

const cacheBust = () => `v=${Date.now()}`;
const wait = (ms: number) => new Promise((resolve) => window.setTimeout(resolve, ms));

/** Loads the vocabulary manifest from the v2 backend (JWT). Shape: { version, cards: [...] }. */
async function fetchManifestOnce(): Promise<Manifest> {
  const response = await fetch(`/api/cards?${cacheBust()}`, {
    cache: "no-store",
    headers: { Accept: "application/json", ...bridgeAuthorizationHeader() },
  });
  if (!response.ok) {
    throw new Error(`Cannot load cards (${response.status})`);
  }
  const payload = (await response.json()) as {
    version?: string;
    cards?: Array<Record<string, unknown>>;
  };
  // v1's card schema uses .optional() (string | undefined) — nulls from the backend must be stripped.
  // It also requires a non-empty `file`; v2 dropped PNGs, so synthesize one from the slug.
  const rawCards = (Array.isArray(payload.cards) ? payload.cards : []).map((c) => {
    const clean: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(c)) {
      if (value !== null) clean[key] = value;
    }
    clean.file = (clean.file as string) || (clean.slug as string) || String(clean.word ?? "card");
    return clean;
  });
  const input = payload.version !== undefined ? { version: payload.version, cards: rawCards } : rawCards;
  return parseManifest(input);
}

export async function fetchManifest(): Promise<Manifest> {
  let lastError: unknown;
  for (const delay of [0, 120, 360]) {
    if (delay) await wait(delay);
    try {
      return await fetchManifestOnce();
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error("Cannot load manifest");
}

/** No printable PNG in v2 — cards render as structured faces. */
export function imagePath(_file: string): string {
  return "";
}
