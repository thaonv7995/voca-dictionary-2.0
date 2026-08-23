import Foundation

/// Streaming AI endpoints. Prompts are built server-side (`/api/agent/chat`, `/api/practice/*`),
/// so the client only streams and (for practice) parses the accumulated output.
struct AssistantService {
    private let api = ApiClient.shared

    private struct ChatBody: Encodable { let message: String }
    private struct DrillsBody: Encodable { let count: Int; let selectedWord: String? }
    private struct ReadingBody: Encodable { let format: String; let selectedWord: String? }
    private struct GenBody: Encodable { let selectedWord: String? }
    private struct ChatCompletionsBody: Encodable { let messages: [[String: String]] }

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

    /// Streams a daily listening passage, then parse with `PracticeParsing.conversation`.
    ///
    /// There is no server-side `/practice/conversation` endpoint (the web builds this prompt in the
    /// browser too); we build the prompt client-side and stream via the generic `/api/chat/completions`
    /// proxy — which already exists on the server, so no backend redeploy is needed.
    func conversation(format: String = "auto", selectedWord: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let cards = (try? await CardsService().list()) ?? []
                    let index = Self.vocabularyIndex(from: cards)
                    let prompt = ClientPrompts.conversation(index: index, selectedWord: selectedWord, format: format)
                    let body = ChatCompletionsBody(messages: [["role": "system", "content": prompt]])
                    for try await chunk in api.streamContent(path: "/api/chat/completions", body: body) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Words ordered by learning priority (new/learning first), capped — the conversation target index.
    private static func vocabularyIndex(from cards: [Card], limit: Int = 50) -> [String] {
        func rank(_ level: String?) -> Int {
            switch level?.lowercased() {
            case "learning": return 1
            case "known": return 2
            case "mastered": return 3
            default: return 0
            }
        }
        return cards.sorted { rank($0.level) < rank($1.level) }.map(\.word).prefix(limit).map { $0 }
    }

    /// Card-scoped assistant chat: seeds the message with the word so the tutor grounds its answer.
    func cardChat(word: String, message: String) -> AsyncThrowingStream<String, Error> {
        let seeded = "Về từ vựng \"\(word)\": \(message)"
        return chat(message: seeded)
    }
}
