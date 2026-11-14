import SwiftUI
import WebKit

private actor HanziStrokeRepository {
    static let shared = HanziStrokeRepository()

    func data(for character: String) async throws -> Data {
        let cache = try cacheURL(for: character)
        if let data = try? Data(contentsOf: cache), !data.isEmpty { return data }

        guard let escaped = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/\(escaped).json")
        else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else { throw URLError(.cannotParseResponse) }
        try data.write(to: cache, options: .atomic)
        return data
    }

    private func cacheURL(for character: String) throws -> URL {
        let root = (FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedStore.appGroup)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0])
            .appendingPathComponent("HanziWriterData", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = character.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
        return root.appendingPathComponent(name).appendingPathExtension("json")
    }
}

struct HanziWritingView: View {
    let word: String
    var compact = false
    var displayOnly = false
    var onCharacterFocus: ((String) -> Void)?

    private var characters: [String] {
        word.map(String.init).filter { value in
            value.unicodeScalars.contains { scalar in
                (0x3400...0x4DBF).contains(scalar.value)
                    || (0x4E00...0x9FFF).contains(scalar.value)
                    || (0xF900...0xFAFF).contains(scalar.value)
                    || (0x20000...0x323AF).contains(scalar.value)
            }
        }
    }

    var body: some View {
        if displayOnly, let character = characters.first {
            HanziCharacterPractice(character: character, compact: false, displayOnly: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if !characters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if !compact && !displayOnly {
                    HStack(spacing: 8) {
                        Label("Tập viết Hán tự", systemImage: "pencil.and.outline")
                            .font(.headline)
                        Spacer()
                        Text("\(characters.count) chữ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: compact ? 6 : 14) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                            if compact, let onCharacterFocus {
                                HanziCharacterPractice(character: character, compact: true,
                                                       displayOnly: displayOnly)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    TapGesture().onEnded { onCharacterFocus(character) })
                                .accessibilityLabel("Phóng lớn chữ \(character)")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction { onCharacterFocus(character) }
                            } else {
                                HanziCharacterPractice(character: character, compact: compact,
                                                       displayOnly: displayOnly)
                            }
                        }
                    }
                    .frame(minWidth: compact ? 114 : 0, alignment: .trailing)
                    .padding(.horizontal, 1)
                }
                .frame(width: compact ? 114 : nil, alignment: .trailing)
            }
        }
    }
}

private struct HanziCharacterPractice: View {
    @Environment(\.colorScheme) private var colorScheme
    let character: String
    let compact: Bool
    let displayOnly: Bool
    @State private var strokeJSON: String?
    @State private var errorMessage: String?
    @State private var command: HanziCommand?
    @State private var status = ""

    private var canvasSize: CGFloat { compact ? 48 : displayOnly ? 240 : 176 }

    private var canvasSurfaceColor: Color {
        colorScheme == .dark ? Color(red: 0.086, green: 0.114, blue: 0.184) : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let strokeJSON {
                    HanziWriterWebView(
                        character: character,
                        strokeJSON: strokeJSON,
                        size: Int(canvasSize),
                        isDark: colorScheme == .dark,
                        command: command,
                        onStatus: { status = $0 }
                    )
                } else if errorMessage != nil {
                    VStack(spacing: 8) {
                        Text(character)
                            .font(VocaTypography.hanziFont(size: compact ? 28 : 84, weight: .semibold))
                        if !compact {
                            Button("Tải lại") { load() }.font(.caption)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(width: canvasSize, height: canvasSize)
            .background(canvasSurfaceColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !compact && !displayOnly {
                HStack(spacing: 10) {
                    iconButton("play.fill", title: "Xem nét", label: "Xem thứ tự nét") {
                        Haptics.selection()
                        command = HanziCommand(kind: .animate)
                    }
                    iconButton("pencil.and.scribble", title: "Tự viết", label: "Luyện viết") {
                        Haptics.selection()
                        command = HanziCommand(kind: .quiz)
                    }
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.green)
                }
            }
        }
        .padding(compact ? 4 : 12)
        .background(
            Brand.cardFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: compact ? 10 : 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 18, style: .continuous)
                .strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1)
        )
        .task(id: character) { await loadData() }
    }

