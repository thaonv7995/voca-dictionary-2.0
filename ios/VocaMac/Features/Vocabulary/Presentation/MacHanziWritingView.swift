import AppKit
import SwiftUI
import WebKit

// MARK: - Stroke Data Repository (Cached on Disk)

private struct MacHanziStrokePayload: Decodable {
    let strokes: [String]
}

private actor MacHanziStrokeRepository {
    static let shared = MacHanziStrokeRepository()
    private var pathCache: [String: [CGPath]] = [:]

    func data(for character: String) async throws -> Data {
        let cache = try cacheURL(for: character)
        if let data = try? Data(contentsOf: cache), !data.isEmpty {
            return data
        }

        guard let escaped = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/\(escaped).json")
        else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else {
            throw URLError(.cannotParseResponse)
        }

        try? data.write(to: cache, options: .atomic)
        return data
    }

    func strokePaths(for character: String) async -> [CGPath]? {
        if let cached = pathCache[character] {
            return cached
        }
        guard let data = try? await data(for: character),
              let payload = try? JSONDecoder().decode(MacHanziStrokePayload.self, from: data),
              !payload.strokes.isEmpty
        else {
            return nil
        }
        let parsed = payload.strokes.map { Self.parseSVGPath($0) }
        pathCache[character] = parsed
        return parsed
    }

    private static func parseSVGPath(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        var currentCmd: Character = " "
        while !scanner.isAtEnd {
            if let cmdStr = scanner.scanCharacters(from: CharacterSet.letters),
               let first = cmdStr.first {
                currentCmd = first
                if currentCmd == "Z" || currentCmd == "z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch currentCmd {
            case "M":
                if let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                    path.move(to: CGPoint(x: x, y: y))
                }
            case "L":
                if let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            case "Q":
                if let cx = scanner.scanDouble(), let cy = scanner.scanDouble(),
                   let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                    path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
                }
            case "C":
                if let c1x = scanner.scanDouble(), let c1y = scanner.scanDouble(),
                   let c2x = scanner.scanDouble(), let c2y = scanner.scanDouble(),
                   let x = scanner.scanDouble(), let y = scanner.scanDouble() {
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: c1x, y: c1y),
                        control2: CGPoint(x: c2x, y: c2y)
                    )
                }
            default:
                _ = scanner.scanDouble()
            }
        }
        return path
    }

    private func cacheURL(for character: String) throws -> URL {
        let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VocaHanziWriterData", isDirectory: true)
        try FileManager.default.createDirectory(at: cachesRoot, withIntermediateDirectories: true)
        let name = character.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-")
        return cachesRoot.appendingPathComponent(name).appendingPathExtension("json")
    }
}

// MARK: - Web-Style Chinese Writing Guide (`ChineseWritingGuide` in Web)

struct MacHanziWritingGuide: View {
    let word: String
    var compact: Bool = false
    var displayOnly: Bool = false
    var tileSize: CGFloat? = nil
    var onCharacterFocus: ((String) -> Void)?

    private var characters: [String] {
        word.map(String.init).filter { VocaDesign.containsHanCharacters($0) }
    }

    var body: some View {
        if !characters.isEmpty {
            if compact {
                let size = tileSize ?? 46
                HStack(spacing: max(5, size * 0.12)) {
                    ForEach(Array(characters.prefix(tileSize != nil ? 8 : 5).enumerated()), id: \.offset) { _, character in
                        MacCompactTianzigeTile(
                            character: character,
                            size: size,
                            onTap: onCharacterFocus == nil ? nil : {
                                onCharacterFocus?(character)
                            }
                        )
                    }
                }
            } else {
                FlowLayoutHanzi(spacing: 14) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                        MacHanziCharacterWriterCard(
                            character: character,
                            displayOnly: displayOnly,
                            onFocus: onCharacterFocus
                        )
                    }
                }
            }
        }
    }
}

@MainActor
private final class MacHanziMemoryCache {
    static let shared = MacHanziMemoryCache()
    private var storage: [String: [CGPath]] = [:]

    func get(_ character: String) -> [CGPath]? {
        storage[character]
    }

    func set(_ paths: [CGPath], for character: String) {
        storage[character] = paths
    }
}

// MARK: - Compact Tianzige Tile for Card List Row (`.hanzi-writer-card.compact`)
// Uses a single GPU-accelerated `Canvas` node + synchronous RAM cache for 120fps scrolling.

private struct MacCompactTianzigeTile: View {
    let character: String
    var size: CGFloat = 46
    var onTap: (() -> Void)? = nil

