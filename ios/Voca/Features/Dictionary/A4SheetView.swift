import SwiftUI
import WebKit

/// A full A4 study sheet viewer for Chinese vocabulary cards.
/// Displays the print-ready A4 HTML template rendered with WKWebView,
/// supporting native AirPrint, PDF export & sharing, and AI re-generation.
struct A4SheetView: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss

    @State private var htmlContent: String?
    @State private var isLoading = true
    @State private var isRegenerating = false
    @State private var isExportingPDF = false
    @State private var errorMessage: String?
    @State private var pdfShareItem: PDFShareItem?
    @State private var showRegenerateConfirm = false
    @State private var loadGeneration = 0
    @StateObject private var webState = A4WebState()

    private let cardsService = CardsService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Đang tải phiếu học A4…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, htmlContent == nil {
                    ContentUnavailableView {
                        Label("Không tải được phiếu học", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    } actions: {
                        Button("Thử lại") {
                            Task { await loadSheet() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.green)
                    }
                } else if let html = htmlContent {
                    A4WebView(html: html, webState: webState)
                        .ignoresSafeArea(edges: .bottom)
                }

                if isRegenerating {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("AI đang tạo lại phiếu học A4…")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Phiếu học A4 • \(card.word)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .disabled(isRegenerating || isExportingPDF)
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    if htmlContent != nil && !isLoading {
                        Button {
                            showRegenerateConfirm = true
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isRegenerating || isExportingPDF)
                        .accessibilityLabel("Tạo lại bằng AI")

                        Button {
                            Task { await exportAndSharePDF() }
                        } label: {
                            if isExportingPDF {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .disabled(isRegenerating || isExportingPDF)
                        .accessibilityLabel("Chia sẻ hoặc lưu PDF")

                        Button {
                            printSheet()
                        } label: {
                            Image(systemName: "printer")
                        }
                        .disabled(isRegenerating || isExportingPDF)
                        .accessibilityLabel("In phiếu học A4")
                    }
                }
            }
            .interactiveDismissDisabled(isRegenerating || isExportingPDF)
            .alert(
                "Không thể hoàn tất",
                isPresented: Binding(
                    get: { errorMessage != nil && htmlContent != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Đóng", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog(
                "Tạo lại phiếu học A4?",
                isPresented: $showRegenerateConfirm,
                titleVisibility: .visible
            ) {
                Button("Tạo lại bằng AI", role: .destructive) {
                    Task { await regenerateSheet() }
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Hệ thống sẽ tạo lại nội dung phiếu học A4 chi tiết cho chữ \"\(card.word)\".")
            }
            .sheet(item: $pdfShareItem) { item in
                A4ActivityView(activityItems: [item.url])
            }
            .task {
                await loadSheet()
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadSheet() async {
        loadGeneration &+= 1
        let expectedGeneration = loadGeneration

        if let cached = cardsService.cachedHtml(slug: card.slug) {
            self.htmlContent = cached
            self.isLoading = false
        } else {
            isLoading = true
        }
        errorMessage = nil
        do {
            let html = try await cardsService.getHtml(slug: card.slug)
            guard loadGeneration == expectedGeneration, !Task.isCancelled else { return }
            self.htmlContent = html
        } catch is CancellationError {
            return
        } catch {
            guard loadGeneration == expectedGeneration else { return }
            if self.htmlContent == nil {
                self.errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
            }
        }
        if loadGeneration == expectedGeneration {
            isLoading = false
        }
    }

    @MainActor
    private func regenerateSheet() async {
        loadGeneration &+= 1
        let expectedGeneration = loadGeneration
        isRegenerating = true
        errorMessage = nil
        do {
            let html = try await cardsService.generateHtml(slug: card.slug)
            guard loadGeneration == expectedGeneration else { return }
            self.htmlContent = html
        } catch {
            guard loadGeneration == expectedGeneration else { return }
            self.errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        if loadGeneration == expectedGeneration {
            isRegenerating = false
        }
    }

    @MainActor
    private func printSheet() {
        guard let webView = webState.webView else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Phieu_hoc_\(card.word)"
        printInfo.orientation = .portrait
        printInfo.duplex = .none
        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()
        printController.present(animated: true) { _, _, error in
            if let error {
                Task { @MainActor in
                    errorMessage = "Lỗi in: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func exportAndSharePDF() async {
        guard let webView = webState.webView else { return }
        isExportingPDF = true
        defer { isExportingPDF = false }

        do {
            let pdfData = renderA4PDF(from: webView)
            guard !pdfData.isEmpty else {
                throw ApiError(status: 0, code: "PDF_EMPTY", message: "Không tạo được dữ liệu PDF.")
            }
            let safeChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            let sanitizedWord = String(card.word.unicodeScalars.map { safeChars.contains($0) ? Character($0) : "_" })
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            let label = sanitizedWord.isEmpty ? "voca" : sanitizedWord
            let fileName = "Phieu_hoc_\(label).pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try pdfData.write(to: tempURL, options: .atomic)
            self.pdfShareItem = PDFShareItem(url: tempURL)
        } catch {
            self.errorMessage = "Không thể xuất file PDF: \(error.localizedDescription)"
        }
    }

    /// Renders clean A4 print PDF (activating `@media print`, stripping screen backdrop/shadows).
    @MainActor
    private func renderA4PDF(from webView: WKWebView) -> Data {
        let a4Rect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89) // 210mm × 297mm @ 72dpi
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: a4Rect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: a4Rect), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, a4Rect, nil)
        let pageCount = max(1, renderer.numberOfPages)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
        for pageIndex in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

// MARK: - Supporting Types

private struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
private final class A4WebState: ObservableObject {
    weak var webView: WKWebView?
}

private struct A4WebView: UIViewRepresentable {
    private static let sharedDataStore = WKWebsiteDataStore.nonPersistent()

    let html: String
    @ObservedObject var webState: A4WebState

    func makeCoordinator() -> Coordinator {
        Coordinator(webState: webState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = Self.sharedDataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor.systemGroupedBackground

        let scroll = view.scrollView
        scroll.isScrollEnabled = true
        scroll.bounces = true
        scroll.alwaysBounceVertical = true
        scroll.minimumZoomScale = 0.2
        scroll.maximumZoomScale = 5.0
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = true
        scroll.showsVerticalScrollIndicator = true

        context.coordinator.webState.webView = view
        load(html: html, into: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webState.webView = uiView
        if context.coordinator.lastLoadedHtml != html {
            load(html: html, into: uiView, coordinator: context.coordinator)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        uiView.navigationDelegate = nil
        if coordinator.webState.webView === uiView {
            coordinator.webState.webView = nil
        }
    }

    private func load(html: String, into view: WKWebView, coordinator: Coordinator) {
        coordinator.lastLoadedHtml = html

        // Prepare HTML for mobile viewing:
        // 1. Fit 794px width (210mm A4) automatically on iPhone while supporting pinch-to-zoom.
        // 2. Add light paper backdrop for `@media screen` only (`@media print` stays clean).
        var processed = html
        if !processed.contains("viewport-fit") {
            processed = processed.replacingOccurrences(
                of: "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
                with: "<meta name=\"viewport\" content=\"width=794, minimum-scale=0.2, maximum-scale=5.0, user-scalable=yes\">"
            )
        }

        let screenStyle = """
        <style>
          @media screen {
            html, body {
              background: #f1f5f9 !important;
              margin: 0 !important;
              padding: 16px 0 32px 0 !important;
              min-height: 100%;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: flex-start;
            }
            .a4-page {
              margin: 0 auto !important;
              box-shadow: 0 6px 28px rgba(0, 0, 0, 0.14) !important;
              border-radius: 4px;
            }
          }
        </style>
        """

        if let headEnd = processed.range(of: "</head>") {
            processed.insert(contentsOf: "\n" + screenStyle + "\n", at: headEnd.lowerBound)
        }

        view.loadHTMLString(processed, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let webState: A4WebState
        var lastLoadedHtml: String?

        init(webState: A4WebState) {
            self.webState = webState
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webState.webView = webView
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .other,
               navigationAction.request.url?.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}

private struct A4ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        if let window = activeScene?.windows.first(where: \.isKeyWindow) ?? activeScene?.windows.first,
           let anchorView = window.rootViewController?.view {
            controller.popoverPresentationController?.sourceView = anchorView
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: anchorView.bounds.midX,
                y: anchorView.bounds.midY,
                width: 0,
                height: 0
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
