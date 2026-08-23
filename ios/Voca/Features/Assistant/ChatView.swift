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
        let assistant = ChatMessage(role: .assistant, text: "")
        let assistantId = assistant.id
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            messages.append(ChatMessage(role: .user, text: text))
            messages.append(assistant)
        }
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
                                .transition(.asymmetric(
                                    insertion: .move(edge: message.role == .user ? .trailing : .leading)
                                        .combined(with: .opacity),
                                    removal: .opacity))
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
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 6) {
                TextField("Nhập tin nhắn…", text: $vm.input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.leading, 14)
                    .padding(.vertical, 8)
                    .disabled(vm.isStreaming)

                ChatSendButton(isStreaming: vm.isStreaming, canSend: vm.canSend) {
                    vm.send()
                }
                .padding(4)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
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
            TypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Text(message.text)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)   // wrap long AI replies; grow vertically
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
        if message.isError { return Color.red.opacity(0.12) }
        if isUser { return Brand.green }
        return Color(.secondarySystemBackground)
    }
}
