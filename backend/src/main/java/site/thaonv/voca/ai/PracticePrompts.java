package site.thaonv.voca.ai;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/** TOEIC practice prompts, ported from packages/voca-core/src/practice/prompts.ts. */
@Component
public class PracticePrompts {

    private final ObjectMapper mapper;

    public PracticePrompts(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    public String assistantSystemPrompt() {
        return "You are Voca, a concise bilingual (English-Vietnamese) TOEIC vocabulary tutor. "
                + "Answer in clear Markdown, English first then a short Vietnamese support line when helpful. "
                + "Ground answers in the learner's vocabulary when relevant.";
    }

    public String drillPrompt(List<String> index, String selectedWord, int count, String context, String weakness) {
        List<String> lines = new ArrayList<>();
        lines.add("You are creating " + count + " TOEIC vocabulary drills.");
        lines.add("Use targetVocabularyIndex as the active learning context and the full list of allowed target answers.");
        lines.add("For wrong choices and supporting context, create plausible TOEIC/business distractors yourself when the target list is small.");
        lines.add("Active context: " + context + ".");
        lines.add("The targetVocabularyIndex is ordered by learning priority: new and learning words first, mastered words last. Prefer earlier unmastered words.");
        lines.add(weakness);
        lines.add("Use exact words or phrases from targetVocabularyIndex as correct answers whenever possible.");
        lines.add("Each drill must be unique and use a different target answer if possible.");
        lines.add("Mix these drill kinds across the batch: scenario, rescue, collocation, error_spotting, trap, reverse, part2_response.");
        lines.add("Use trapType from this taxonomy: same_word_family, wrong_preposition, near_synonym_wrong_context, similar_spelling, similar_sound, grammar_mismatch, collocation_mismatch, too_literal, wrong_question_type.");
        lines.add("Return exactly 4 choices for normal drills, but exactly 3 choices for part2_response.");
        lines.add("Randomize the answer position. The explanation must teach the trap: 2-4 short sentences, English first then Vietnamese support.");
        lines.add("whyWrong must explain why each wrong choice is wrong in English + Vietnamese.");
        lines.add("Set targetWord to the exact tested answer, testedSkill to a short skill label, and difficulty to easy, medium, or hard.");
        lines.add("Return NDJSON only: each line must be one compact JSON object for one drill.");
        lines.add("Each line shape: {\"kind\":\"scenario|rescue|collocation|error_spotting|trap|reverse|part2_response\",\"trapType\":\"...\",\"targetWord\":\"...\",\"testedSkill\":\"...\",\"difficulty\":\"easy|medium|hard\",\"title\":\"...\",\"instruction\":\"...\",\"scenario\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\",\"whyWrong\":{\"choice\":\"reason\"}}.");
        lines.add("Do not wrap the lines in an array. Do not use markdown.");
        lines.add(selectedWord != null ? "Currently selected word: " + selectedWord : "No selected word.");
        lines.add("Target vocabulary index JSON: " + toJson(index));
        return String.join("\n", lines);
    }

    public String readingPrompt(List<String> index, String selectedWord, String format, String context, String weakness) {
        boolean isPart6 = !"part7".equalsIgnoreCase(format);
        List<String> lines = new ArrayList<>();
        lines.add("You are creating one TOEIC " + (isPart6 ? "Part 6" : "Part 7") + " reading context for a vocabulary learning app.");
        lines.add("Use targetVocabularyIndex as the active learning context and target vocabulary source.");
        lines.add("Active context: " + context + ".");
        lines.add(weakness);
        lines.add("Create a realistic TOEIC-style business document. Use natural workplace context, specific but simple details.");
        lines.add(isPart6
                ? "Part 6 passage: 4-7 short lines, one coherent email/notice/memo/article/message, and 1-3 numbered blanks formatted exactly as [1] _____, [2] _____, [3] _____."
                : "Part 7 passage: create a TOEIC single, double, or triple passage set with 1-3 related documents, no blanks. Ask 1-5 TOEIC Part 7 style questions about detail, purpose, inference, intended audience, next action, cross-document connection, or vocabulary-in-context.");
        lines.add("Each question must have exactly 4 answer choices and one correct answer.");
        lines.add("Use exact words or phrases from targetVocabularyIndex for correct answers whenever possible.");
        lines.add(isPart6
                ? "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part6\",\"documentType\":\"email\",\"title\":\"...\",\"passage\":[\"...\"],\"questions\":[{\"blank\":1,\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}."
                : "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part7\",\"documentType\":\"email\",\"title\":\"...\",\"passage\":[\"...\"],\"documents\":[{\"title\":\"Email\",\"documentType\":\"email\",\"passage\":[\"...\"]}],\"questions\":[{\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}.");
        lines.add("Do not use markdown. Do not include extra text outside JSON.");
        lines.add(selectedWord != null ? "Currently selected word: " + selectedWord : "No selected word.");
        lines.add("Target vocabulary index JSON: " + toJson(index));
        return String.join("\n", lines);
    }

    public String articlePrompt(List<String> index, String selectedWord, String context, String weakness) {
        List<String> lines = new ArrayList<>();
        lines.add("You are creating one short TOEIC-style article practice set for a vocabulary learning app.");
        lines.add("This is a focused business article/email/notice/memo that teaches vocabulary in context.");
        lines.add("Active context: " + context + ".");
        lines.add(weakness);
        lines.add("Use 3-5 target words naturally in a realistic workplace document. Passage should be 8-12 short lines.");
        lines.add("Create 3-5 questions across vocabulary-in-context, inference, paraphrase, phrase replacement, and main purpose.");
        lines.add("Each question must have exactly 4 plausible choices and one correct answer. Add vocabularyNotes for the target words used.");
        lines.add("Return JSON only in this shape: {\"type\":\"article_practice\",\"title\":\"...\",\"documentType\":\"article\",\"passage\":[\"...\"],\"targetWords\":[\"...\"],\"questions\":[{\"prompt\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"vocabularyNotes\":[{\"word\":\"...\",\"meaningVi\":\"...\",\"contextMeaning\":\"...\"}]}.");
        lines.add("Do not use markdown. Do not include extra text outside JSON.");
        lines.add(selectedWord != null ? "Currently selected word: " + selectedWord : "No selected word.");
        lines.add("Target vocabulary index JSON: " + toJson(index));
        return String.join("\n", lines);
    }

    public String speakingPrompt(List<String> index, String selectedWord, String context, String weakness) {
        List<String> lines = new ArrayList<>();
        lines.add("You are creating one English speaking/shadowing practice set for a mobile vocabulary learning app.");
        lines.add("The goal is to help users practice speaking by reading a passage aloud with synchronized words (karaoke style).");
        lines.add("Active context: " + context + ".");
        lines.add(weakness);
        lines.add("Incorporate 2-4 target words naturally. The passage must be a 150-250 word TOEIC/IELTS/news-style reading in 3-4 paragraphs.");
        lines.add("For each sentence provide: the text, the sentence IPA (no slashes), a list of words each with word/ipa/startMs/endMs (~100 wpm, chronological across the whole passage), and connectedSpeech linking points.");
        lines.add("Return JSON only in this shape: {\"type\":\"speaking_practice\",\"title\":\"...\",\"topic\":\"...\",\"passageText\":\"...\",\"sentences\":[{\"text\":\"...\",\"ipa\":\"...\",\"words\":[{\"word\":\"...\",\"ipa\":\"...\",\"startMs\":0,\"endMs\":300}],\"connectedSpeech\":[{\"from\":\"...\",\"to\":\"...\",\"type\":\"linking\",\"symbol\":\"‿\"}]}]}.");
        lines.add("Do not use markdown. Do not include extra text outside JSON.");
        lines.add(selectedWord != null ? "Currently selected word: " + selectedWord : "No selected word.");
        lines.add("Target vocabulary index JSON: " + toJson(index));
        return String.join("\n", lines);
    }

    /** Card generation prompt (ported from skills/scripts/voca-create-card.mjs), no PNG/drawing field. */
    public String cardCreationPrompt(List<String> words, String language) {
        String joined = String.join(", ", words);
        if ("zh-CN".equals(language)) {
            return "Create compact Mandarin Chinese vocabulary card data for Vietnamese learners for: " + joined + ".\n\n"
                    + "Return only a JSON array. Each item must contain: word, pronunciation, partOfSpeech, topic, frequency, "
                    + "meaningEn, meaningVi, useCases, examples, memoryTip, toeicTrap, practicePrompt, answer.\n\n"
                    + "Rules:\n"
                    + "- Return exactly one item per requested word in order; word must use Simplified Chinese.\n"
                    + "- pronunciation must be standard Hanyu Pinyin with tone marks.\n"
                    + "- meaningVi must be one short, natural Vietnamese meaning; meaningEn must be compact.\n"
                    + "- Include exactly one short example formatted as: Chinese | Pinyin | Vietnamese.\n"
                    + "- Include at most two short use cases. Keep memoryTip and toeicTrap to one short sentence each.\n"
                    + "- Do not include explanations, markdown, images, or extra fields.";
        }
        return "Create compact TOEIC-focused bilingual vocabulary card data for these words/phrases: " + joined + ".\n\n"
                + "Return only a JSON array. Each item must contain: word, pronunciation, partOfSpeech, topic, frequency, "
                + "meaningEn, meaningVi, useCases, examples, memoryTip, toeicTrap, practicePrompt, answer.\n\n"
                + "Rules:\n"
                + "- You MUST return exactly " + words.size() + " entries in the array, one per requested word in order.\n"
                + "- Do not split a phrase into multiple separate word entries.\n"
                + "- Simple English first, Vietnamese second. Keep explanations compact and practical.\n"
                + "- Include 3-4 collocations/use cases and 2-3 natural examples.\n"
                + "- pronunciation is the IPA (may be wrapped in slashes).\n"
                + "- If a requested word appears misspelled, use the correct spelling as word and mention the spelling trap in toeicTrap.\n"
                + "- Do NOT include any image/drawing field. Do not use markdown. Return only the JSON array.";
    }

    private String toJson(List<String> index) {
        try {
            return mapper.writeValueAsString(index);
        } catch (JsonProcessingException e) {
            return "[]";
        }
    }
}
