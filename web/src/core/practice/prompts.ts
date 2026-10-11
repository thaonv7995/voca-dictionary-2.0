import { shuffleItems } from "./utils";
import type { ReadingFormat } from "./types";
import type { CardLanguage } from "../data/schema";

export function drillPrompt(
  targetVocabularyIndex: string[],
  selectedWord?: string,
  count = 5,
  contextDescription = "All words",
  weaknessContext = "No recorded practice mistakes yet.",
  language: CardLanguage = "en",
): string {
  if (language === "zh-CN") {
    return [
      `You are creating ${count} friendly everyday Chinese (Hán ngữ giao tiếp đời sống) vocabulary practice questions for a casual hobbyist learner.`,
      "This is for casual hobby learning (daily life, food, travel, shopping, casual communication), NOT high-stress academic exams.",
      "Use targetVocabularyIndex as the active learning context and the full list of allowed target answers.",
      "For wrong choices and supporting context, create plausible Chinese distractors (similar Hanzi, homophones, near-synonyms, common mix-ups) yourself when the target list is small.",
      `Active context: ${contextDescription}.`,
      "The targetVocabularyIndex is ordered by learning priority: new and learning words first, mastered words last. Prefer earlier unmastered words.",
      weaknessContext,
      "Use exact Chinese words or phrases from targetVocabularyIndex as correct answers whenever possible.",
      "For wrong choices, create plausible distractors yourself in Chinese characters. Do not make every A/B/C/D choice come only from targetVocabularyIndex when it has fewer than 4 items.",
      "Each question must be unique and use a different target answer if possible.",
      "Mix these fun practice kinds across the batch: scenario, rescue, collocation, error_spotting, trap, reverse.",
      "scenario: practical daily life / travel / food / casual chat scenario in simplified Chinese characters with Pinyin.",
      "rescue: a friendly conversation line that sounds awkward or slightly incorrect, asking the learner to pick the natural word/phrase.",
      "collocation: pick the natural daily compound or collocation (e.g. đi chợ, ăn cơm, uống trà, xem phim...).",
      "error_spotting: show a short everyday Chinese sentence with one wrong word/character. The 4 choices are words from the sentence, and the answer is the wrong one.",
      "trap: test a common casual confusion such as homophones, wrong measure word (lượng từ), confusing character radicals, or Pinyin tone confusion.",
      "reverse: give a clear Vietnamese meaning or Sino-Vietnamese (âm Hán Việt) hint and ask the learner to pick the matching Chinese word.",
      "Return exactly 4 choices for all questions.",
      "One choice must be the answer. The other choices must be realistic distractors based on character, sound, pinyin, or meaning.",
      "Randomize the answer position across A/B/C/D.",
      "The explanation must be warm and helpful in Vietnamese, including Chinese characters, Pinyin with tone marks, and Sino-Vietnamese (âm Hán Việt) where helpful.",
      "whyWrong must briefly explain why each wrong choice is wrong in friendly Vietnamese.",
      "Set targetWord to the exact tested answer when possible, testedSkill to a short skill label, and difficulty to easy or medium.",
      "Prefer the currently selected word as answer if it can make a good question. Otherwise choose any good target from targetVocabularyIndex.",
      "Return NDJSON only: each line must be one compact JSON object for one drill.",
      "Each line shape: {\"kind\":\"scenario|rescue|collocation|error_spotting|trap|reverse\",\"trapType\":\"...\",\"targetWord\":\"...\",\"testedSkill\":\"...\",\"difficulty\":\"easy|medium|hard\",\"title\":\"...\",\"instruction\":\"...\",\"scenario\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\",\"whyWrong\":{\"choice\":\"reason\"}}.",
      "Do not wrap the lines in an array. Do not use markdown.",
      selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
      `Target vocabulary index JSON: ${JSON.stringify(targetVocabularyIndex)}`,
    ].join("\n");
  }

  return [
    `You are creating ${count} IELTS vocabulary drills.`,
    "Use targetVocabularyIndex as the active learning context and the full list of allowed target answers.",
    "For wrong choices and supporting context, create plausible IELTS/academic distractors yourself when the target list is small.",
    `Active context: ${contextDescription}.`,
    "The targetVocabularyIndex is ordered by learning priority: new and learning words first, mastered words last. Prefer earlier unmastered words.",
    weaknessContext,
    "Use recent mistakes to choose trap types and target words, but do not repeat the exact same prompt.",
    "Use exact words or phrases from targetVocabularyIndex as correct answers whenever possible.",
    "For wrong choices, create plausible distractors yourself. Do not make every A/B/C/D choice come only from targetVocabularyIndex when it has fewer than 4 items.",
    "Each drill must be unique and use a different target answer if possible.",
    "Mix these drill kinds across the batch: scenario, rescue, collocation, error_spotting, trap, reverse.",
    "Use trapType from this taxonomy: same_word_family, wrong_preposition, near_synonym_wrong_context, similar_spelling, similar_sound, grammar_mismatch, collocation_mismatch, too_literal, academic_register.",
    "scenario: create a short academic, scientific, or general training situation and ask which word fits.",
    "rescue: show one incorrect or awkward sentence using a confusing word/collocation, then ask the learner to choose the best correction.",
    "collocation: ask which word naturally completes an academic/IELTS collocation, such as conduct research, significant impact, draw a conclusion, pose a threat.",
    "error_spotting: show one sentence with exactly one wrong word or phrase. The 4 choices must be words/phrases from that sentence, and the answer must be the wrong word/phrase the learner should identify.",
    "trap: test an IELTS trap such as wrong preposition, word family, confusing spelling, false friend, academic register mismatch, or unnatural collocation.",
    "reverse: show a Vietnamese meaning or academic context and ask the learner to choose the matching English word or phrase from targetVocabularyIndex.",
    "Do not use a plain dictionary-definition prompt.",
    "Return exactly 4 choices for all drills.",
    "One choice must be the answer. The other choices must be realistic traps based on spelling, sound, meaning, or academic/IELTS context.",
    "Randomize the answer position across A/B/C/D. Do not repeatedly put the correct answer first.",
    "The explanation must be detailed enough to teach the trap: 2-4 short sentences, English first then Vietnamese support.",
    "whyWrong must explain why each wrong choice is wrong in English + Vietnamese. Mention grammar, collocation, meaning, or register when relevant.",
    "Set targetWord to the exact tested answer when possible, testedSkill to a short skill label, and difficulty to easy, medium, or hard.",
    "Prefer the currently selected word as answer if it can make a good drill. Otherwise choose any good target from targetVocabularyIndex.",
    "Return NDJSON only: each line must be one compact JSON object for one drill.",
    "Each line shape: {\"kind\":\"scenario|rescue|collocation|error_spotting|trap|reverse\",\"trapType\":\"...\",\"targetWord\":\"...\",\"testedSkill\":\"...\",\"difficulty\":\"easy|medium|hard\",\"title\":\"...\",\"instruction\":\"...\",\"scenario\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\",\"whyWrong\":{\"choice\":\"reason\"}}.",
    "Do not wrap the lines in an array. Do not use markdown.",
    selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
    `Target vocabulary index JSON: ${JSON.stringify(targetVocabularyIndex)}`,
  ].join("\n");
}

