import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(ThemeStore.self) private var theme
    @Environment(LocalLearnerStore.self) private var learner
    @Environment(\.colorScheme) private var colorScheme

    @State private var displayName = ""
    @State private var isSavingName = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeroCard
                    appearanceQuickCard
                    displayNameCard
                    settingsMenuCard
                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(VocaThemeBackground())
            .navigationTitle("Hồ sơ")
            .onAppear {
                displayName = auth.user?.displayName ?? ""
                learner.reloadIfNeeded()
            }
            .overlay(alignment: .top) {
                if let statusMessage {
                    VocaToastBanner(
                        icon: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        message: statusMessage,
                        tint: statusIsError ? .red : Brand.semanticSuccess
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Sections

    private var profileHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.gradient)
                        .frame(width: 58, height: 58)
                        .shadow(color: theme.accent.opacity(0.30), radius: 10, y: 4)
                    Text(initials)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(resolvedName)
                            .font(.title3.bold())
                            .lineLimit(1)
                        if auth.user?.admin == true {
                            Badge(text: "ADMIN", color: theme.accent)
                        }
                    }

                    Text(auth.user?.email ?? "—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                miniStatPill(
                    icon: "flame.fill",
                    value: "\(learner.streakDays) ngày",
                    label: "Chuỗi",
                    tint: .orange
                )
                miniStatPill(
                    icon: "checkmark.circle.fill",
                    value: "\(learner.reviewedTodayCount)/\(learner.dailyGoal)",
                    label: "Hôm nay",
                    tint: theme.accent
                )
                miniStatPill(
                    icon: "star.fill",
                    value: "\(learner.favoriteSlugs.count)",
                    label: "Yêu thích",
                    tint: .yellow
                )
            }
        }
        .brandHeroCard(padding: 18, cornerRadius: 22)
    }

    private var appearanceQuickCard: some View {
        @Bindable var theme = theme
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Giao diện nhanh", systemImage: "paintpalette.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Spacer()
                Picker("Hiển thị", selection: $theme.appearance) {
                    ForEach(VocaAppearance.allCases) { mode in
                        Image(systemName: mode.icon)
                            .accessibilityLabel(mode.label)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            HStack(spacing: 10) {
                ForEach(VocaPalette.allCases) { item in
                    let isSelected = theme.palette == item
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            theme.palette = item
                        }
                        Haptics.selection()
                    } label: {
                        Circle()
                            .fill(item.gradient)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(3)
                            .overlay(
                                Circle()
                                    .strokeBorder(isSelected ? item.primary : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
                Spacer(minLength: 0)
            }
        }
        .brandCard(padding: 16, cornerRadius: 18)
    }

    private var displayNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tên hiển thị")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Tên hiển thị", text: $displayName)
                    .textFieldStyle(.plain)
                    .focused($isNameFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Brand.elevatedFill(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isNameFocused ? theme.accent : Brand.hairlineBorder(for: colorScheme),
                                lineWidth: isNameFocused ? 1.5 : 1
                            )
                    )

                Button {
                    saveName()
                } label: {
                    HStack(spacing: 6) {
                        if isSavingName {
                            ProgressView().controlSize(.small).tint(.white)
                        }
                        Text("Lưu tên")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSavingName || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(isSavingName || displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
            }
        }
        .brandCard(padding: 16, cornerRadius: 18)
    }

    private var settingsMenuCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsRootView(embeddedInNavigation: true)
            } label: {
                menuRow(
                    icon: "gearshape.fill",
                    tint: theme.accent,
                    title: "Cài đặt (AI, TTS, API keys)",
                    subtitle: "Theme, giọng đọc máy/AI, mô hình LLM & máy chủ"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            NavigationLink {
                ChangePasswordView()
            } label: {
                menuRow(
                    icon: "lock.rotation",
                    tint: .indigo,
                    title: "Đổi mật khẩu",
                    subtitle: "Cập nhật mật khẩu tài khoản"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            NavigationLink {
                ApiKeysView()
            } label: {
                menuRow(
                    icon: "key.fill",
                    tint: .teal,
                    title: "Quản lý API keys",
                    subtitle: "Khóa truy cập Voca CLI / tiện ích ngoài"
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            HStack(spacing: 12) {
                VocaIconBadge(systemImage: "server.rack", tint: .secondary, size: 36, iconSize: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Máy chủ đang kết nối")
                        .font(.subheadline.weight(.medium))
                    Text(AppConfig.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Badge(text: AppConfig.isCustomBaseURL ? "Tùy chỉnh" : "Mặc định", color: theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .brandCard(padding: 4, cornerRadius: 18)
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            Haptics.impact(.medium)
            Task { await auth.logout() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Đăng xuất")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.red)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(colorScheme == .dark ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func menuRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VocaIconBadge(systemImage: icon, tint: tint, size: 36, iconSize: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func miniStatPill(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Brand.elevatedFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var resolvedName: String {
        let trimmed = auth.user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return auth.user?.email.split(separator: "@").first.map(String.init) ?? "Người học Voca"
    }

    private var initials: String {
        let parts = resolvedName.split(separator: " ")
        if parts.count >= 2, let a = parts.first?.first, let b = parts.last?.first {
            return "\(a)\(b)".uppercased()
        }
        return String(resolvedName.prefix(2)).uppercased()
    }

    private func saveName() {
        isNameFocused = false
        isSavingName = true
        statusMessage = nil
        Task {
            do {
                try await auth.updateProfile(displayName: displayName)
                Haptics.notify(.success)
                showToast("Đã cập nhật tên hiển thị.", isError: false)
            } catch {
                Haptics.notify(.error)
                showToast((error as? ApiError)?.message ?? error.localizedDescription, isError: true)
            }
            isSavingName = false
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            statusIsError = isError
            statusMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    if statusMessage == message {
                        statusMessage = nil
                    }
                }
            }
        }
    }
}
