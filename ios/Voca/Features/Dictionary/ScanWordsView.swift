import AVFoundation
import ImageIO
import NaturalLanguage
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
        case loadingImage // loading/decoding picked photo off main thread
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
    private(set) var loadError: String?

    private let cards = CardsService()
    @ObservationIgnored private var ocrTask: Task<Void, Never>?
    @ObservationIgnored private var createTask: Task<Void, Never>?

    var selectedCount: Int { selected.count }
    var allSelected: Bool { !words.isEmpty && selected.count == words.count }
    var failedWords: [String] { results.filter { !$0.success }.map(\.word) }

    // MARK: OCR

    func beginLoadingPhoto() {
        ocrTask?.cancel()
        loadError = nil
        phase = .loadingImage
    }

    func setLoadFailure(_ message: String) {
        loadError = message
        phase = image == nil ? .empty : (words.isEmpty ? .noWords : .results)
    }

    /// Downsamples picked photo data off-main and runs Vision OCR.
    func recognize(imageData: Data, language: CardLanguage) {
        ocrTask?.cancel()
        loadError = nil
        phase = .loadingImage
        ocrTask = Task { [weak self] in
            let prepared = await Task.detached(priority: .userInitiated) {
                Self.downsampledImage(from: imageData, maxPixelSize: 2048)
            }.value
            guard !Task.isCancelled, let self else { return }
            guard let prepared else {
                self.setLoadFailure("Không thể đọc tệp ảnh đã chọn. Hãy thử ảnh khác.")
                return
            }
            await self.runRecognition(prepared, language: language)
        }
    }

    /// Recognises text in `image` and turns it into candidate words.
    func recognize(_ image: UIImage, language: CardLanguage) {
        ocrTask?.cancel()
        loadError = nil
        ocrTask = Task { [weak self] in
            guard let self else { return }
            await self.runRecognition(image, language: language)
        }
    }

    private func runRecognition(_ image: UIImage, language: CardLanguage) async {
        self.image = image
        words = []
        selected = []
        results = []
        finished = false
        loadError = nil
        phase = .recognizing

        let found = await Self.recognizeText(image, language: language)
        guard !Task.isCancelled else { return }
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
        finished = false
    }

    func toggleSelectAll() {
        if allSelected {
            selected.removeAll()
        } else {
            selected = Set(words)
        }
        finished = false
    }

    func selectFailedForRetry() {
        let retrySet = Set(failedWords)
        guard !retrySet.isEmpty else { return }
        selected = retrySet
        finished = false
    }

    // MARK: Card creation

    func cancelCreation() {
        createTask?.cancel()
        createTask = nil
    }

    func cancelAll() {
        ocrTask?.cancel()
        ocrTask = nil
        createTask?.cancel()
        createTask = nil
    }

    /// Creates one card per selected word, sequentially, reporting progress and
    /// a per-word success/failure list. Calls `onCreated` if at least one succeeded.
    func create(language: CardLanguage, onCreated: @escaping () -> Void) {
        guard !isCreating else { return }
        // Preserve chip order rather than Set order.
        let queue = words.filter { selected.contains($0) }
        guard !queue.isEmpty else { return }

        isCreating = true
        finished = false
        results = []

        createTask = Task { [weak self] in
            guard let self else { return }
            for (index, word) in queue.enumerated() {
                if Task.isCancelled { break }
                progressText = "Đang tạo \(index + 1)/\(queue.count)…"
                do {
                    let created = try await cards.createWithAI(word: word, language: language)
                    AudioPrefetchManager.shared.cacheCardInBackgroundIfEnabled(created)
                    results.append(WordResult(word: word, success: true, message: nil))
                } catch is CancellationError {
                    break
                } catch {
                    let message = (error as? ApiError)?.message ?? error.localizedDescription
                    results.append(WordResult(word: word, success: false, message: message))
                }
            }

            let cancelled = Task.isCancelled
            progressText = nil
            isCreating = false
            createTask = nil
            finished = !cancelled && !results.isEmpty

            if results.contains(where: { $0.success }) {
                onCreated()
            }
        }
    }

    // MARK: - Vision & Image helpers (off the main thread)

    nonisolated private static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    nonisolated private static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Runs `VNRecognizeTextRequest` on a background queue and returns candidate words.
    nonisolated private static func recognizeText(_ image: UIImage, language: CardLanguage) async -> [String] {
        let cgImage: CGImage?
        let orientation: CGImagePropertyOrientation
        if let direct = image.cgImage {
            cgImage = direct
            orientation = cgOrientation(for: image.imageOrientation)
        } else if let ciImage = image.ciImage {
            cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
            orientation = cgOrientation(for: image.imageOrientation)
        } else {
            cgImage = nil
            orientation = .up
        }
        guard let cgImage else { return [] }

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
                        .joined(separator: "\n")
                    resume(tokenize(text, language: language))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = language == .chinese ? ["zh-Hans"] : ["en-US"]

                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
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

    /// Uses `NLTokenizer(unit: .word)` so Chinese sentences segment cleanly into vocabulary words
    /// rather than full clauses, and filters tokens strictly by script and stop-words.
    nonisolated private static func tokenize(_ text: String, language: CardLanguage) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(language == .chinese ? .simplifiedChinese : .english)

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return true }

            let token: String
            if language == .chinese {
                let hanziOnly = String(raw.unicodeScalars.filter { Self.isHanziScalar($0) }.map(Character.init))
                guard !hanziOnly.isEmpty, hanziOnly.count <= 6 else { return true }
                token = hanziOnly
            } else {
                let lowered = raw.lowercased()
                let isLatinWord = lowered.unicodeScalars.allSatisfy {
                    ($0.value >= 0x61 && $0.value <= 0x7A) || $0 == "-" || $0 == "'"
                }
                guard isLatinWord, lowered.count >= 3, !stopWords.contains(lowered) else { return true }
                token = lowered
            }

            if seen.insert(token).inserted {
                result.append(token)
            }
            return result.count < 24
        }

        return result
    }

    nonisolated private static func isHanziScalar(_ scalar: UnicodeScalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
            || (0x20000...0x323AF).contains(scalar.value)
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
    @State private var showCameraPermissionAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image = model.image {
                        thumbnail(image)
                    }
                    sourceButtons

                    if let loadError = model.loadError {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .brandCard(padding: 12, cornerRadius: 12)
                    }

                    switch model.phase {
                    case .empty:        emptyPrompt
                    case .loadingImage: loadingPhotoView
                    case .recognizing:  recognizingView
                    case .noWords:      noWordsView
                    case .results:      resultsSection
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
                    Button(model.isCreating ? "Dừng" : (model.finished ? "Xong" : "Hủy")) {
                        if model.isCreating {
                            model.cancelCreation()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(model.isCreating)
            .onDisappear { model.cancelAll() }
            .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    model.recognize(image, language: language)
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                model.beginLoadingPhoto()
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self) else {
                            model.setLoadFailure("Không thể đọc dữ liệu ảnh từ thư viện.")
                            pickerItem = nil
                            return
                        }
                        model.recognize(imageData: data, language: language)
                    } catch {
                        model.setLoadFailure("Không tải được ảnh: \(error.localizedDescription)")
                    }
                    pickerItem = nil
                }
            }
            .alert("Chưa có quyền truy cập Camera", isPresented: $showCameraPermissionAlert) {
                Button("Mở Cài đặt") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Chọn từ thư viện") { showLibrary = true }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Hãy cấp quyền Camera cho Voca trong Cài đặt hoặc chọn ảnh từ thư viện.")
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
        .disabled(model.isCreating || model.phase == .recognizing || model.phase == .loadingImage)
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

    private var loadingPhotoView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Đang tải ảnh…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            VocaFlowLayout(spacing: 8) {
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
            VStack(spacing: 8) {
                if !model.failedWords.isEmpty {
                    Button {
                        model.selectFailedForRetry()
                        model.create(language: language, onCreated: onCreated)
                    } label: {
                        Text("Thử lại \(model.failedWords.count) từ lỗi")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }

                Button { dismiss() } label: {
                    Text("Xong").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.green)
            }
            .padding(.top, 4)
        } else {
            VStack(spacing: 8) {
                Button {
                    model.create(language: language, onCreated: onCreated)
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

                if model.isCreating {
                    Button(role: .destructive) {
                        model.cancelCreation()
                    } label: {
                        Text("Dừng tạo thẻ").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
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
                    if granted { showCamera = true } else { showCameraPermissionAlert = true }
                }
            }
        default:
            showCameraPermissionAlert = true
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
