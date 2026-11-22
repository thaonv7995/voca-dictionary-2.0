import SwiftUI
import WebKit

private struct HanziStrokePayload: Decodable {
    let strokes: [String]
}

private actor HanziStrokeRepository {
    static let shared = HanziStrokeRepository()

    private struct InFlight {
        let id: UUID
        let task: Task<Data, Error>
    }

    private let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 256
        return cache
    }()
    private let strokesCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 256
        return cache
    }()
    private var inFlight: [String: InFlight] = [:]

    func strokes(for character: String) async throws -> [String] {
        if let cached = strokesCache.object(forKey: character as NSString) as? [String] {
            return cached
        }
        let raw = try await data(for: character)
        let payload = try JSONDecoder().decode(HanziStrokePayload.self, from: raw)
        strokesCache.setObject(payload.strokes as NSArray, forKey: character as NSString)
        return payload.strokes
    }

    func data(for character: String) async throws -> Data {
        if let cached = memoryCache.object(forKey: character as NSString) {
            return cached as Data
        }

        if let existing = inFlight[character] {
            return try await existing.task.value
        }

        let cache = try cacheURL(for: character)
        if let data = try? Data(contentsOf: cache), !data.isEmpty {
            memoryCache.setObject(data as NSData, forKey: character as NSString)
            return data
        }

        guard let escaped = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/\(escaped).json")
        else { throw URLError(.badURL) }

        let id = UUID()
        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> Data in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      !data.isEmpty,
                      (try? JSONSerialization.jsonObject(with: data)) != nil
                else { throw URLError(.cannotParseResponse) }
                try? data.write(to: cache, options: .atomic)
                await self?.finish(id: id, for: character, data: data)
                return data
            } catch {
                await self?.clearIfCurrent(id: id, for: character)
                throw error
            }
        }
        inFlight[character] = InFlight(id: id, task: task)
        return try await task.value
    }

    private func finish(id: UUID, for character: String, data: Data) {
        memoryCache.setObject(data as NSData, forKey: character as NSString)
        if inFlight[character]?.id == id {
            inFlight[character] = nil
        }
    }

    private func clearIfCurrent(id: UUID, for character: String) {
        if inFlight[character]?.id == id {
            inFlight[character] = nil
        }
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

    private var compactStripWidth: CGFloat {
        let count = characters.count
        guard count > 0 else { return 0 }
        let full = CGFloat(count) * 48 + CGFloat(max(0, count - 1)) * 6
        return min(full, 156)
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
                if compact && characters.count <= 3 {
                    characterStrip
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        characterStrip
                            .padding(.vertical, 1)
                    }
                    .frame(width: compact ? compactStripWidth : nil, alignment: .trailing)
                }
            }
        }
    }

    private var characterStrip: some View {
        HStack(spacing: compact ? 6 : 14) {
            ForEach(Array(characters.enumerated()), id: \.offset) { offset, character in
                let tileID = "\(offset)-\(character)"
                if compact, let onCharacterFocus {
                    HanziCharacterPractice(character: character, compact: true,
                                           displayOnly: displayOnly)
                        .id(tileID)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded { onCharacterFocus(character) }
                        )
                        .accessibilityLabel("Phóng lớn chữ \(character)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onCharacterFocus(character) }
                } else {
                    HanziCharacterPractice(character: character, compact: compact,
                                           displayOnly: displayOnly)
                        .id(tileID)
                }
            }
        }
    }
}

private struct HanziCharacterPractice: View {
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let character: String
    let compact: Bool
    let displayOnly: Bool
    @State private var strokeJSON: String?
    @State private var strokePaths: [String]?
    @State private var errorMessage: String?
    @State private var command: HanziCommand?
    @State private var status = ""

    private var canvasSize: CGFloat { compact ? 48 : displayOnly ? 240 : 176 }
    private var canvasRadius: CGFloat { compact ? 9 : displayOnly ? 16 : 12 }

