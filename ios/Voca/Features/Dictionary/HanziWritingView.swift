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
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HanziWriterData", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = character.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
        return root.appendingPathComponent(name).appendingPathExtension("json")
    }
}

struct HanziWritingView: View {
    let word: String

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
        if !characters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Tập viết", systemImage: "pencil.and.outline")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                            HanziCharacterPractice(character: character)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
}

private struct HanziCharacterPractice: View {
    let character: String
    @State private var strokeJSON: String?
    @State private var errorMessage: String?
    @State private var command: HanziCommand?
    @State private var status = ""

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let strokeJSON {
                    HanziWriterWebView(character: character, strokeJSON: strokeJSON,
                                       command: command, onStatus: { status = $0 })
                } else if errorMessage != nil {
                    VStack(spacing: 8) {
                        Text(character).font(.system(size: 84, weight: .semibold))
                        Button("Tải lại") { load() }.font(.caption)
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(width: 176, height: 176)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                iconButton("play.fill", label: "Xem thứ tự nét") {
                    command = HanziCommand(kind: .animate)
                }
                iconButton("pencil.and.scribble", label: "Luyện viết") {
                    command = HanziCommand(kind: .quiz)
                }
            }
            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(Brand.green)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .task(id: character) { await loadData() }
    }

    private func iconButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title3).frame(width: 44, height: 36)
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
        view.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onStatus = onStatus
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
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#fff}
        #grid{position:relative;width:176px;height:176px;border:3px solid #e5e7eb}
        #grid:before,#grid:after{content:"";position:absolute;z-index:0;opacity:.65}
        #grid:before{left:50%;top:0;height:100%;border-left:1px dashed #a9bad3}
        #grid:after{top:50%;left:0;width:100%;border-top:1px dashed #a9bad3}
        #target{position:relative;z-index:1;width:170px;height:170px}
        </style></head><body><div id="grid"><div id="target"></div></div>
        <script src="hanzi-writer.min.js"></script><script>
        const character=\(encodedCharacter), characterData=\(strokeJSON);
        const writer=HanziWriter.create('target',character,{width:170,height:170,padding:8,
          showOutline:true,strokeColor:'#111827',outlineColor:'#d1d5db',strokeAnimationSpeed:1,
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
        private var isReady = false
        private var pending: HanziCommand?

        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }

        func run(_ command: HanziCommand, in view: WKWebView) {
            guard isReady else { pending = command; return }
            onStatus(command.kind == .quiz ? "Viết theo thứ tự nét" : "Đang xem thứ tự nét")
            view.evaluateJavaScript(command.kind == .quiz ? "window.vocaQuiz()" : "window.vocaAnimate()")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let pending { self.pending = nil; run(pending, in: webView) }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let value = message.body as? String else { return }
            DispatchQueue.main.async {
                self.onStatus(value == "quizComplete" ? "Hoàn thành" : "Đã xem xong")
            }
        }
    }
}
