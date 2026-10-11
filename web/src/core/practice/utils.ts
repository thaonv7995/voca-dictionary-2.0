export function escapeRawControlCharsInStrings(jsonStr: string): string {
  let result = "";
  let inString = false;
  let isEscaped = false;
  for (let i = 0; i < jsonStr.length; i++) {
    const char = jsonStr[i];
    if (char === '"' && !isEscaped) {
      inString = !inString;
      result += char;
    } else if (inString && (char === '\n' || char === '\r' || char === '\t')) {
      if (char === '\n') {
        result += '\\n';
      } else if (char === '\r') {
        if (jsonStr[i + 1] === '\n') {
          result += '\\n';
          i++;
        } else {
          result += '\\n';
        }
      } else if (char === '\t') {
        result += '\\t';
      }
    } else {
      result += char;
    }

    if (char === '\\' && inString) {
      isEscaped = !isEscaped;
    } else {
      isEscaped = false;
    }
  }
  return result;
}

export function parseJsonObject<T>(value: string): T {
  const sanitized = escapeRawControlCharsInStrings(value);
  const trimmed = sanitized.trim();
  if (trimmed.startsWith("⚠️") || trimmed.includes("Không gọi được LLM")) {
    throw new Error(trimmed);
  }
  try {
    return JSON.parse(trimmed) as T;
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) throw new Error("No JSON object found");
    return JSON.parse(match[0]) as T;
  }
}

export function normalizeAnswer(value: string): string {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[.,!?;:]+$/g, "")
    .replace(/\s+/g, " ");
}

export function stringHash(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

export function stableShuffleItems<T>(items: T[], seed: string): T[] {
  return [...items]
    .map((item, index) => ({ item, order: stringHash(`${seed}:${index}:${String(item)}`) }))
    .sort((first, second) => first.order - second.order)
    .map(({ item }) => item);
}

export function shuffleItems<T>(items: T[]): T[] {
  const shuffled = [...items];
  for (let index = shuffled.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
  }
  return shuffled;
}

/**
 * Strips parenthetical and inline Pinyin annotations so TTS voice reads only pure Chinese characters.
 * E.g. "谢谢！有你这样的朋友（péng yǒu），我（wǒ）觉得很幸运。" -> "谢谢！有你这样的朋友，我觉得很幸运。"
 */
export function extractSpokenChineseText(text: string): string {
  if (!text) return "";
  return text
    // Remove full-width or half-width parentheses containing pinyin / Latin letters
    .replace(/[（(][^）)]*[a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ][^）)]*[）)]/g, "")
    // Remove brackets with pinyin / Latin
    .replace(/[\[【][^\]】]*[a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ][^\]】]*[\]】]/g, "")
    // Remove any isolated Latin word tokens that don't belong to Chinese characters
    .replace(/(^|[\s\p{P}])+[a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+(?=[\s\p{P}]|$)/gu, "")
    // Normalize leftover whitespace
    .replace(/[ \t]+/g, " ")
    .replace(/\s+([，。！？；：、])/g, "$1")
    .trim();
}

/**
 * Extracts inline Pinyin tokens in parentheses from mixed text if the model put pinyin inline.
 * E.g. "谢谢！有你这样的朋友（péng yǒu），我（wǒ）觉得很幸运。" -> "péng yǒu wǒ"
 */
export function extractInlinePinyin(text: string): string | undefined {
  if (!text) return undefined;
  const matches = Array.from(text.matchAll(/[（(]([^）)]*[a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ][^）)]*)[）)]/g));
  if (!matches.length) return undefined;
  const combined = matches.map((m) => m[1].trim()).join(" ");
  return combined || undefined;
}