    @ViewState private var loadedPaths: [CGPath]?

    var body: some View {
        let paths = loadedPaths ?? MacHanziMemoryCache.shared.get(character)
        let cornerRadius: CGFloat = max(6, size * 0.15)

        let tileContent = ZStack {
            Canvas { context, canvasSize in
                let rect = CGRect(origin: .zero, size: canvasSize)
                let rounded = Path(roundedRect: rect, cornerRadius: cornerRadius)

                // 1. Crisp paper background
                context.fill(rounded, with: .color(.white))

                // 2. Tianzige dashed crosshairs
                let dashStyle = StrokeStyle(lineWidth: max(0.8, size * 0.018), dash: [max(3, size * 0.06), max(2.5, size * 0.05)])
                let gridColor = Color(red: 0.78, green: 0.83, blue: 0.89)

                var hLine = Path()
                hLine.move(to: CGPoint(x: 1, y: canvasSize.height * 0.5))
                hLine.addLine(to: CGPoint(x: canvasSize.width - 1, y: canvasSize.height * 0.5))
                context.stroke(hLine, with: .color(gridColor), style: dashStyle)

                var vLine = Path()
                vLine.move(to: CGPoint(x: canvasSize.width * 0.5, y: 1))
                vLine.addLine(to: CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height - 1))
                context.stroke(vLine, with: .color(gridColor), style: dashStyle)

                // 3. Vector Brush Strokes ("Nét Thanh Đậm")
                if let paths, !paths.isEmpty {
                    let padding: CGFloat = max(4, size * 0.10)
                    let innerSize = min(canvasSize.width, canvasSize.height) - padding * 2
                    let scale = innerSize / 1024.0
                    var transform = CGAffineTransform(translationX: padding, y: padding + 900.0 * scale)
                    transform = transform.scaledBy(x: scale, y: -scale)

                    let inkColor = Color(red: 0.067, green: 0.094, blue: 0.153)
                    for cgPath in paths {
                        if let transformed = cgPath.copy(using: &transform) {
                            context.fill(Path(transformed), with: .color(inkColor))
                        }
                    }
                }

                // 4. Subtle border
                let borderPath = Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: cornerRadius)
                context.stroke(
                    borderPath,
                    with: .color(Color(red: 0.75, green: 0.80, blue: 0.86)),
                    lineWidth: 1
                )
            }

            if paths == nil || paths?.isEmpty == true {
                Text(character)
                    .font(VocaDesign.kaitiFont(size: size * 0.68, weight: .bold))
                    .foregroundStyle(Color(red: 0.067, green: 0.094, blue: 0.153))
            }
        }
        .frame(width: size, height: size)

        if let onTap {
            Button(action: onTap) {
                tileContent
            }
            .buttonStyle(.plain)
            .help("Phóng lớn & luyện viết chữ \(character)")
            .task(id: character) {
                await loadPathsIfNeeded()
            }
        } else {
            tileContent
                .task(id: character) {
                    await loadPathsIfNeeded()
                }
        }
    }

    private func loadPathsIfNeeded() async {
        if MacHanziMemoryCache.shared.get(character) != nil {
            return
        }
        if let fetched = await MacHanziStrokeRepository.shared.strokePaths(for: character) {
            MacHanziMemoryCache.shared.set(fetched, for: character)
            loadedPaths = fetched
        }
    }
}

// MARK: - Full Interactive Hanzi Writer Card (`.hanzi-writer-card`)

private struct MacHanziCommand: Equatable {
    enum Kind {
        case animate
        case quiz
    }
    let id = UUID()
    let kind: Kind
}

private struct MacHanziCharacterWriterCard: View {
    let character: String
    let displayOnly: Bool
    var onFocus: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var strokeJSON: String?
    @ViewState private var loadError = false
    @ViewState private var command: MacHanziCommand?
    @ViewState private var mode: String = "idle"