export function readingPrompt(
  targetVocabularyIndex: string[],
  selectedWord?: string,
  format: ReadingFormat = "part6",
  contextDescription = "All words",
  weaknessContext = "No recorded practice mistakes yet.",
  language: CardLanguage = "en",
): string {
  const isGapFill = format === "part6";
  if (language === "zh-CN") {
    return [
      `You are creating one Chinese (Hán ngữ / HSK) reading ${isGapFill ? "gap-fill" : "full passage"} practice for a vocabulary learning app.`,
      "Use targetVocabularyIndex as the active learning context and target vocabulary source.",
      "For wrong choices and related vocabulary, create plausible Chinese distractors yourself when the target list is small.",
      `Active context: ${contextDescription}.`,
      "The targetVocabularyIndex is ordered by learning priority: new and learning words first, mastered words last. Prefer earlier unmastered words for target vocabulary.",
      weaknessContext,
      "Create a realistic and interesting Chinese reading passage in simplified Chinese characters (topics: daily life, culture, education, technology, work).",
      isGapFill
        ? "Gap-fill passage: create a 120-180 character Chinese passage with 3-6 numbered blanks formatted exactly as [1] _____, [2] _____, [3] _____, etc. Each blank tests vocabulary in context."
        : "Full passage: create a Chinese reading passage of 200-350 characters. Mix question types: True/False/Not Given, multiple choice (4 choices). Ask 3-6 questions in Vietnamese or Chinese.",
      isGapFill ? "Create 3-6 questions, one for each blank." : "Create 3-6 questions. Mix question types when possible.",
      "For multiple choice questions, use exactly 4 answer choices in Chinese and one correct answer.",
      "For True/False/Not Given questions, choices must be exactly [\"True\", \"False\", \"Not Given\"] or [\"Đúng\", \"Sai\", \"Không đề cập\"].",
      "Use exact words or phrases from targetVocabularyIndex for correct answers whenever possible.",
      "Questions, prompts, and explanations should be in Vietnamese with Chinese characters and Pinyin when useful.",
      isGapFill
        ? "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part6\",\"documentType\":\"chinese_passage\",\"title\":\"...\",\"passage\":[\"...\"],\"questions\":[{\"blank\":1,\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}."
        : "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part7\",\"documentType\":\"chinese_passage\",\"title\":\"...\",\"passage\":[\"paragraph lines...\"],\"questions\":[{\"questionType\":\"multiple_choice|true_false_not_given|summary_completion\",\"prompt\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}.",
      "Do not use markdown. Do not include extra text outside JSON.",
      selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
      `Target vocabulary index JSON: ${JSON.stringify(shuffleItems(targetVocabularyIndex))}`,
    ].join("\n");
  }

  return [
    `You are creating one IELTS Academic Reading ${isGapFill ? "gap-fill" : "full passage"} practice for a vocabulary learning app.`,
    "Use targetVocabularyIndex as the active learning context and target vocabulary source.",
    "For wrong choices and related vocabulary, create plausible academic/IELTS distractors yourself when the target list is small.",
    `Active context: ${contextDescription}.`,
    "The targetVocabularyIndex is ordered by learning priority: new and learning words first, mastered words last. Prefer earlier unmastered words for target vocabulary.",
    weaknessContext,
    "Use recent mistakes to bias target vocabulary and trap types, but keep the passage realistic and avoid repeating exact questions.",
    "Create a realistic IELTS Academic Reading passage. Use topics from science, education, environment, health, technology, history, or social issues. Write in a formal academic register with specific but clear details.",
    isGapFill
      ? "Gap-fill passage: create a 150-200 word academic passage with 3-6 numbered blanks formatted exactly as [1] _____, [2] _____, [3] _____, etc. Each blank tests vocabulary in context. The passage should read like an excerpt from a journal article, textbook, or research summary."
      : "Full passage: create an IELTS Academic Reading passage of 300-500 words on a single topic. The passage should feel like a real IELTS Reading section excerpt — formal, informative, and well-structured in 3-5 paragraphs. Mix question types: True/False/Not Given, multiple choice (4 choices), summary completion, or sentence completion. Ask 4-8 questions covering detail, inference, writer's purpose, vocabulary-in-context, and information matching.",
    isGapFill ? "Create 3-6 questions, one for each blank." : "Create 4-8 questions. Mix at least 2 different question types (e.g., True/False/Not Given + multiple choice, or summary completion + inference).",
    "For multiple choice questions, use exactly 4 answer choices and one correct answer.",
    "For True/False/Not Given questions, choices must be exactly [\"True\", \"False\", \"Not Given\"] and the prompt must be a statement about the passage.",
    "Use exact words or phrases from targetVocabularyIndex for correct answers whenever possible. For wrong choices, create plausible distractors when useful.",
    isGapFill
      ? "Gap-fill choices must be close academic traps: same word family, collocation traps, grammar fit, meaning fit, or register traps. The correct answer must fit grammar and meaning in the sentence."
      : "Choices must be plausible and tied to the passage. Avoid obvious wrong choices. Include detail, inference, and vocabulary-in-context style questions.",
    isGapFill ? "Avoid reusing the same target word, blank pattern, or passage topic repeatedly." : "Avoid reusing the same target word, question type, or passage topic repeatedly.",
    isGapFill
      ? "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part6\",\"documentType\":\"academic_passage\",\"title\":\"...\",\"passage\":[\"...\"],\"questions\":[{\"blank\":1,\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}."
      : "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part7\",\"documentType\":\"academic_passage\",\"title\":\"...\",\"passage\":[\"paragraph lines...\"],\"questions\":[{\"questionType\":\"multiple_choice|true_false_not_given|summary_completion\",\"prompt\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}.",
    "Do not use markdown. Do not include extra text outside JSON.",
    selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
    `Target vocabulary index JSON: ${JSON.stringify(shuffleItems(targetVocabularyIndex))}`,
  ].join("\n");
}

