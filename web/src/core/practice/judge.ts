import type { PracticeQualityReport } from "./quality";
import type { CardLanguage } from "../data/schema";

export type RevisePracticeKind = "drill_ndjson" | "reading_context" | "article_practice" | "speaking_practice";

export function revisePracticePrompt(
  kind: RevisePracticeKind,
  content: string,
  report: PracticeQualityReport,
  language: CardLanguage = "en",
): string {
  const targetShape =
    kind === "drill_ndjson"
      ? "Return NDJSON only. Each line must be one drill object with kind, trapType, targetWord, testedSkill, difficulty, title, instruction, scenario, choices, answer, explanation, and whyWrong."
      : kind === "article_practice"
        ? "Return JSON only using the article_practice schema. Keep type, title, documentType, passage, targetWords, questions, and vocabularyNotes."
        : kind === "speaking_practice"
          ? "Return JSON only using the speaking_practice schema. Keep type, title, topic, passageText, and sentences (each with text, ipa, words containing word/ipa/startMs/endMs, and connectedSpeech)."
          : "Return JSON only using the reading_context schema. Keep type, format, documentType, title, passage or documents, questions, and targetWords.";

  const isChinese = language === "zh-CN";

  return [
    isChinese
      ? "You are a Chinese (Hán ngữ / HSK) practice quality judge and reviser."
      : "You are an IELTS practice quality judge and reviser.",
    isChinese
      ? "Revise the draft so it is realistic, grammatically correct, and useful for Chinese learners."
      : "Revise the draft so it is realistic, grammatically correct, and useful for IELTS learners.",
    "Fix these quality issues:",
    ...report.issues.slice(0, 10).map((issue) => `- ${issue}`),
    "Requirements:",
    "- Keep correct answers inside choices.",
    "- Use plausible distractors, not obviously unrelated choices.",
    isChinese
      ? "- Explanations must teach the trap or usage briefly in Vietnamese with Chinese characters and Pinyin when useful."
      : "- Explanations must teach the trap briefly in English with Vietnamese support when useful.",
    "- Do not add markdown or commentary.",
    targetShape,
    "Draft:",
    content,
  ].join("\n");
}
