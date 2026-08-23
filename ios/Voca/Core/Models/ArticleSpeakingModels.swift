import Foundation

// Schemas produced by server-side PracticePrompts for `/api/practice/article` and `/api/practice/speaking`.

/// `POST /api/practice/article` → one JSON object: a business article + questions + vocabulary notes.
struct ArticlePractice: Decodable {
    let type: String?
    let title: String?
    let documentType: String?
    let passage: [String]?
    let targetWords: [String]?
    let questions: [ReadingQuestion]      // reused: prompt/choices/answer/explanation (blank is nil here)
    let vocabularyNotes: [VocabularyNote]?
}

struct VocabularyNote: Decodable, Identifiable {
    let id = UUID()
    let word: String?
    let meaningVi: String?
    let contextMeaning: String?

    enum CodingKeys: String, CodingKey { case word, meaningVi, contextMeaning }
}

/// `POST /api/practice/speaking` → one JSON object: a shadowing passage with per-word IPA + timings.
struct SpeakingPractice: Decodable {
    let type: String?
    let title: String?
    let topic: String?
    let passageText: String?
    let sentences: [SpeakingSentence]
}

struct SpeakingSentence: Decodable, Identifiable {
    let id = UUID()
    let text: String?
    let ipa: String?
    let words: [SpeakingWord]?
    let connectedSpeech: [ConnectedSpeech]?

    enum CodingKeys: String, CodingKey { case text, ipa, words, connectedSpeech }
}

struct SpeakingWord: Decodable, Identifiable {
    let id = UUID()
    let word: String?
    let ipa: String?
    let startMs: Int?
    let endMs: Int?

    enum CodingKeys: String, CodingKey { case word, ipa, startMs, endMs }
}

struct ConnectedSpeech: Decodable, Identifiable {
    let id = UUID()
    let from: String?
    let to: String?
    let type: String?
    let symbol: String?

    enum CodingKeys: String, CodingKey { case from, to, type, symbol }
}

extension PracticeParsing {
    /// Article is one JSON object (fence/prose tolerant).
    static func article(from raw: String) -> ArticlePractice? {
        guard let json = extractJSONObject(from: raw), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ArticlePractice.self, from: data)
    }

    /// Speaking is one JSON object.
    static func speaking(from raw: String) -> SpeakingPractice? {
        guard let json = extractJSONObject(from: raw), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SpeakingPractice.self, from: data)
    }
}
