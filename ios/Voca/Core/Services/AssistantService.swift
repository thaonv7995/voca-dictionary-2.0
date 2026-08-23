import Foundation

/// Streaming AI endpoints. Prompts are built server-side (`/api/agent/chat`, `/api/practice/*`),
/// so the client only streams and (for practice) parses the accumulated output.
struct AssistantService {
    private let api = ApiClient.shared

    private struct ChatBody: Encodable { let message: String }
    private struct DrillsBody: Encodable { let count: Int; let selectedWord: String? }
    private struct ReadingBody: Encodable { let format: String; let selectedWord: String? }
    private struct GenBody: Encodable { let selectedWord: String? }

    /// Free-form assistant chat. Yields incremental text fragments.
    func chat(message: String) -> AsyncThrowingStream<String, Error> {
        api.streamContent(path: "/api/agent/chat", body: ChatBody(message: message))
    }

    /// Streams NDJSON drills; accumulate and parse with `PracticeParsing.drills`.
    func drills(count: Int = 5, selectedWord: String? = nil) -> AsyncThrowingStream<String, Error> {
        api.streamContent(path: "/api/practice/drills", body: DrillsBody(count: count, selectedWord: selectedWord))
    }

    /// Streams a reading context (`part6`/`part7`); accumulate and parse with `PracticeParsing.reading`.
    func reading(format: String = "part6", selectedWord: String? = nil) -> AsyncThrowingStream<String, Error> {
        api.streamContent(path: "/api/practice/reading", body: ReadingBody(format: format, selectedWord: selectedWord))
    }

    /// Streams an article practice set; accumulate and parse with `PracticeParsing.article`.
    func article(selectedWord: String? = nil) -> AsyncThrowingStream<String, Error> {
        api.streamContent(path: "/api/practice/article", body: GenBody(selectedWord: selectedWord))
    }

    /// Streams a speaking/shadowing passage; accumulate and parse with `PracticeParsing.speaking`.
    func speaking(selectedWord: String? = nil) -> AsyncThrowingStream<String, Error> {
        api.streamContent(path: "/api/practice/speaking", body: GenBody(selectedWord: selectedWord))
    }

    /// Card-scoped assistant chat: seeds the message with the word so the tutor grounds its answer.
    func cardChat(word: String, message: String) -> AsyncThrowingStream<String, Error> {
        let seeded = "Về từ vựng \"\(word)\": \(message)"
        return chat(message: seeded)
    }
}
