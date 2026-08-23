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

    /// Drills usually stream as NDJSON, but models sometimes pretty-print objects across lines, wrap
    /// them in a JSON array, or add ```json fences / prose. Extract every top-level `{ … }` object by
    /// brace-matching (string-aware) and decode each — robust to all those shapes.
    static func drills(from raw: String) -> [Drill] {
        topLevelObjects(in: raw).compactMap { try? decoder.decode(Drill.self, from: Data($0.utf8)) }
    }

    /// Returns every top-level `{ … }` JSON object in `raw`, ignoring braces inside string literals.
    static func topLevelObjects(in raw: String) -> [String] {
        var objects: [String] = []
        var depth = 0
        var start: String.Index?
        var inString = false
        var escaped = false
        var i = raw.startIndex
        while i < raw.endIndex {
            let c = raw[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                switch c {
                case "\"": inString = true
                case "{":
                    if depth == 0 { start = i }
                    depth += 1
                case "}":
                    if depth > 0 {
                        depth -= 1
                        if depth == 0, let s = start {
                            objects.append(String(raw[s...i]))
                            start = nil
                        }
                    }
                default: break
                }
            }
            i = raw.index(after: i)
        }
        return objects
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
