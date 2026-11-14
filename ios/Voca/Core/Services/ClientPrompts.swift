import Foundation

/// Client-side prompt builders for features that use the generic `/api/chat/completions` proxy
/// (the same approach the web app takes with `@voca/core`). Shared between Voca iOS & VocaMac.
enum ClientPrompts {
    static func conversation(
        index: [String],
        selectedWord: String?,
        format: String,
        language: CardLanguage = .english,
        availableVoices: [(id: String, label: String)] = [],
        autoSelectVoices: Bool = true
    ) -> String {
        let auto = format.isEmpty || format.lowercased() == "auto"
        let formatLine = auto
            ? "Format preference: Auto. Choose one suitable format at random from conversation, radio, announcement, or story based on the vocabulary context."
            : "Format preference: \(format). Use this exact format."
        let speakerRule = "Speaker selection is automatic. conversation should use 2, 3, or 4 speakers; announcement must use exactly 1 speaker; story must use exactly 1 narrator; radio can use 1 or 2 hosts."
        let voiceRule: String
        if availableVoices.isEmpty || !autoSelectVoices {
            voiceRule = "voiceAssignments is optional (the app maps speakers to voices) — you may omit it or leave it empty."
        } else {
            voiceRule = "Choose suitable voiceAssignments from Available voices JSON. Use only voice ids from that list."
        }

        var lines: [String] = []
        if language == .chinese {
            lines.append("Generate one practical everyday Chinese (Hán ngữ giao tiếp) listening passage for vocabulary learning.")
            lines.append("Return only JSON in this exact shape: {\"type\":\"daily_conversation\",\"format\":\"conversation|radio|announcement|story\",\"title\":\"...\",\"context\":\"...\",\"speakers\":[\"...\"],\"voiceAssignments\":{\"Speaker\":\"voice_id\"},\"lines\":[{\"speaker\":\"...\",\"text\":\"...\",\"pinyin\":\"...\",\"translation\":\"...\",\"vocabulary\":[\"...\"],\"vocabularyMeanings\":{\"chinese term\":\"Vietnamese phrase in translation\"}}]}.")
            lines.append(formatLine)
            lines.append(speakerRule)
            lines.append("First infer a natural daily-life situation from targetVocabularyIndex; build the entire passage in Simplified Chinese around it.")
            lines.append(index.isEmpty
                ? "targetVocabularyIndex is empty, so choose 5-7 practical everyday HSK 1-3 Mandarin words/phrases suited to one situation."
                : "targetVocabularyIndex is ordered by priority (new/learning first) — pick 5-7 Chinese target items from the top that fit one situation and use at least 4 naturally.")
            lines.append("CRITICAL 3-PART FORMAT RULE PER LINE:")
            lines.append("1. 'text': MUST contain ONLY natural spoken Simplified Chinese characters and Chinese punctuation. NEVER put Pinyin, Latin letters, English translations, or parentheses inside 'text'.")
            lines.append("2. 'pinyin': Complete, accurate Pinyin with tone marks for the ENTIRE sentence in 'text'.")
            lines.append("3. 'translation': Natural Vietnamese translation for the line.")
            lines.append("Format rules: conversation = 8-10 short natural spoken turns. radio = short Chinese radio segment. announcement = public notice from one speaker. story = 1-3 short paragraphs from one narrator.")
            lines.append("Put target Chinese words used in each line's vocabulary array and map each to its exact Vietnamese phrase in translation via vocabularyMeanings. Highlight 1-2 items per line.")
            lines.append(voiceRule)
            lines.append("Do not use markdown. Do not include any extra text outside JSON.")
            lines.append(selectedWord != nil ? "Currently selected Chinese word: \(selectedWord!)" : "No selected word.")
            lines.append("Target vocabulary index JSON: \(jsonArray(index))")
            if !availableVoices.isEmpty {
                lines.append("Available voices JSON: \(voicesJson(availableVoices))")
            }
            return lines.joined(separator: "\n")
        }

        lines.append("Generate one practical everyday English listening passage for vocabulary learning and listening exposure.")
        lines.append("Use targetVocabularyIndex as the active learning context and target vocabulary source.")
        lines.append(formatLine)
        lines.append(speakerRule)
        lines.append("First infer a natural daily-life situation from targetVocabularyIndex; build the passage around it.")
        lines.append(index.isEmpty
            ? "targetVocabularyIndex is empty, so choose 5-7 useful everyday English words/phrases suited to one situation."
            : "targetVocabularyIndex is ordered by priority (new/learning first) — prefer words from the top. Pick 5-7 target items that fit one situation and use at least 4 naturally.")
        lines.append("Put the target words used in each line's vocabulary array, and map each highlighted item to the exact Vietnamese phrase in that line's translation via vocabularyMeanings.")
        lines.append("Format rules: conversation = back-and-forth spoken interaction (dialogue/interview/group chat). radio = a short radio segment. announcement = a public notice from one speaker. story = narrated prose from one narrator (no dialogue turns).")
        lines.append("For conversation use 8-10 short natural turns. For story/announcement return 1-3 paragraphs under one speaker (2-4 connected sentences each, not one sentence per line).")
        lines.append("Each line text must be natural spoken English; translation must be Vietnamese. Highlight 1-2 vocabulary items per line.")
        lines.append(voiceRule)
        lines.append("Return JSON only in this exact shape: {\"type\":\"daily_conversation\",\"format\":\"conversation|radio|announcement|story\",\"title\":\"...\",\"context\":\"...\",\"speakers\":[\"...\"],\"voiceAssignments\":{\"Speaker\":\"voice_id\"},\"lines\":[{\"speaker\":\"...\",\"text\":\"...\",\"translation\":\"...\",\"vocabulary\":[\"...\"],\"vocabularyMeanings\":{\"english term\":\"Vietnamese phrase\"}}]}.")
        lines.append("Do not use markdown. Do not include any extra text outside JSON.")
        lines.append(selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.")
        lines.append("Target vocabulary index JSON: \(jsonArray(index))")
        if !availableVoices.isEmpty {
            lines.append("Available voices JSON: \(voicesJson(availableVoices))")
        }
        return lines.joined(separator: "\n")
    }

    static func chatSystem(index: [String], language: CardLanguage) -> String {
        if language == .chinese {
            return [
                "You are Voca Chinese Agent (Gia sư Hán ngữ AI) for a Vietnamese learner studying Mandarin Chinese.",
                "Always communicate in clear Vietnamese with Simplified Chinese characters (Hán tự) and Pinyin with tone marks.",
                "When providing example sentences, ALWAYS include 3 parts: Simplified Chinese characters, Pinyin with tone marks, and Vietnamese translation.",
                "Highlight Sino-Vietnamese (âm Hán Việt) and radicals (bộ thủ) when explaining Chinese characters to aid retention.",
                "Keep normal answers concise and scan-friendly unless detailed explanation is requested.",
                "Use targetChineseVocabularyIndex as context when relevant; prioritize new/learning words first.",
                "Target Chinese vocabulary index JSON: \(jsonArray(index))",
            ].joined(separator: "\n")
        }
        return [
            "You are Voca, a concise bilingual (English-Vietnamese) IELTS vocabulary tutor.",
            "Answer in clear Markdown, English first then a short Vietnamese support line when helpful.",
            "Ground answers in the learner's vocabulary when relevant.",
            "Target vocabulary index JSON: \(jsonArray(index))",
        ].joined(separator: "\n")
    }

    static func cardChatSystem(
        word: String,
        language: CardLanguage,
        pronunciation: String? = nil,
        meaningVi: String? = nil
    ) -> String {
        if language == .chinese {
            var lines = [
                "You are an expert AI Chinese (Hán ngữ) tutor for a Vietnamese learner.",
                "Help the learner master Simplified Chinese characters (Hán tự), Pinyin with tone marks, Sino-Vietnamese (âm Hán Việt), radicals (bộ thủ), and natural sentences.",
                "Keep answers concise (4-8 lines unless asked for detail), clear Markdown, ALWAYS in Vietnamese with Simplified Chinese + Pinyin + Vietnamese translation for any example.",
                "Current Chinese word: \(word)",
            ]
            if let pronunciation, !pronunciation.isEmpty { lines.append("Pinyin: \(pronunciation)") }
            if let meaningVi, !meaningVi.isEmpty { lines.append("Meaning (Nghĩa tiếng Việt): \(meaningVi)") }
            return lines.joined(separator: "\n")
        }
        var lines = [
            "You are a concise bilingual (English-Vietnamese) IELTS vocabulary tutor.",
            "Answer clearly in English with helpful Vietnamese support, focusing on usage, collocations, and common mistakes.",
            "Current word: \(word)",
        ]
        if let pronunciation, !pronunciation.isEmpty { lines.append("IPA: \(pronunciation)") }
        if let meaningVi, !meaningVi.isEmpty { lines.append("Meaning: \(meaningVi)") }
        return lines.joined(separator: "\n")
    }

    static func chineseDrills(index: [String], count: Int, selectedWord: String?) -> String {
        [
            "You are creating \(count) friendly everyday Chinese (Hán ngữ giao tiếp đời sống) vocabulary practice questions for a Vietnamese hobbyist learner.",
            "Use targetVocabularyIndex as the active learning context and allowed target answers (or common HSK 1-3 words if the index is small).",
            "For wrong choices, create plausible Chinese distractors (similar Hanzi, homophones, near-synonyms, measure-word/tone mix-ups).",
            "Each drill must be unique and mix kinds: scenario, rescue, collocation, error_spotting, trap, reverse.",
            "scenario/rescue/collocation/error_spotting prompts should contain Simplified Chinese with Pinyin when helpful.",
            "Return exactly 4 choices in Simplified Chinese for every drill, randomized answer position.",
            "explanation and whyWrong must be written in warm, clear Vietnamese mentioning Hanzi, Pinyin with tone marks, and âm Hán Việt when useful.",
            "Return NDJSON only: each line must be one compact JSON object for one drill.",
            "Each line shape: {\"kind\":\"scenario|rescue|collocation|error_spotting|trap|reverse\",\"trapType\":\"...\",\"targetWord\":\"...\",\"testedSkill\":\"...\",\"difficulty\":\"easy|medium|hard\",\"title\":\"...\",\"instruction\":\"...\",\"scenario\":\"...\",\"choices\":[\"...\"],\"answer\":\"...\",\"explanation\":\"...\",\"whyWrong\":{\"choice\":\"reason\"}}.",
            "Do not wrap the lines in an array. Do not use markdown.",
            selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.",
            "Target vocabulary index JSON: \(jsonArray(index))",
        ].joined(separator: "\n")
    }

    static func chineseReading(index: [String], format: String, selectedWord: String?) -> String {
        let isPart6 = format.lowercased() != "part7"
        return [
            "You are creating one Chinese (Hán ngữ / HSK) reading \(isPart6 ? "gap-fill" : "full passage") practice for a Vietnamese learner.",
            "Use targetVocabularyIndex as target vocabulary source (supplement with HSK 1-3 daily vocabulary if small).",
            "Write the reading passage strictly in Simplified Chinese characters (no inline English).",
            isPart6
                ? "Gap-fill passage: create a 120-180 character Simplified Chinese passage with 3-6 numbered blanks like [1] _____, [2] _____."
                : "Full passage: create a 200-350 character Simplified Chinese passage across 2-4 short paragraphs, plus 3-6 comprehension/vocabulary questions.",
            "Each multiple choice question has 4 choices in Simplified Chinese. Prompts and explanations should be clear Vietnamese (with Hanzi + Pinyin).",
            isPart6
                ? "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part6\",\"documentType\":\"chinese_passage\",\"title\":\"...\",\"passage\":[\"...\"],\"questions\":[{\"blank\":1,\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}."
                : "Return JSON only in this exact shape: {\"type\":\"reading_context\",\"format\":\"part7\",\"documentType\":\"chinese_passage\",\"title\":\"...\",\"passage\":[\"...\"],\"documents\":[{\"title\":\"Bài đọc\",\"documentType\":\"chinese_passage\",\"passage\":[\"...\"]}],\"questions\":[{\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"targetWords\":[\"...\"]}.",
            "Do not use markdown. Do not include extra text outside JSON.",
            selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.",
            "Target vocabulary index JSON: \(jsonArray(index))",
        ].joined(separator: "\n")
    }

    static func chineseArticle(index: [String], selectedWord: String?) -> String {
        [
            "You are creating one short Chinese (Hán ngữ) article practice set for a Vietnamese learner.",
            "Write an engaging 150-250 character Simplified Chinese passage (6-10 short lines) using 3-5 target Chinese words naturally.",
            "Create 3-5 questions across vocabulary-in-context, main idea, and inference. Write questions, choices, and explanations clearly (Vietnamese + Hanzi/Pinyin).",
            "Add vocabularyNotes for the target Chinese words used, putting Vietnamese meaning in meaningVi and Pinyin + usage in contextMeaning.",
            "Return JSON only in this exact shape: {\"type\":\"article_practice\",\"title\":\"...\",\"documentType\":\"chinese_article\",\"passage\":[\"...\"],\"targetWords\":[\"...\"],\"questions\":[{\"prompt\":\"...\",\"choices\":[\"...\",\"...\",\"...\",\"...\"],\"answer\":\"...\",\"explanation\":\"...\"}],\"vocabularyNotes\":[{\"word\":\"...\",\"meaningVi\":\"...\",\"contextMeaning\":\"Pinyin + cách dùng trong bài\"}]}.",
            "Do not use markdown. Do not include extra text outside JSON.",
            selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.",
            "Target vocabulary index JSON: \(jsonArray(index))",
        ].joined(separator: "\n")
    }

    static func chineseSpeaking(index: [String], selectedWord: String?) -> String {
        [
            "You are creating one Chinese (Hán ngữ) speaking/shadowing practice set for a mobile vocabulary learning app.",
            "Incorporate 2-4 target Chinese words naturally into a 120-200 character everyday Simplified Chinese passage in 2-3 paragraphs.",
            "For each sentence provide: Simplified Chinese text (NO inline pinyin in text), sentence Pinyin with tone marks in ipa, and segmented Chinese words each with word, ipa (Pinyin), startMs, endMs chronological across the passage. Leave connectedSpeech [].",
            "Return JSON only in this exact shape: {\"type\":\"speaking_practice\",\"title\":\"...\",\"topic\":\"...\",\"passageText\":\"...\",\"sentences\":[{\"text\":\"...\",\"ipa\":\"pinyin\",\"words\":[{\"word\":\"...\",\"ipa\":\"pinyin\",\"startMs\":0,\"endMs\":450}],\"connectedSpeech\":[]}]}.",
            "Do not use markdown. Do not include extra text outside JSON.",
            selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.",
            "Target vocabulary index JSON: \(jsonArray(index))",
        ].joined(separator: "\n")
    }

    private static func jsonArray(_ items: [String]) -> String {
        jsonString(items, fallback: "[]")
    }

    private static func voicesJson(_ voices: [(id: String, label: String)]) -> String {
        jsonString(voices.map { ["id": $0.id, "label": $0.label] }, fallback: "[]")
    }

    private static func jsonString(_ object: Any, fallback: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]),
              let string = String(data: data, encoding: .utf8) else { return fallback }
        return string
    }
}
