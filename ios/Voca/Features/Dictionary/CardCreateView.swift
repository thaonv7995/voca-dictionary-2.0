import SwiftUI

/// Sheet that creates a new card from a single word via the server-side LLM.
struct CardCreateView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called after a card is created successfully (so the list can refresh).
    var onCreated: () -> Void = {}

    @State private var word = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let cards = CardsService()

    private var canSubmit: Bool {
        !isCreating && !word.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nhập từ vựng", text: $word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isCreating)
                        .onSubmit { if canSubmit { create() } }
                } footer: {
                    Text("AI sẽ tự tạo nghĩa, phát âm, ví dụ và mẹo ghi nhớ cho từ này.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: create) {
                        HStack {
                            if isCreating { ProgressView().padding(.trailing, 4) }
                            Text(isCreating ? "Đang tạo…" : "Tạo thẻ bằng AI")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Tạo thẻ mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }.disabled(isCreating)
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
    }

    private func create() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                _ = try await cards.createWithAI(
                    word: word.trimmingCharacters(in: .whitespacesAndNewlines))
                onCreated()
                dismiss()
            } catch {
                errorMessage = (error as? ApiError)?.message ?? error.localizedDescription
                isCreating = false
            }
        }
    }
}