    private var boxSize: CGFloat {
        displayOnly ? 300 : 132
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Crisp White Tianzige Background + Calligraphic Fallback
                ZStack {
                    RoundedRectangle(cornerRadius: displayOnly ? 16 : 10, style: .continuous)
                        .fill(Color.white)

                    GeometryReader { geo in
                        Path { path in
                            let midY = geo.size.height / 2
                            path.move(to: CGPoint(x: 0, y: midY))
                            path.addLine(to: CGPoint(x: geo.size.width, y: midY))
                        }
                        .stroke(
                            Color(red: 0.78, green: 0.83, blue: 0.89),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )

                        Path { path in
                            let midX = geo.size.width / 2
                            path.move(to: CGPoint(x: midX, y: 0))
                            path.addLine(to: CGPoint(x: midX, y: geo.size.height))
                        }
                        .stroke(
                            Color(red: 0.78, green: 0.83, blue: 0.89),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    }

                    if strokeJSON == nil || loadError {
                        Text(character)
                            .font(VocaDesign.kaitiFont(size: displayOnly ? 190 : 82, weight: .bold))
                            .foregroundStyle(Color(red: 0.067, green: 0.094, blue: 0.153))
                    }
                }

                if let strokeJSON, !loadError {
                    MacHanziWriterWebView(
                        character: character,
                        strokeJSON: strokeJSON,
                        size: Int(boxSize),
                        isDark: colorScheme == .dark,
                        command: command,
                        onModeChange: { newMode in
                            mode = newMode
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: displayOnly ? 16 : 10, style: .continuous))
                }
            }
            .frame(width: boxSize, height: boxSize)
            .overlay(
                RoundedRectangle(cornerRadius: displayOnly ? 16 : 10, style: .continuous)
                    .strokeBorder(Color(red: 0.75, green: 0.80, blue: 0.86), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

            // Action Buttons (`Play` Xem thứ tự nét | `Pen` Luyện viết | `Zoom` Phóng lớn)
            HStack(spacing: 0) {
                Button {
                    mode = "animating"
                    command = MacHanziCommand(kind: .animate)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mode == "animating" ? .white : .secondary)
                        .frame(width: 44, height: 34)
                        .background(mode == "animating" ? VocaDesign.brandGreen : Color.clear)
                }
                .buttonStyle(.plain)
                .help("Xem thứ tự nét chữ \(character)")

                Divider()
                    .frame(height: 22)

                Button {
                    mode = "practicing"
                    command = MacHanziCommand(kind: .quiz)
                } label: {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            (mode == "practicing" || mode == "complete") ? .white : .secondary
                        )
                        .frame(width: 44, height: 34)
                        .background(
                            (mode == "practicing" || mode == "complete")
                                ? VocaDesign.brandGreen
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
                .help("Luyện viết chữ \(character) theo thứ tự nét")

                if !displayOnly, let onFocus {
                    Divider()
                        .frame(height: 22)

                    Button {
                        onFocus(character)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 34)
                    }
                    .buttonStyle(.plain)
                    .help("Phóng lớn ô luyện viết chữ \(character)")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if mode == "practicing" {
                Text("Viết theo đúng thứ tự nét trong ô.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if mode == "complete" {
                Text("Hoàn thành ✓")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VocaDesign.brandGreen)
            }
        }
        .frame(width: displayOnly ? 316 : 142)
        .task(id: character) {
            await loadStrokeData()
        }
    }

    @MainActor
    private func loadStrokeData() async {
        loadError = false
        do {
            let data = try await MacHanziStrokeRepository.shared.data(for: character)
            guard let json = String(data: data, encoding: .utf8) else {
                loadError = true
                return
            }
            strokeJSON = json
        } catch {
            loadError = true
        }
    }
}

// MARK: - NSViewRepresentable WKWebView for `hanzi-writer.min.js`

private struct MacHanziWriterWebView: NSViewRepresentable {
    let character: String
    let strokeJSON: String
    let size: Int
    var isDark: Bool = false
    let command: MacHanziCommand?
    let onModeChange: (String) -> Void

    private var renderKey: String {
        "\(character)|\(size)|\(isDark)|\(strokeJSON.hashValue)"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onModeChange: onModeChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "hanzi")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.lastRenderedKey = renderKey
        webView.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onModeChange = onModeChange
        if context.coordinator.lastRenderedKey != renderKey {
            context.coordinator.lastRenderedKey = renderKey
            context.coordinator.resetForReload()
            webView.loadHTMLString(html, baseURL: scriptURL?.deletingLastPathComponent())
        }
        guard let command, command.id != context.coordinator.lastCommandID else {
            return
        }
        context.coordinator.lastCommandID = command.id
        context.coordinator.run(command, in: webView)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.navigationDelegate = nil
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "hanzi")
    }

    private var scriptURL: URL? {
        Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js", subdirectory: "HanziWriter")
            ?? Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js")
    }

    private var inlineScriptTag: String {
        if let url = scriptURL, let jsContent = try? String(contentsOf: url, encoding: .utf8) {
            return "<script>\(jsContent)</script>"
        }
        return "<script src=\"hanzi-writer.min.js\"></script>"
    }

