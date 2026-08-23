import SwiftUI
import Observation

/// One message in the chat transcript.
struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
    var isError: Bool = false
}

/// Drives the streaming chat conversation.
@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var input: String = ""
    var isStreaming = false

    private let service = AssistantService()

    var canSend: Bool {
        !isStreaming && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        input = ""
        messages.append(ChatMessage(role: .user, text: text))
        let assistant = ChatMessage(role: .assistant, text: "")
        messages.append(assistant)
        let assistantId = assistant.id
        isStreaming = true

        Task { @MainActor in
            var acc = ""
            do {
                for try await chunk in service.chat(message: text) {
                    acc += chunk
                    update(assistantId, text: acc)
                }
                if acc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    update(assistantId, text: "Không tạo được nội dung, thử lại", isError: true)
                }
            } catch {
                let message = (error as? ApiError)?.message ?? error.localizedDescription
                update(assistantId, text: message, isError: true)
            }
            isStreaming = false
        }
    }

    private func update(_ id: UUID, text: String, isError: Bool = false) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
        messages[index].isError = isError
    }
}

/// Scrolling conversation with a bottom input bar; assistant replies stream in live.
struct ChatView: View {
    @Bindable var vm: ChatViewModel
    private let bottomAnchor = "chat-bottom"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.messages.isEmpty {
                            emptyState
                        }
                        ForEach(vm.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .padding()
                }
                .onChange(of: vm.messages.count) { scrollToBottom(proxy) }
                .onChange(of: vm.messages.last?.text) { scrollToBottom(proxy) }
            }
            inputBar
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Hãy đặt câu hỏi hoặc yêu cầu luyện tập.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Nhập tin nhắn…", text: $vm.input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(vm.isStreaming)
            Button {
                vm.send()
            } label: {
                if vm.isStreaming {
                    ProgressView().frame(width: 30, height: 30)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
            }
            .disabled(!vm.canSend)
        }
        .padding()
        .background(.bar)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
}

/// A single message bubble: user right-aligned, assistant left-aligned.
private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            content
            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder private var content: some View {
        if !isUser && message.text.isEmpty {
            // Waiting for the first streamed chunk.
            ProgressView()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Text(message.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var foreground: Color {
        if message.isError { return .red }
        return isUser ? .white : .primary
    }

    private var background: Color {
        if isUser { return .accentColor }
        return Color(.secondarySystemBackground)
    }
}
