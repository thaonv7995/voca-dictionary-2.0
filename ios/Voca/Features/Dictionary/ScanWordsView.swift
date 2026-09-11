import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

// MARK: - Model

/// Drives the "scan a photo → OCR → pick words → create cards" flow.
///
/// OCR runs off the main thread (Vision); everything user-facing is `@MainActor`.
@MainActor
@Observable
final class ScanWordsModel {

    /// Where the flow currently is (drives which section the view shows).
    enum Phase {
        case empty        // no image picked yet
        case recognizing  // running Vision OCR
        case results      // candidate words ready
        case noWords      // OCR finished but produced nothing usable
    }

    /// Outcome of creating a single card, shown in the finish summary.
    struct WordResult: Identifiable {
        let id = UUID()
        let word: String
        let success: Bool
        let message: String?
    }

    private(set) var phase: Phase = .empty
    private(set) var image: UIImage?
    private(set) var words: [String] = []
    var selected: Set<String> = []

    private(set) var isCreating = false
    private(set) var progressText: String?
    private(set) var results: [WordResult] = []
    private(set) var finished = false

    private let cards = CardsService()

    var selectedCount: Int { selected.count }
    var allSelected: Bool { !words.isEmpty && selected.count == words.count }

    // MARK: OCR

    /// Recognises text in `image` and turns it into candidate words.
    func recognize(_ image: UIImage, language: CardLanguage) async {
        self.image = image
        words = []
        selected = []
        results = []
        finished = false
        phase = .recognizing

        let found = await Self.recognizeText(image, language: language)
        words = found
        phase = found.isEmpty ? .noWords : .results
    }

    // MARK: Selection

    func toggle(_ word: String) {
        if selected.contains(word) {
            selected.remove(word)
        } else {
            selected.insert(word)
        }
    }

    func toggleSelectAll() {
        if allSelected {
            selected.removeAll()
        } else {
            selected = Set(words)
        }
    }

    // MARK: Card creation

    /// Creates one card per selected word, sequentially, reporting progress and
    /// a per-word success/failure list. Calls `onCreated` if at least one succeeded.
    func create(language: CardLanguage, onCreated: @escaping () -> Void) async {
        // Preserve chip order rather than Set order.
        let queue = words.filter { selected.contains($0) }
        guard !queue.isEmpty else { return }

        isCreating = true
        finished = false
        results = []

        for (index, word) in queue.enumerated() {
            progressText = "Đang tạo \(index + 1)/\(queue.count)…"
            do {
                _ = try await cards.createWithAI(word: word, language: language)
                results.append(WordResult(word: word, success: true, message: nil))
            } catch {
                let message = (error as? ApiError)?.message ?? error.localizedDescription
                results.append(WordResult(word: word, success: false, message: message))
            }
        }

        progressText = nil
        isCreating = false
        finished = true

        if results.contains(where: { $0.success }) {
            onCreated()
        }
    }

    // MARK: - Vision (off the main thread)

    /// Runs `VNRecognizeTextRequest` on a background queue and returns candidate words.
    nonisolated private static func recognizeText(_ image: UIImage, language: CardLanguage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var didResume = false
                let resume: ([String]) -> Void = { words in
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: words)
                }

                let request = VNRecognizeTextRequest { request, _ in
                    let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ")
                    resume(tokenize(text, language: language))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = language == .chinese ? ["zh-Hans"] : ["en-US"]

                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    resume([])
                }
            }
        }
    }

    /// English stop-words filtered out of OCR candidates.
    nonisolated private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "have", "has", "had",
        "are", "was", "were", "you", "your", "our", "their", "they", "them", "its",
        "but", "not", "all", "any", "can", "will", "would", "could", "should",
        "may", "might", "out", "off", "get", "got", "one", "two", "use", "used",
        "into", "over", "than", "then", "some", "such", "only", "also", "more",
        "most", "when", "what", "which", "who", "whom", "why", "how", "been",
        "being", "does", "did", "done", "each", "other", "about", "there", "here",
        "very", "just", "like", "want", "need", "make", "made", "know", "these",
        "those", "because", "while", "where",
    ]

    /// Lowercases, splits on non-letters, drops short tokens and stop-words,
    /// dedupes (preserving order) and caps the list.
    nonisolated private static func tokenize(_ text: String, language: CardLanguage) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for token in text.lowercased().components(separatedBy: CharacterSet.letters.inverted) {
            guard language == .chinese ? !token.isEmpty : token.count >= 3 else { continue }
            guard language == .chinese || !stopWords.contains(token) else { continue }
            guard !seen.contains(token) else { continue }
            seen.insert(token)
            result.append(token)
            if result.count >= 24 { break }
        }
        return result
    }
}

