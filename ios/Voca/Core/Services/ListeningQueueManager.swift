import Foundation
import Combine

/// Manages a queue of conversations for non-stop listening.
@MainActor
final class ListeningQueueManager: ObservableObject {
    @Published var queue: [Conversation] = []
    @Published var isGenerating = false
    @Published var error: String?

    private let assistantService = AssistantService()
    private var cancellables = Set<AnyCancellable>()

    // Limits
    private let maxQueueSize = 3

    init() {}

    func startQueue(format: String = "auto") async {
        await fillQueue(format: format)
    }

    func fillQueue(format: String = "auto") async {
        guard !isGenerating && queue.count < maxQueueSize else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            let stream = assistantService.conversation(format: format)
            var rawData = ""
            for try await chunk in stream {
                rawData += chunk
            }

            if let conversation = PracticeParsing.conversation(from: rawData) {
                queue.append(conversation)
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    func popNext() -> Conversation? {
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }
}
