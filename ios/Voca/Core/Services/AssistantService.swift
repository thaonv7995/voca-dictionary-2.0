import Foundation

/// Streaming AI endpoints. English routes use server-side `/api/agent/chat` & `/api/practice/*`
/// (with `language`), while Chinese (`zh-CN`) and Conversation build localized prompts via
/// `/api/chat/completions` so language scoping & Pinyin formatting work reliably regardless of server version.
/// Shared between Voca iOS & VocaMac.
struct AssistantService {
    private let api = ApiClient.shared

    private struct ChatBody: Encodable { let message: String; let language: String }
    private struct DrillsBody: Encodable { let count: Int; let selectedWord: String?; let language: String }
    private struct ReadingBody: Encodable { let format: String; let selectedWord: String?; let language: String }
    private struct GenBody: Encodable { let selectedWord: String?; let language: String }
    private struct ChatCompletionsBody: Encodable { let messages: [[String: String]] }

    /// Free-form assistant chat. Yields incremental text fragments.
    func chat(message: String, language: CardLanguage = .english) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            return streamWithIndex(language: .chinese) { index in
                [
                    ["role": "system", "content": ClientPrompts.chatSystem(index: index, language: .chinese)],
                    ["role": "user", "content": message],
                ]
            }
        }
        return api.streamContent(path: "/api/agent/chat",
                                 body: ChatBody(message: message, language: language.rawValue))
    }

    /// Streams NDJSON drills; accumulate and parse with `PracticeParsing.drills`.
    func drills(count: Int = 5,
                selectedWord: String? = nil,
                language: CardLanguage = .english) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            return streamWithIndex(language: .chinese) { index in
                [["role": "system", "content": ClientPrompts.chineseDrills(index: index, count: count, selectedWord: selectedWord)]]
            }
        }
        return api.streamContent(path: "/api/practice/drills",
                                 body: DrillsBody(count: count, selectedWord: selectedWord, language: language.rawValue))
    }

    /// Streams a reading context (`part6`/`part7`); accumulate and parse with `PracticeParsing.reading`.
    func reading(format: String = "part6",
                 selectedWord: String? = nil,
                 language: CardLanguage = .english) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            return streamWithIndex(language: .chinese) { index in
                [["role": "system", "content": ClientPrompts.chineseReading(index: index, format: format, selectedWord: selectedWord)]]
            }
        }
        return api.streamContent(path: "/api/practice/reading",
                                 body: ReadingBody(format: format, selectedWord: selectedWord, language: language.rawValue))
    }

    /// Streams an article practice set; accumulate and parse with `PracticeParsing.article`.
    func article(selectedWord: String? = nil, language: CardLanguage = .english) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            return streamWithIndex(language: .chinese) { index in
                [["role": "system", "content": ClientPrompts.chineseArticle(index: index, selectedWord: selectedWord)]]
            }
        }
        return api.streamContent(path: "/api/practice/article",
                                 body: GenBody(selectedWord: selectedWord, language: language.rawValue))
    }

    /// Streams a speaking/shadowing passage; accumulate and parse with `PracticeParsing.speaking`.
    func speaking(selectedWord: String? = nil, language: CardLanguage = .english) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            return streamWithIndex(language: .chinese) { index in
                [["role": "system", "content": ClientPrompts.chineseSpeaking(index: index, selectedWord: selectedWord)]]
            }
        }
        return api.streamContent(path: "/api/practice/speaking",
                                 body: GenBody(selectedWord: selectedWord, language: language.rawValue))
    }

    /// Streams a daily listening passage, then parse with `PracticeParsing.conversation`.
    func conversation(format: String = "auto",
                      selectedWord: String? = nil,
                      language: CardLanguage = .english,
                      availableVoices: [(id: String, label: String)] = [],
                      autoSelectVoices: Bool = true) -> AsyncThrowingStream<String, Error> {
        streamWithIndex(language: language) { index in
            let prompt = ClientPrompts.conversation(
                index: index,
                selectedWord: selectedWord,
                format: format,
                language: language,
                availableVoices: availableVoices,
                autoSelectVoices: autoSelectVoices
            )
            return [["role": "system", "content": prompt]]
        }
    }

    /// Card-scoped assistant chat: seeds the prompt with the card's language, pinyin/IPA, and meaning.
    func cardChat(word: String,
                  message: String,
                  language: CardLanguage = .english,
                  pronunciation: String? = nil,
                  meaningVi: String? = nil) -> AsyncThrowingStream<String, Error> {
        if language == .chinese {
            let system = ClientPrompts.cardChatSystem(
                word: word,
                language: .chinese,
                pronunciation: pronunciation,
                meaningVi: meaningVi
            )
            return api.streamContent(
                path: "/api/chat/completions",
                body: ChatCompletionsBody(messages: [
                    ["role": "system", "content": system],
                    ["role": "user", "content": message],
                ]),
                rawChunks: true
            )
        }
        let seeded = "Về từ vựng \"\(word)\": \(message)"
        return chat(message: seeded, language: language)
    }

    private func streamWithIndex(
        language: CardLanguage,
        messagesBuilder: @Sendable @escaping ([String]) -> [[String: String]]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let cards = (try? await CardsService().list()) ?? CardsService().cachedList()
                    let index = Self.vocabularyIndex(from: cards, language: language)
                    let body = ChatCompletionsBody(messages: messagesBuilder(index))
                    for try await chunk in api.streamContent(path: "/api/chat/completions", body: body, rawChunks: true) {
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

    /// Words for a specific language ordered by learning priority (new/learning first), capped.
    static func vocabularyIndex(from cards: [Card], language: CardLanguage, limit: Int = 50) -> [String] {
        func rank(_ level: String?) -> Int {
            switch level?.lowercased() {
            case "learning": return 1
            case "known": return 2
            case "mastered": return 3
            default: return 0
            }
        }
        return cards
            .filter { $0.cardLanguage == language }
            .sorted { rank($0.level) < rank($1.level) }
            .map(\.word)
            .prefix(limit)
            .map { $0 }
    }
}