    private func iconButton(_ icon: String, title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
        .tint(Brand.green)
        .accessibilityLabel(label)
    }

    private func load() {
        errorMessage = nil
        strokeJSON = nil
        Task { await loadData() }
    }

    @MainActor private func loadData() async {
        do {
            let data = try await HanziStrokeRepository.shared.data(for: character)
            guard let json = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            strokeJSON = json
        } catch {
            errorMessage = "Không tải được dữ liệu nét"
        }
    }
}

private struct HanziCommand: Equatable {
    enum Kind { case animate, quiz }
    let id = UUID()
    let kind: Kind
}

private struct HanziWriterWebView: UIViewRepresentable {
    let character: String
    let strokeJSON: String
    let size: Int
    let isDark: Bool
    let command: HanziCommand?
    let onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "hanzi")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        context.coordinator.lastIsDark = isDark
        view.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onStatus = onStatus
        if context.coordinator.lastIsDark != isDark {
            context.coordinator.lastIsDark = isDark
            context.coordinator.resetReady()
            view.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
            return
        }
        guard let command, command.id != context.coordinator.lastCommandID else { return }
        context.coordinator.lastCommandID = command.id
        context.coordinator.run(command, in: view)
    }

    private var scriptURL: URL? {
        Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js", subdirectory: "HanziWriter")
            ?? Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js")
    }

    private var html: String {
        let encodedCharacter = (try? String(data: JSONEncoder().encode(character), encoding: .utf8)) ?? "\"\""
        let targetSize = size - 6
        let bgColor = isDark ? "#161d2f" : "#ffffff"
        let borderColor = isDark ? "#2d3852" : "#e5e7eb"
        let crossColor = isDark ? "#3f4e70" : "#a9bad3"
        let strokeColor = isDark ? "#f1f5f9" : "#111827"
        let outlineColor = isDark ? "#475569" : "#d1d5db"
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:\(bgColor)}
        #grid{position:relative;width:\(size)px;height:\(size)px;border:3px solid \(borderColor);border-radius:10px;overflow:hidden}
        #grid:before,#grid:after{content:"";position:absolute;z-index:0;opacity:.65}
        #grid:before{left:50%;top:0;height:100%;border-left:1px dashed \(crossColor)}
        #grid:after{top:50%;left:0;width:100%;border-top:1px dashed \(crossColor)}
        #target{position:relative;z-index:1;width:\(targetSize)px;height:\(targetSize)px}
        </style></head><body><div id="grid"><div id="target"></div></div>
        <script src="hanzi-writer.min.js"></script><script>
        const character=\(encodedCharacter), characterData=\(strokeJSON);
        const writer=HanziWriter.create('target',character,{width:\(targetSize),height:\(targetSize),padding:8,
          showOutline:true,strokeColor:'\(strokeColor)',outlineColor:'\(outlineColor)',strokeAnimationSpeed:1,
          delayBetweenStrokes:180,charDataLoader:()=>Promise.resolve(characterData)});
        window.vocaAnimate=async()=>{writer.cancelQuiz();await writer.hideCharacter({duration:80});
          writer.animateCharacter({onComplete:()=>webkit.messageHandlers.hanzi.postMessage('animationComplete')});};
        window.vocaQuiz=()=>{writer.cancelQuiz();writer.quiz({showHintAfterMisses:2,
          highlightOnComplete:true,onComplete:()=>webkit.messageHandlers.hanzi.postMessage('quizComplete')});};
        </script></body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onStatus: (String) -> Void
        var lastCommandID: UUID?
        var lastIsDark: Bool?
        private var isReady = false
        private var pending: HanziCommand?

        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }

        func resetReady() {
            isReady = false
        }

        func run(_ command: HanziCommand, in view: WKWebView) {
            guard isReady else { pending = command; return }
            onStatus(command.kind == .quiz ? "Viết theo thứ tự nét" : "Đang xem thứ tự nét")
            view.evaluateJavaScript(command.kind == .quiz ? "window.vocaQuiz()" : "window.vocaAnimate()")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let pending { self.pending = nil; run(pending, in: webView) }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            if body == "quizComplete" { onStatus("Hoàn thành!") }
            else if body == "animationComplete" { onStatus("") }
        }
    }
}
