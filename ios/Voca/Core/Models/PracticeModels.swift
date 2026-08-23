import Foundation

// Output schemas produced by the server-side PracticePrompts (LLM), consumed after SSE accumulation.

/// One TOEIC drill. `POST /api/practice/drills` streams NDJSON — one JSON object per line.
struct Drill: Decodable, Identifiable {
    let id = UUID()
    let kind: String?
    let trapType: String?
    let targetWord: String?
    let testedSkill: String?
    let difficulty: String?
    let title: String?
    let instruction: String?
    let scenario: String?
    let choices: [String]
    let answer: String
    let explanation: String?
    let whyWrong: [String: String]?

    enum CodingKeys: String, CodingKey {
        case kind, trapType, targetWord, testedSkill, difficulty, title
        case instruction, scenario, choices, answer, explanation, whyWrong
    }
}

/// `POST /api/practice/reading` returns a single reading-context JSON object (part6 or part7).
struct ReadingContext: Decodable {
    let type: String?
    let format: String?
    let documentType: String?
    let title: String?
    let passage: [String]?
    let documents: [ReadingDocument]?
    let questions: [ReadingQuestion]
    let targetWords: [String]?
}

struct ReadingDocument: Decodable, Identifiable {
    let id = UUID()
    let title: String?
    let documentType: String?
    let passage: [String]?

    enum CodingKeys: String, CodingKey { case title, documentType, passage }
}

struct ReadingQuestion: Decodable, Identifiable {
    let id = UUID()
    let blank: Int?
    let prompt: String?
    let choices: [String]
    let answer: String
    let explanation: String?

    enum CodingKeys: String, CodingKey { case blank, prompt, choices, answer, explanation }
}

/// Parses the accumulated SSE text into structured practice objects.
enum PracticeParsing {
    private static let decoder = JSONDecoder()

    /// Drills stream as NDJSON — decode each non-empty line independently, skipping malformed lines.
    static func drills(from raw: String) -> [Drill] {
        raw.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
            return try? decoder.decode(Drill.self, from: data)
        }
    }

    /// Reading is one JSON object, possibly wrapped in prose/code-fences — extract `{ … }` and decode.
    static func reading(from raw: String) -> ReadingContext? {
        guard let json = extractJSONObject(from: raw), let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(ReadingContext.self, from: data)
    }

    /// Returns the substring from the first `{` to the last matching `}` (best-effort, fence-tolerant).
    static func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else { return nil }
        return String(raw[start...end])
    }
}
