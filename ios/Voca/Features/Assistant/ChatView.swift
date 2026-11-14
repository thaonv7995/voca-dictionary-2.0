import Observation
import SwiftUI
import UIKit

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
    var language: CardLanguage = .english
    var messages: [ChatMessage] = []
    var input: String = ""
    var isStreaming = false

    private let service = AssistantService()

    func setLanguage(_ newLanguage: CardLanguage) {
        guard language != newLanguage else { return }
        language = newLanguage
        if !isStreaming {
            messages = []
        }
    }

    var canSend: Bool {
        !isStreaming && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendPreset(_ prompt: String) {
        input = prompt
        send()
    }

    func clear() {
        guard !isStreaming else { return }
        messages = []
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        input = ""
        let lang = language
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
                for try await chunk in service.chat(message: text, language: lang) {
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

/// Scrolling conversation with language-aware starter prompts, markdown streaming, copy/TTS actions, and bottom composer.
struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var vm: ChatViewModel
    @State private var copiedId: UUID?
    private let bottomAnchor = "chat-bottom"

    private var starters: [String] {
        vm.language == .chinese
            ? [
                "Ôn 5 từ Hán ngữ trong kho từ",
                "Đặt hội thoại ngắn dùng từ tôi đang học",
                "Giải thích cách nhớ thanh điệu & Pinyin",
                "So sánh những chữ Hán dễ nhầm"
            ]
            : [
                "Ôn 5 từ vựng gần đây của tôi",
                "Đặt 5 câu ví dụ công sở với từ đang học",
                "Phân biệt các từ đồng nghĩa hay gặp",
                "Ra bài tập điền từ nhanh cho tôi"
            ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.messages.isEmpty {
                            emptyState
                        }
                        ForEach(vm.messages) { message in
                            ChatBubble(
                                message: message,
                                isStreaming: vm.isStreaming && message.id == vm.messages.last?.id,
                                language: vm.language,
                                isCopied: copiedId == message.id,
                                onCopy: { copyMessage(message) }
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: message.role == .user ? .trailing : .leading)
                                    .combined(with: .opacity),
                                removal: .opacity))
                        }
                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .padding()
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.count) { scrollToBottom(proxy) }
                .onChange(of: vm.messages.last?.text) { scrollToBottom(proxy) }
            }
            inputBar
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            VocaIconBadge(systemImage: "sparkles", size: 58, iconSize: 26)

            VStack(spacing: 6) {
                Text(vm.language == .chinese ? "Gia sư Hán ngữ AI" : "Gia sư tiếng Anh AI")
                    .font(.headline)
                Text(vm.language == .chinese
                     ? "Hỏi về Hán tự, Pinyin, bộ thủ, âm Hán Việt hoặc luyện đặt câu với kho từ của bạn."
                     : "Hỏi nghĩa từ, sắc thái, bẫy IELTS hoặc yêu cầu tạo bài luyện tập theo kho từ của bạn.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VocaFlowLayout(spacing: 8) {
                ForEach(starters, id: \.self) { prompt in
                    Button {
                        Haptics.selection()
                        vm.sendPreset(prompt)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkle")
                                .font(.caption2)
                            Text(prompt)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(Brand.green)
                        .background(Brand.greenSoft, in: Capsule())
                        .overlay(Capsule().strokeBorder(Brand.green.opacity(0.22), lineWidth: 0.8))
                    }
                    .buttonStyle(PressableScaleStyle(scale: 0.96))
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 8)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            HStack(alignment: .bottom, spacing: 8) {
                if !vm.messages.isEmpty && !vm.isStreaming {
                    Button {
                        Haptics.impact(.light)
                        withAnimation { vm.clear() }
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Brand.elevatedFill(for: colorScheme), in: Circle())
                    }
                    .accessibilityLabel("Cuộc trò chuyện mới")
                }

                HStack(alignment: .bottom, spacing: 6) {
                    TextField("Nhập tin nhắn…", text: $vm.input, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.leading, 14)
                        .padding(.vertical, 9)
                        .disabled(vm.isStreaming)

                    ChatSendButton(isStreaming: vm.isStreaming, canSend: vm.canSend) {
                        vm.send()
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(.bar)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    private func copyMessage(_ message: ChatMessage) {
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

private struct ChatBubble: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: ChatMessage
    let isStreaming: Bool
    let language: CardLanguage
    let isCopied: Bool
    let onCopy: () -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 44) }
            bubble
                .layoutPriority(1)
            if !isUser { Spacer(minLength: 32) }
        }
    }

    @ViewBuilder private var bubble: some View {
        if !isUser && message.text.isEmpty {
            TypingIndicator()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    Brand.cardFill(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1)
                )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if isUser || message.isError {
                        Text(message.text)
                            .multilineTextAlignment(.leading)
                    } else {
                        MarkdownText(text: message.text)
                    }
                }
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

                if !isUser && !message.isError && !isStreaming && !message.text.isEmpty {
                    Divider().opacity(0.45)
                    HStack(spacing: 12) {
                        Button(action: onCopy) {
                            Label(isCopied ? "Đã chép" : "Sao chép", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isCopied ? Brand.semanticSuccess : .secondary)
                        }
                        .buttonStyle(.plain)

                        PronounceButton(
                            text: message.text,
                            language: message.text.hasChineseCharacters ? .chinese : language,
                            size: 24,
                            font: .caption
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(foreground)
            .background {
                if isUser {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Brand.gradient)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.isError ? Color.red.opacity(0.12) : Brand.cardFill(for: colorScheme))
                }
            }
            .overlay {
                if !isUser {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            message.isError ? Color.red.opacity(0.35) : Brand.hairlineBorder(for: colorScheme),
                            lineWidth: 1
                        )
                }
            }
        }
    }

    private var foreground: Color {
        if message.isError { return .red }
        return isUser ? .white : .primary
    }
}
