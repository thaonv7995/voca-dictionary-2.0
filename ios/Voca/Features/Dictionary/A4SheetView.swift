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
        isLoading = true
        errorMessage = nil
        do {
            let html = try await cardsService.getHtml(slug: card.slug)
            self.htmlContent = html
        } catch {
            self.errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func regenerateSheet() async {
        isRegenerating = true
        errorMessage = nil
        do {
            let html = try await cardsService.generateHtml(slug: card.slug)
            self.htmlContent = html
        } catch {
            self.errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
        }
        isRegenerating = false
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
                errorMessage = "Lỗi in: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func exportAndSharePDF() async {
        guard let webView = webState.webView else { return }
        isExportingPDF = true
        defer { isExportingPDF = false }

        do {
            let config = WKPDFConfiguration()
            let pdfData = try await webView.pdf(configuration: config)
            let sanitizedWord = card.word.replacingOccurrences(of: "/", with: "_")
            let fileName = "Phieu_hoc_\(sanitizedWord).pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try pdfData.write(to: tempURL, options: .atomic)
            self.pdfShareItem = PDFShareItem(url: tempURL)
        } catch {
            self.errorMessage = "Không thể xuất file PDF: \(error.localizedDescription)"
        }
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
    let html: String
    @ObservedObject var webState: A4WebState

    func makeCoordinator() -> Coordinator {
        Coordinator(webState: webState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
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
        load(html: html, into: view)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webState.webView = uiView
        if context.coordinator.lastLoadedHtml != html {
            load(html: html, into: uiView)
        }
    }

    private func load(html: String, into view: WKWebView) {
        // Prepare HTML for mobile viewing:
        // 1. Ensure viewport tag fits 794px width (standard 210mm A4) on screen and supports zoom.
        // 2. Add light paper backdrop for screen viewing.
        var processed = html
        if !processed.contains("viewport-fit") {
            processed = processed.replacingOccurrences(
                of: "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
                with: "<meta name=\"viewport\" content=\"width=794, initial-scale=1.0, minimum-scale=0.2, maximum-scale=5.0, user-scalable=yes\">"
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

        view.loadHTMLString(processed, baseURL: AppConfig.baseURL)
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
    }
}

private struct A4ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            controller.popoverPresentationController?.sourceView = rootVC.view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