// MARK: - View

/// A sheet that scans a photo, extracts candidate English words and creates a
/// card for each selected word via the server-side LLM.
struct ScanWordsView: View {
    @Environment(\.dismiss) private var dismiss

    let language: CardLanguage

    /// Called after cards are created so the dictionary list can refresh.
    var onCreated: () -> Void = {}

    @State private var model = ScanWordsModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image = model.image {
                        thumbnail(image)
                    }
                    sourceButtons

                    switch model.phase {
                    case .empty:       emptyPrompt
                    case .recognizing: recognizingView
                    case .noWords:     noWordsView
                    case .results:     resultsSection
                    }

                    if !model.results.isEmpty {
                        creationSummary
                    }
                }
                .padding()
            }
            .navigationTitle("Quét ảnh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.finished ? "Xong" : "Hủy") { dismiss() }
                        .disabled(model.isCreating)
                }
            }
            .interactiveDismissDisabled(model.isCreating)
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await model.recognize(image, language: language) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await model.recognize(image, language: language)
                    }
                    pickerItem = nil
                }
            }
        }
    }

    // MARK: Image source

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            Button(action: openCamera) {
                Label("Chụp ảnh", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            Button { showLibrary = true } label: {
                Label("Chọn ảnh", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .tint(Brand.green)
        .disabled(model.isCreating || model.phase == .recognizing)
    }

    private func thumbnail(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Phase sections

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(Brand.green)
            Text(language == .chinese
                 ? "Chụp hoặc chọn một ảnh có chữ Hán"
                 : "Chụp hoặc chọn một ảnh có chữ tiếng Anh")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Voca sẽ nhận diện chữ trong ảnh, gợi ý các từ và tạo thẻ cho những từ bạn chọn.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var recognizingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Đang nhận diện…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var noWordsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Không tìm thấy từ nào")
                .font(.headline)
            Text(language == .chinese
                 ? "Thử chọn ảnh rõ nét hơn hoặc có nhiều chữ Hán hơn."
                 : "Thử chọn ảnh rõ nét hơn hoặc có nhiều chữ tiếng Anh hơn.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chọn từ để tạo thẻ")
                    .font(.headline)
                Spacer()
                Button(model.allSelected ? "Bỏ chọn" : "Chọn tất cả") {
                    model.toggleSelectAll()
                }
                .font(.subheadline.weight(.medium))
                .tint(Brand.green)
                .disabled(model.isCreating)
            }

            FlowLayout(spacing: 8) {
                ForEach(model.words, id: \.self) { word in
                    chip(word)
                }
            }

            createButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ word: String) -> some View {
        let isSelected = model.selected.contains(word)
        return Button { model.toggle(word) } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                }
                Text(word).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.white : Brand.green)
            .background(isSelected ? Brand.green : Brand.greenSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.isCreating)
    }

    @ViewBuilder private var createButton: some View {
        if model.finished {
            Button { dismiss() } label: {
                Text("Xong").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
            .padding(.top, 4)
        } else {
            Button {
                Task { await model.create(language: language, onCreated: onCreated) }
            } label: {
                HStack {
                    if model.isCreating { ProgressView().padding(.trailing, 4) }
                    Text(model.progressText ?? "Tạo \(model.selectedCount) thẻ")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.green)
            .disabled(model.selectedCount == 0 || model.isCreating)
            .padding(.top, 4)
        }
    }

    // MARK: Finish summary

    private var creationSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kết quả")
                .font(.headline)
            ForEach(model.results) { result in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: result.success
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                        .foregroundStyle(result.success ? Brand.green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.word).font(.subheadline.weight(.medium))
                        if let message = result.message, !result.success {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    // MARK: Camera launch (permission-aware, falls back to library)

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // No camera (e.g. Simulator) → use the library instead.
            showLibrary = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { showCamera = true } else { showLibrary = true }
                }
            }
        default:
            // Denied / restricted → gracefully fall back to the library.
            showLibrary = true
        }
    }
}

// MARK: - Camera picker (UIKit bridge)

/// Thin `UIImagePickerController` wrapper for taking a photo with the camera.
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Flow layout

/// A simple wrapping layout (left-to-right, top-to-bottom) for the word chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widestRow = max(widestRow, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        widestRow = max(widestRow, x - spacing)
        let width = maxWidth.isFinite ? maxWidth : max(widestRow, 0)
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