export function articlePracticePrompt(
  targetVocabularyIndex: string[],
  selectedWord?: string,
  contextDescription = "All words",
  weaknessContext = "No recorded practice mistakes yet.",
  language: CardLanguage = "en",
): string {
  if (language === "zh-CN") {
    return [
      "You are creating one short Chinese (Hán ngữ) article practice set for a vocabulary learning app.",
      "This is a focused reading article in simplified Chinese that teaches vocabulary in context.",
      `Active context: ${contextDescription}.`,
      "Use targetVocabularyIndex as the target vocabulary source.",
      weaknessContext,
      "Use 3-5 target Chinese words naturally in an interesting short article in simplified Chinese (150-250 characters).",
      "Create 3-5 questions across vocabulary-in-context, main purpose, and inference. Questions and options can be in Vietnamese or Chinese.",
      "Each question must have exactly 4 plausible choices and one correct answer.",
      "Add vocabularyNotes for the target words used in the passage with Vietnamese meaning and Pinyin.",
      "Do not use markdown. Do not include extra text outside JSON.",
      selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
      `Target vocabulary index JSON: ${JSON.stringify(shuffleItems(targetVocabularyIndex))}`,
    ].join("\n");
  }

  return [
    "You are creating one short IELTS-style article practice set for a vocabulary learning app.",
    "This is a focused academic or general training article/report/essay excerpt that teaches vocabulary in context.",
    `Active context: ${contextDescription}.`,
    "Use targetVocabularyIndex as the target vocabulary source. Prefer earlier unmastered words and recent mistake areas.",
    weaknessContext,
    "Use 3-5 target words naturally in a realistic academic or informational document.",
    "Passage should be 10-15 lines with clear academic or general training content.",
    "Create 3-5 questions across vocabulary-in-context, inference, paraphrase, phrase replacement, and main purpose.",
    "Each question must have exactly 4 plausible choices and one correct answer.",
    "Add vocabularyNotes for the target words used in the passage.",
    "Do not use markdown. Do not include extra text outside JSON.",
    selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
    `Target vocabulary index JSON: ${JSON.stringify(shuffleItems(targetVocabularyIndex))}`,
  ].join("\n");
}

