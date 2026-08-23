import Foundation

/// Client-side prompt builders for features that use the generic `/api/chat/completions` proxy
/// (the same approach the web app takes with `@voca/core`). Used where there is no dedicated
/// server-side `/practice/*` endpoint — currently the daily conversation / listening passage.
enum ClientPrompts {
    static func conversation(index: [String], selectedWord: String?, format: String) -> String {
        let auto = format.isEmpty || format.lowercased() == "auto"
        var lines: [String] = []
        lines.append("Generate one practical everyday English listening passage for vocabulary learning and listening exposure.")
        lines.append("Use targetVocabularyIndex as the active learning context and target vocabulary source.")
        lines.append(auto
            ? "Format preference: Auto. Choose one suitable format at random from conversation, radio, announcement, or story based on the vocabulary context."
            : "Format preference: \(format). Use this exact format.")
        lines.append("Speaker selection is automatic. conversation should use 2, 3, or 4 speakers; announcement must use exactly 1 speaker named Announcer; story must use exactly 1 narrator named Narrator; radio can use 1 or 2 hosts.")
        lines.append("First infer a natural daily-life situation from targetVocabularyIndex; build the passage around it.")
        lines.append("targetVocabularyIndex is ordered by priority (new/learning first) — prefer words from the top. Pick 5-7 target items that fit one situation and use at least 4 naturally.")
        lines.append("Put the target words used in each line's vocabulary array, and map each highlighted item to the exact Vietnamese phrase in that line's translation via vocabularyMeanings.")
        lines.append("Format rules: conversation = back-and-forth spoken interaction (dialogue/interview/group chat). radio = a short radio segment. announcement = a public notice from one speaker. story = narrated prose from one narrator (no dialogue turns).")
        lines.append("For conversation use 8-10 short natural turns. For story/announcement return 1-3 paragraphs under one speaker (2-4 connected sentences each, not one sentence per line).")
        lines.append("Each line text must be natural spoken English; translation must be Vietnamese. Highlight 1-2 vocabulary items per line.")
        lines.append("voiceAssignments is optional (the app maps speakers to voices) — you may omit it or leave it empty.")
        lines.append("Return JSON only in this exact shape: {\"type\":\"daily_conversation\",\"format\":\"conversation|radio|announcement|story\",\"title\":\"...\",\"context\":\"...\",\"speakers\":[\"...\"],\"voiceAssignments\":{\"Speaker\":\"voice_id\"},\"lines\":[{\"speaker\":\"...\",\"text\":\"...\",\"translation\":\"...\",\"vocabulary\":[\"...\"],\"vocabularyMeanings\":{\"english term\":\"Vietnamese phrase\"}}]}.")
        lines.append("Do not use markdown. Do not include any extra text outside JSON.")
        lines.append(selectedWord != nil ? "Currently selected word: \(selectedWord!)" : "No selected word.")
        lines.append("Target vocabulary index JSON: \(jsonArray(index))")
        return lines.joined(separator: "\n")
    }

    private static func jsonArray(_ items: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: items),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }
}