    private var canvasSurfaceColor: Color {
        colorScheme == .dark ? Color(red: 0.086, green: 0.114, blue: 0.184) : .white
    }

    private var gridBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
    }

    private var strokeInkColor: Color {
        colorScheme == .dark ? Color(red: 0.945, green: 0.961, blue: 0.976) : Color(red: 0.067, green: 0.094, blue: 0.153)
    }

    var body: some View {
        if compact {
            compactDetailTile
        } else {
            interactiveBody
        }
    }

    /// Vẽ trực tiếp từ mảng nét SVG của `hanzi-writer-data` bằng SwiftUI `Canvas` thuần
    /// (không tạo WKWebView cho từng dòng danh sách), vừa khớp hình dáng nét 100% với ô detail
    /// vừa nhẹ RAM và mượt cuộn trên iPhone/iPad.
    private var compactDetailTile: some View {
        ZStack {
            canvasSurfaceColor

            HanziMiGridOverlay()
                .stroke(
                    colorScheme == .dark
                        ? Color(red: 0.58, green: 0.64, blue: 0.72).opacity(0.34)
                        : Color(red: 0.663, green: 0.729, blue: 0.827).opacity(0.65),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )

            if let strokePaths, !strokePaths.isEmpty {
                Canvas { context, size in
                    let side = min(size.width, size.height)
                    for svg in strokePaths {
                        if let path = HanziSVGPathBuilder.path(from: svg, size: side) {
                            context.fill(path, with: .color(strokeInkColor))
                        }
                    }
                }
            } else {
                Text(character)
                    .font(VocaTypography.hanziFont(size: 30, weight: .regular, isCalligraphic: theme.hanziCalligraphic))
                    .foregroundStyle(errorMessage != nil ? Color.primary : Color.secondary.opacity(0.35))
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .clipShape(RoundedRectangle(cornerRadius: canvasRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: canvasRadius, style: .continuous)
                .strokeBorder(gridBorderColor, lineWidth: 1)
        )
        .task(id: character) {
            await loadData()
        }
    }

    @ViewBuilder
    private var interactiveBody: some View {
        let content = VStack(spacing: 10) {
            ZStack {
                canvasSurfaceColor

                if let strokeJSON {
                    HanziWriterWebView(
                        character: character,
                        strokeJSON: strokeJSON,
                        size: Int(canvasSize),
                        borderWidth: compact ? 1 : (displayOnly ? 2 : 1.5),
                        cornerRadius: Int(canvasRadius),
                        isDark: colorScheme == .dark,
                        isInteractive: !compact && !displayOnly,
                        handlesScriptMessages: true,
                        command: command,
                        onStatus: { status = $0 }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if errorMessage != nil {
                    VStack(spacing: 8) {
                        Text(character)
                            .font(VocaTypography.hanziFont(size: compact ? 28 : 84, weight: .semibold, isCalligraphic: theme.hanziCalligraphic))
                        if !compact {
                            Button("Tải lại") { load() }.font(.caption)
                        }
                    }
                } else {
                    Text(character)
                        .font(VocaTypography.hanziFont(size: compact ? 26 : (displayOnly ? 120 : 86), weight: .regular, isCalligraphic: theme.hanziCalligraphic))
                        .foregroundStyle(.secondary.opacity(0.32))
                }
            }
            .frame(width: canvasSize, height: canvasSize)
            .clipShape(RoundedRectangle(cornerRadius: canvasRadius, style: .continuous))
            .overlay {
                if strokeJSON == nil {
                    RoundedRectangle(cornerRadius: canvasRadius, style: .continuous)
                        .strokeBorder(gridBorderColor, lineWidth: compact ? 1 : (displayOnly ? 2 : 1.5))
                }
            }
            .shadow(
                color: displayOnly ? .black.opacity(colorScheme == .dark ? 0.3 : 0.1) : .clear,
                radius: displayOnly ? 16 : 0,
                y: displayOnly ? 6 : 0
            )
            .animation(.easeOut(duration: 0.22), value: strokeJSON != nil)
            .contentShape(RoundedRectangle(cornerRadius: canvasRadius, style: .continuous))
            .onTapGesture {
                guard displayOnly, strokeJSON != nil else { return }
                Haptics.selection()
                command = HanziCommand(kind: .animate)
            }
            .accessibilityElement(children: displayOnly ? .combine : .contain)
            .accessibilityLabel(displayOnly ? "Chữ \(character)" : "")
            .accessibilityHint(displayOnly ? "Chạm đúp để xem thứ tự nét" : "")
            .accessibilityAddTraits(displayOnly ? .isButton : [])

            if displayOnly {
                Label("Chạm vào chữ để xem thứ tự nét", systemImage: "hand.tap")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if !compact && !displayOnly {
                HStack(spacing: 10) {
                    iconButton("play.fill", title: "Xem nét", label: "Xem thứ tự nét") {
                        Haptics.selection()
                        command = HanziCommand(kind: .animate)
                    }
                    .disabled(strokeJSON == nil)
                    iconButton("pencil.and.scribble", title: "Tự viết", label: "Luyện viết") {
                        Haptics.selection()
                        command = HanziCommand(kind: .quiz)
                    }
                    .disabled(strokeJSON == nil)
                }
                if !status.isEmpty {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.green)
                        .transition(.opacity)
                }
            }
        }
        .task(id: character) { await loadData() }

        if displayOnly {
            content
        } else {
            content
                .padding(12)
                .background(
                    Brand.cardFill(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Brand.hairlineBorder(for: colorScheme), lineWidth: 1)
                )
        }
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
        strokePaths = nil
        status = ""
        command = nil
        Task { await loadData() }
    }

    @MainActor private func loadData() async {
        errorMessage = nil
        strokeJSON = nil
        strokePaths = nil
        status = ""
        command = nil
        let targetCharacter = character
        do {
            if compact {
                let paths = try await HanziStrokeRepository.shared.strokes(for: targetCharacter)
                guard !Task.isCancelled, character == targetCharacter else { return }
                strokePaths = paths
            } else {
                let data = try await HanziStrokeRepository.shared.data(for: targetCharacter)
                guard !Task.isCancelled, character == targetCharacter else { return }
                guard let json = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
                strokeJSON = json
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, character == targetCharacter else { return }
            errorMessage = "Không tải được dữ liệu nét"
        }
    }
}

private enum HanziSVGPathBuilder {
    static func path(from source: String, size: CGFloat) -> Path? {
        let tokens = source.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let margin = size * 0.08
        let scale = (size - margin * 2) / 1024
        var index = 0
        var path = Path()

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: margin + CGFloat(x) * scale,
                    y: margin + CGFloat(900 - y) * scale)
        }

        func number(_ offset: Int) -> Double? {
            guard index + offset < tokens.count else { return nil }
            return Double(tokens[index + offset])
        }

        while index < tokens.count {
            switch tokens[index] {
            case "M":
                guard let x = number(1), let y = number(2) else { return nil }
                path.move(to: point(x, y)); index += 3
            case "L":
                guard let x = number(1), let y = number(2) else { return nil }
                path.addLine(to: point(x, y)); index += 3
            case "Q":
                guard let cx = number(1), let cy = number(2),
                      let x = number(3), let y = number(4) else { return nil }
                path.addQuadCurve(to: point(x, y), control: point(cx, cy)); index += 5
            case "C":
                guard let c1x = number(1), let c1y = number(2),
                      let c2x = number(3), let c2y = number(4),
                      let x = number(5), let y = number(6) else { return nil }
                path.addCurve(to: point(x, y), control1: point(c1x, c1y),
                              control2: point(c2x, c2y)); index += 7
            case "Z":
                path.closeSubpath(); index += 1
            default:
                return nil
            }
        }
        return path
    }
}

private struct HanziCommand: Equatable {
    enum Kind { case animate, quiz }
    let id = UUID()
    let kind: Kind
}

private struct HanziMiGridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct HanziWriterWebView: UIViewRepresentable {
    private static let sharedDataStore = WKWebsiteDataStore.nonPersistent()

    let character: String
    let strokeJSON: String
    let size: Int
    let borderWidth: Double
    let cornerRadius: Int
    let isDark: Bool
    let isInteractive: Bool
    let handlesScriptMessages: Bool
    let command: HanziCommand?
    let onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus) }

    private var renderKey: String {
        "\(character)|\(size)|\(borderWidth)|\(cornerRadius)|\(isDark)|\(strokeJSON.count)|\(strokeJSON.prefix(32))"
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        if handlesScriptMessages {
            controller.add(context.coordinator, name: "hanzi")
        }
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = Self.sharedDataStore
        configuration.suppressesIncrementalRendering = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.isUserInteractionEnabled = isInteractive
        view.isOpaque = false
        view.backgroundColor = .clear
        context.coordinator.lastRenderKey = renderKey
        if let command {
            context.coordinator.lastCommandID = command.id
            context.coordinator.run(command, in: view)
        }
        view.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onStatus = onStatus
        if view.isUserInteractionEnabled != isInteractive {
            view.isUserInteractionEnabled = isInteractive
        }
        let key = renderKey
        if context.coordinator.lastRenderKey != key {
            context.coordinator.lastRenderKey = key
            context.coordinator.resetReady()
            onStatus("")
            if let command, command.id != context.coordinator.lastCommandID {
                context.coordinator.lastCommandID = command.id
                context.coordinator.run(command, in: view)
            }
            view.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
            return
        }
        guard let command, command.id != context.coordinator.lastCommandID else { return }
        context.coordinator.lastCommandID = command.id
        context.coordinator.run(command, in: view)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "hanzi")
    }

    private var scriptURL: URL? {
        Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js", subdirectory: "HanziWriter")
            ?? Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js")
    }

    private var html: String {
        let encodedCharacter = (try? String(data: JSONEncoder().encode(character), encoding: .utf8)) ?? "\"\""
        let safeStrokeJSON = strokeJSON
            .replacingOccurrences(of: "</", with: "<\\/")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        let inset = Int(ceil(borderWidth * 2))
        let targetSize = max(size - inset, 16)
        let writerPadding = size <= 64 ? 4 : 8
        let bgColor = isDark ? "#161d2f" : "#ffffff"
        let borderColor = isDark ? "rgba(255,255,255,0.16)" : "rgba(0,0,0,0.10)"
        let crossColor = isDark ? "rgba(148,163,184,0.34)" : "#a9bad3"
        let strokeColor = isDark ? "#f1f5f9" : "#111827"
        let outlineColor = isDark ? "#475569" : "#d1d5db"
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;background:\(bgColor)}
        #grid{position:relative;width:\(size)px;height:\(size)px;border:\(borderWidth)px solid \(borderColor);border-radius:\(cornerRadius)px;overflow:hidden}
        #grid:before,#grid:after{content:"";position:absolute;z-index:0;opacity:.65}
        #grid:before{left:50%;top:0;height:100%;border-left:1px dashed \(crossColor)}
        #grid:after{top:50%;left:0;width:100%;border-top:1px dashed \(crossColor)}
        #target{position:relative;z-index:1;width:\(targetSize)px;height:\(targetSize)px}
        </style></head><body><div id="grid"><div id="target"></div></div>
        <script src="hanzi-writer.min.js"></script><script>
        const character=\(encodedCharacter), characterData=\(safeStrokeJSON);
        const writer=HanziWriter.create('target',character,{width:\(targetSize),height:\(targetSize),padding:\(writerPadding),
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
        var lastRenderKey: String?
        private var isReady = false
        private var pending: HanziCommand?

        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }

        func resetReady() {
            isReady = false
            pending = nil
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

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if body == "quizComplete" { self.onStatus("Hoàn thành!") }
                else if body == "animationComplete" { self.onStatus("") }
            }
        }
    }
}
