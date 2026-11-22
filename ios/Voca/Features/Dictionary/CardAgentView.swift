import SwiftUI
import UIKit

/// A lightweight, card-scoped tutor chat grounded on `card.word`.
struct CardAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let card: Card

    @State private var messages: [CardChatMessage] = []
    @State private var input = ""
    @State private var isStreaming = false
    @State private var copiedId: UUID?
    @State private var streamTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private let assistant = AssistantService()

    private var starters: [String] {
        card.isChinese
            ? [
                "Cho ví dụ có Pinyin",
                "Bộ thủ & Âm Hán Việt",
                "Phân biệt từ gần nghĩa",
            ]
            : [
                "Cho ví dụ",
                "Phân biệt từ gần nghĩa",
                "Bẫy IELTS của từ này",
            ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VocaThemeBackground()

                VStack(spacing: 0) {
                    messagesScroll
                    Divider().opacity(0.6)
                    inputBar
                }
            }
            .navigationTitle("Hỏi AI: \(card.word)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        stopStreaming()
                        dismiss()
                    }
                }
            }
            .onDisappear { stopStreaming() }
        }
    }

    // MARK: - Messages

    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { message in
                        CardChatBubble(
                            message: message,
                            language: card.cardLanguage,
                            isStreaming: isStreaming && message.id == messages.last?.id,
                            isCopied: copiedId == message.id,
                            onCopy: { copyMessage(message) }
                        )
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: message.role == .user ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .opacity))
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VocaIconBadge(systemImage: "sparkles", size: 36, iconSize: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hỏi gia sư AI về “\(card.word)”")
                        .font(.headline)
                    if let meaning = card.meaningVi, !meaning.isEmpty {
                        Text(meaning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Chọn một gợi ý bên dưới hoặc nhập câu hỏi của bạn.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandHeroCard(padding: 16, cornerRadius: 18)
        .padding(.vertical, 12)
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

                ChatSendButton(isStreaming: isStreaming, canSend: canSend, onStop: stopStreaming) {
                    send(input)
                }
                .padding(4)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Brand.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1)
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
                        Haptics.selection()
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
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

        streamTask?.cancel()
        streamTask = Task {
            var acc = ""
            var lastFlush = Date.distantPast
            do {
                for try await chunk in assistant.cardChat(
                    word: card.word,
                    message: text,
                    language: card.cardLanguage,
                    pronunciation: card.phonetic,
                    meaningVi: card.meaningVi
                ) {
                    if Task.isCancelled { break }
                    acc += chunk
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.06 {
                        lastFlush = now
                        updateMessage(id: replyId, text: acc, isError: false)
                    }
                }
                if Task.isCancelled {
                    if !acc.isEmpty {
                        updateMessage(id: replyId, text: acc, isError: false)
                    }
                } else if acc.isEmpty {
                    updateMessage(id: replyId, text: "Không có phản hồi.", isError: false)
                } else {
                    updateMessage(id: replyId, text: acc, isError: false)
                }
            } catch is CancellationError {
                if !acc.isEmpty {
                    updateMessage(id: replyId, text: acc, isError: false)
                }
            } catch {
                let message = (error as? ApiError)?.message ?? error.localizedDescription
                updateMessage(id: replyId, text: message, isError: true)
            }
            isStreaming = false
            streamTask = nil
        }
    }

    private func updateMessage(id: UUID, text: String, isError: Bool) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = text
        messages[idx].isError = isError
    }

    private func copyMessage(_ message: CardChatMessage) {
        UIPasteboard.general.string = message.text
        Haptics.impact(.light)
        copiedId = message.id
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if copiedId == message.id { copiedId = nil }
            }
        }
    }
}

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

private struct CardChatBubble: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: CardChatMessage
    let language: CardLanguage
    let isStreaming: Bool
    let isCopied: Bool
    let onCopy: () -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 40) }
            bubble
                .layoutPriority(1)
            if !isUser { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder private var bubble: some View {
        Group {
            if message.text.isEmpty {
                TypingIndicator().padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if isUser || message.isError || isStreaming {
                        Text(message.text)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        MarkdownText(text: message.text)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().opacity(0.45)
                        HStack(spacing: 12) {
                            Button(action: onCopy) {
                                Label(isCopied ? "Đã chép" : "Sao chép", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isCopied ? Brand.semanticSuccess : .secondary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            let spoken = MarkdownText.plainTextForSpeech(from: message.text)
                            if !spoken.isEmpty {
                                PronounceButton(
                                    text: spoken,
                                    language: spoken.hasChineseCharacters ? .chinese : language,
                                    size: 34,
                                    font: .subheadline
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(isError ? .red : (isUser ? .white : .primary))
        .background {
            if isError {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.12))
            } else if isUser {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Brand.gradient)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Brand.cardFill(for: colorScheme))
            }
        }
        .overlay {
            if !isUser {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isError ? Color.red.opacity(0.35) : Brand.hairlineBorder(for: colorScheme),
                        lineWidth: 1
                    )
            }
        }
    }

    private var isError: Bool { message.isError }
}
