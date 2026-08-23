import SwiftUI

/// A lightweight, card-scoped tutor chat. Every question is grounded on `card.word`
/// via `AssistantService.cardChat`, streaming the reply live into the assistant bubble.
struct CardAgentView: View {
    @Environment(\.dismiss) private var dismiss

    let card: Card

    @State private var messages: [CardChatMessage] = []
    @State private var input = ""
    @State private var isStreaming = false
    @FocusState private var inputFocused: Bool

    private let assistant = AssistantService()

    private let starters = [
        "Cho ví dụ",
        "Phân biệt từ gần nghĩa",
        "Bẫy TOEIC của từ này",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesScroll
                Divider()
                inputBar
            }
            .navigationTitle("Hỏi AI: \(card.word)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { message in
                        CardChatBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: message.role == .user ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity))
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: messages.last?.text) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Brand.green)
                Text("Hỏi gia sư AI về “\(card.word)”")
                    .font(.headline)
            }
            Text("Chọn một gợi ý bên dưới hoặc nhập câu hỏi của bạn.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    // MARK: - Input

    private var inputBar: some View {
        VStack(spacing: 8) {
            starterChips
            HStack(alignment: .bottom, spacing: 6) {
                TextField("Nhập câu hỏi…", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.leading, 14)
                    .padding(.vertical, 8)
                    .focused($inputFocused)
                    .disabled(isStreaming)
                    .onSubmit { send(input) }

                ChatSendButton(isStreaming: isStreaming, canSend: canSend) {
                    send(input)
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
            .padding(.bottom, 10)
        }
        .background(.bar)
    }

    private var starterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(starters, id: \.self) { starter in
                    Button {
                        send(starter)
                    } label: {
                        Text(starter)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(Brand.green)
                            .background(Brand.greenSoft, in: Capsule())
                    }
                    .disabled(isStreaming)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var canSend: Bool {
        !isStreaming && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        input = ""
        inputFocused = false
        let replyId = UUID()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            messages.append(CardChatMessage(role: .user, text: text))
            messages.append(CardChatMessage(id: replyId, role: .assistant, text: ""))
        }
        isStreaming = true

        Task {
            var acc = ""
            do {
                for try await chunk in assistant.cardChat(word: card.word, message: text) {
                    acc += chunk
                    updateMessage(id: replyId, text: acc, isError: false)
                }
                if acc.isEmpty {
                    updateMessage(id: replyId, text: "Không có phản hồi.", isError: false)
                }
            } catch {
                let message = (error as? ApiError)?.message ?? error.localizedDescription
                updateMessage(id: replyId, text: message, isError: true)
            }
            isStreaming = false
        }
    }

    private func updateMessage(id: UUID, text: String, isError: Bool) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = text
        messages[idx].isError = isError
    }
}

// MARK: - Model

/// One line of the card chat.
private struct CardChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id: UUID
    let role: Role
    var text: String
    var isError: Bool

    init(id: UUID = UUID(), role: Role, text: String, isError: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isError = isError
    }
}

// MARK: - Bubble

/// A single chat bubble: user on the right, assistant on the left, errors in red.
private struct CardChatBubble: View {
    let message: CardChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            bubble
                .layoutPriority(1)   // beat the Spacer — otherwise the bubble collapses to one-word-per-line
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder private var bubble: some View {
        Group {
            if message.text.isEmpty {
                // Assistant is "thinking" before the first chunk arrives.
                TypingIndicator().padding(.vertical, 4)
            } else if isUser || message.isError {
                Text(message.text)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Assistant replies are Markdown — render headings/bold/lists/tables properly.
                MarkdownText(text: message.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.body)
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var foreground: Color {
        if message.isError { return .red }
        return isUser ? .white : .primary
    }

    private var background: Color {
        if message.isError { return Color.red.opacity(0.12) }
        return isUser ? Brand.green : Color(.secondarySystemBackground)
    }
}