export function speakingPrompt(
  targetVocabularyIndex: string[],
  selectedWord?: string,
  contextDescription = "All words",
  weaknessContext = "No recorded practice mistakes yet.",
): string {
  return [
    "You are creating one English speaking/shadowing practice set for a mobile vocabulary learning app.",
    "The goal is to help users practice speaking by reading an article/passage aloud with synchronized words (karaoke style).",
    `Active context: ${contextDescription}.`,
    "Use targetVocabularyIndex as the source for vocabulary. Try to incorporate 2-4 target words naturally into the passage.",
    weaknessContext,
    "The passage must be a longer, high-quality IELTS Academic or news-article-style reading passage (150-250 words in total, organized into 3-4 paragraphs) to help users practice reading a complete, professional article aloud.",
    "For each sentence, you must provide:",
    "1. The original sentence text.",
    "2. The overall IPA transcription of the sentence (do not wrap IPA in slashes).",
    "3. A list of all words in the sentence. For each word, provide: word text, its IPA (do not wrap the IPA in slashes `/`), and its estimated timing (startMs and endMs) relative to the start of the ENTIRE passage (0ms). Assume a natural, clear reading pace of approximately 100 words per minute (about 600ms per word + natural pauses between sentences of 700-1000ms). Ensure the startMs and endMs of words are continuous and increase chronologically throughout the entire passage.",
    "4. A list of connectedSpeech (linking/liaison) points between consecutive words in the sentence. For example:",
    "   - Consonant to Vowel linking (e.g. 'read up' -> from: 'read', to: 'up', type: 'linking', symbol: '‿')",
    "   - Vowel to Vowel linking (e.g. 'go on' -> from: 'go', to: 'on', type: 'linking', symbol: '‿')",
    "   - Consonant deletion/Elision (e.g. 'next door' -> from: 'next', to: 'door', type: 'elision')",
    "Return JSON only in this exact shape:",
    "{",
    "  \"type\": \"speaking_practice\",",
    "  \"title\": \"Title of the Reading\",",
    "  \"topic\": \"Topic name\",",
    "  \"passageText\": \"The entire concatenated text of the passage.\",",
    "  \"sentences\": [",
    "    {",
    "      \"text\": \"The first sentence text.\",",
    "      \"ipa\": \"The IPA of the first sentence.\",",
    "      \"words\": [",
    "        {\"word\": \"The\", \"ipa\": \"ðə\", \"startMs\": 0, \"endMs\": 300},",
    "        {\"word\": \"first\", \"ipa\": \"fɜːst\", \"startMs\": 300, \"endMs\": 800}",
    "      ],",
    "      \"connectedSpeech\": [",
    "        {\"from\": \"first\", \"to\": \"sentence\", \"type\": \"linking\", \"symbol\": \"‿\", \"explanation\": \"optional comment\"}",
    "      ]",
    "    }",
    "  ]",
    "}",
    "Do not use markdown. Do not include extra text outside JSON.",
    selectedWord ? `Currently selected word: ${selectedWord}` : "No selected word.",
    `Target vocabulary index JSON: ${JSON.stringify(shuffleItems(targetVocabularyIndex))}`,
  ].join("\n");
}