    private var sanitizedStrokeJSON: String {
        strokeJSON
            .replacingOccurrences(of: "</", with: "<\\/")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    private var html: String {
        let encodedCharacter = (try? String(data: JSONEncoder().encode(character), encoding: .utf8)) ?? "\"\""
        let bgColor = isDark ? "#18181b" : "#ffffff"
        let gridBorderColor = isDark ? "#3f3f46" : "#cbd5e1"
        let strokeColor = isDark ? "#f4f4f5" : "#111827"
        let outlineColor = isDark ? "#3f3f46" : "#cbd5e1"
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        * { box-sizing: border-box; user-select: none; -webkit-user-select: none; }
        html, body {
          margin: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: \(bgColor);
        }
        #grid {
          position: relative;
          width: \(size)px;
          height: \(size)px;
          display: grid;
          place-items: center;
          background: \(bgColor);
        }
        #grid::before, #grid::after {
          content: "";
          position: absolute;
          z-index: 0;
          pointer-events: none;
          opacity: 0.75;
        }
        #grid::before {
          inset: 50% 0 auto;
          border-top: 1px dashed \(gridBorderColor);
        }
        #grid::after {
          inset: 0 auto 0 50%;
          border-left: 1px dashed \(gridBorderColor);
        }
        #target {
          position: relative;
          z-index: 1;
          width: \(size)px;
          height: \(size)px;
        }
        </style>
        </head>
        <body>
        <div id="grid"><div id="target"></div></div>
        \(inlineScriptTag)
        <script>
        const character = \(encodedCharacter);
        const characterData = \(sanitizedStrokeJSON);
        const writer = HanziWriter.create('target', character, {
          width: \(size),
          height: \(size),
          padding: 8,
          showOutline: true,
          showCharacter: true,
          strokeColor: '\(strokeColor)',
          outlineColor: '\(outlineColor)',
          drawingColor: '#059669',
          highlightColor: '#10b981',
          strokeWidth: 4,
          outlineWidth: 2,
          drawingWidth: 7,
          strokeAnimationSpeed: 1.25,
          delayBetweenStrokes: 180,
          charDataLoader: () => Promise.resolve(characterData)
        });
        window.vocaAnimate = async () => {
          writer.cancelQuiz();
          await writer.hideCharacter({ duration: 100 });
          writer.animateCharacter({
            onComplete: () => {
              window.webkit.messageHandlers.hanzi.postMessage('idle');
            }
          });
        };
        window.vocaQuiz = async () => {
          writer.cancelQuiz();
          await writer.hideCharacter({ duration: 100 });
          writer.quiz({
            showHintAfterMisses: 2,
            highlightOnComplete: true,
            onComplete: () => {
              window.webkit.messageHandlers.hanzi.postMessage('complete');
            }
          });
        };
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onModeChange: (String) -> Void
        var lastCommandID: UUID?
        var lastRenderedKey: String?
        private var isReady = false
        private var pending: MacHanziCommand?

        init(onModeChange: @escaping (String) -> Void) {
            self.onModeChange = onModeChange
        }

        func resetForReload() {
            isReady = false
            pending = nil
        }

        func run(_ command: MacHanziCommand, in webView: WKWebView) {
            guard isReady else {
                pending = command
                return
            }
            let js = command.kind == .quiz ? "window.vocaQuiz()" : "window.vocaAnimate()"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            if let pending {
                self.pending = nil
                run(pending, in: webView)
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let status = message.body as? String else { return }
            DispatchQueue.main.async {
                self.onModeChange(status)
            }
        }
    }
}

// MARK: - Zoomed Hanzi Focus Popover (`HanziFocusPopover` in Web)

struct MacHanziFocusOverlay: View {
    let word: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.45))
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 10) {
                        VocaIconBadge(systemImage: "character.textbox", tint: VocaDesign.brandGreen, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Luyện viết & Thứ tự nét chữ Hán")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Bấm ▶ để xem nét bút hoặc ✎ để dùng chuột/trackpad viết trực tiếp")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }

                MacHanziWritingGuide(word: word, compact: false, displayOnly: true)
            }
            .padding(24)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 34, y: 12)
        }
    }
}

// MARK: - Simple Horizontal Flow Layout for Hanzi Tiles

private struct FlowLayoutHanzi: Layout {
    var spacing: CGFloat = 14

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, currentX - spacing)
        }

        return (
            CGSize(width: min(usedWidth, maxWidth), height: currentY + lineHeight),
            points
        )
    }
}
