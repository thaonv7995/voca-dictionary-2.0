import XCTest
@testable import VocaMac

final class MacFeatureModelTests: XCTestCase {
    @MainActor
    func testSessionBootstrapRestoresPersistedAccount() async {
        let account = MacSessionStore.Account(
            id: "account-123",
            displayName: "Thao Nguyen",
            email: "thao@example.com"
        )
        let persistence = InMemoryMacSessionPersistence(account: account)
        let session = MacSessionStore(
            persistence: persistence,
            authentication: PreviewMacAuthenticationService()
        )

        await session.bootstrap()

        XCTAssertEqual(session.phase, .signedIn(account))
        XCTAssertEqual(session.account, account)
        XCTAssertTrue(session.isSignedIn)
    }

    @MainActor
    func testSessionBootstrapShowsSignedOutWhenAccountIsMissing() async {
        let persistence = InMemoryMacSessionPersistence()
        let session = MacSessionStore(
            persistence: persistence,
            authentication: PreviewMacAuthenticationService()
        )

        await session.bootstrap()

        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertNil(session.account)
        XCTAssertFalse(session.isSignedIn)
    }

    @MainActor
    func testSessionRejectsEmptyEmail() async {
        let session = MacSessionStore(
            persistence: InMemoryMacSessionPersistence(),
            authentication: PreviewMacAuthenticationService()
        )

        await session.signIn(
            email: "   ",
            password: "password"
        )

        XCTAssertEqual(session.signInError, .missingEmail)
        XCTAssertFalse(session.isSignedIn)
    }

    @MainActor
    func testSessionRejectsInvalidEmail() async {
        let session = MacSessionStore(
            persistence: InMemoryMacSessionPersistence(),
            authentication: PreviewMacAuthenticationService()
        )

        await session.signIn(
            email: "invalid-email",
            password: "password"
        )

        XCTAssertEqual(session.signInError, .invalidEmail)
        XCTAssertFalse(session.isSignedIn)
    }

    @MainActor
    func testSessionRejectsMissingPassword() async {
        let session = MacSessionStore(
            persistence: InMemoryMacSessionPersistence(),
            authentication: PreviewMacAuthenticationService()
        )

        await session.signIn(
            email: "thao@example.com",
            password: ""
        )

        XCTAssertEqual(session.signInError, .missingPassword)
        XCTAssertFalse(session.isSignedIn)
    }

    @MainActor
    func testSessionNormalizesEmailAndCreatesDisplayName() async {
        let persistence = InMemoryMacSessionPersistence()
        let session = MacSessionStore(
            persistence: persistence,
            authentication: PreviewMacAuthenticationService()
        )

        await session.signIn(
            email: "  thao.nguyen@example.com  ",
            password: "password"
        )

        XCTAssertEqual(
            session.account,
            MacSessionStore.Account(
                id: "thao.nguyen@example.com",
                displayName: "Thao Nguyen",
                email: "thao.nguyen@example.com"
            )
        )
        XCTAssertNil(session.signInError)
        XCTAssertTrue(session.isSignedIn)
    }

    @MainActor
    func testSessionSignOutClearsPersistedAccount() {
        let persistence = InMemoryMacSessionPersistence()
        let session = MacSessionStore(
            persistence: persistence,
            authentication: PreviewMacAuthenticationService()
        )

        session.usePreviewAccount()
        XCTAssertTrue(session.isSignedIn)

        session.signOut()

        XCTAssertEqual(session.phase, .signedOut)
        XCTAssertNil(session.account)
        XCTAssertNil(persistence.loadAccount())
    }

    func testTodaySnapshotClampsCompletedGoalCount() {
        let snapshot = MacTodaySnapshot(
            dueCount: 3,
            completedToday: 25,
            dailyGoal: 20,
            streakDays: 4,
            difficultWordCount: 2,
            recentlyAddedCount: 5
        )

        XCTAssertEqual(snapshot.completedGoalCount, 20)
        XCTAssertEqual(snapshot.remainingGoalCount, 0)
        XCTAssertEqual(snapshot.goalProgress, 1)
    }

    func testTodaySnapshotCalculatesRemainingGoal() {
        let snapshot = MacTodaySnapshot(
            dueCount: 8,
            completedToday: 7,
            dailyGoal: 20,
            streakDays: 2,
            difficultWordCount: 4,
            recentlyAddedCount: 3
        )

        XCTAssertEqual(snapshot.completedGoalCount, 7)
        XCTAssertEqual(snapshot.remainingGoalCount, 13)
        XCTAssertEqual(snapshot.goalProgress, 0.35, accuracy: 0.0001)
    }

    func testTodaySnapshotHandlesZeroDailyGoal() {
        let snapshot = MacTodaySnapshot(
            dueCount: 0,
            completedToday: 0,
            dailyGoal: 0,
            streakDays: 0,
            difficultWordCount: 0,
            recentlyAddedCount: 0
        )

        XCTAssertEqual(snapshot.completedGoalCount, 0)
        XCTAssertEqual(snapshot.remainingGoalCount, 0)
        XCTAssertEqual(snapshot.goalProgress, 0)
    }

    func testVocabularyPreviewContainsEnglishAndChineseItems() {
        let items = MacVocabularyItem.previewItems

        XCTAssertTrue(
            items.contains(where: { $0.language == .english })
        )
        XCTAssertTrue(
            items.contains(where: { $0.language == .chinese })
        )
    }

    func testVocabularyPreviewIdentifiersAreUnique() {
        let identifiers = MacVocabularyItem.previewItems.map(\.id)

        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count
        )
    }

    func testVocabularyPreviewContainsDueAndFavoriteStates() {
        let items = MacVocabularyItem.previewItems

        XCTAssertTrue(items.contains(where: \.isDue))
        XCTAssertTrue(items.contains(where: \.isFavorite))
        XCTAssertTrue(items.contains(where: { !$0.isDue }))
        XCTAssertTrue(items.contains(where: { !$0.isFavorite }))
    }

    func testReviewPreviewIdentifiersAreUnique() {
        let identifiers = MacReviewCard.previewCards.map(\.id)

        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count
        )
    }

    func testReviewPreviewReferencesKnownVocabulary() {
        let vocabularyIdentifiers = Set(
            MacVocabularyItem.previewItems.map(\.id)
        )

        for card in MacReviewCard.previewCards {
            XCTAssertTrue(
                vocabularyIdentifiers.contains(card.id),
                "Review card \(card.id) should reference a known vocabulary item."
            )
        }
    }

    func testReviewGradesUseUniqueKeyboardKeys() {
        let keys = MacReviewGrade.allCases.map {
            String($0.keyboardKey.character)
        }

        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(keys, ["1", "2", "3", "4"])
    }

    func testPracticeActivitiesCoverEverySupportedKind() {
        let kinds = Set(
            MacPracticeActivity.defaults.map(\.kind)
        )

        XCTAssertEqual(
            kinds,
            Set(MacPracticeActivity.Kind.allCases)
        )
    }

    func testPracticeActivitiesHaveValidEstimates() {
        for activity in MacPracticeActivity.defaults {
            XCTAssertGreaterThan(activity.estimatedMinutes, 0)
            XCTAssertGreaterThan(activity.itemCount, 0)
            XCTAssertFalse(activity.kind.title.isEmpty)
            XCTAssertFalse(activity.kind.systemImage.isEmpty)
            XCTAssertFalse(activity.kind.description.isEmpty)
        }
    }

    func testPracticeQuestionsHaveOneCorrectOption() {
        for question in MacPracticeQuestion.multipleChoice {
            XCTAssertFalse(question.options.isEmpty)
            XCTAssertEqual(
                question.options.filter {
                    $0 == question.correctAnswer
                }.count,
                1
            )
        }
    }

    func testPracticeQuestionIdentifiersAreUnique() {
        let identifiers = MacPracticeQuestion.multipleChoice.map(\.id)

        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count
        )
    }

    func testInsightsCalculatesTotalActivity() {
        let snapshot = MacInsightsSnapshot.preview

        XCTAssertEqual(
            snapshot.totalActivityCount,
            snapshot.reviewedThisWeek + snapshot.practicedThisWeek
        )
    }

    func testInsightsFindsMostActiveDay() {
        let snapshot = MacInsightsSnapshot.preview

        XCTAssertEqual(snapshot.mostActiveDay?.day, "Sat")
        XCTAssertEqual(snapshot.mostActiveDay?.reviewedCount, 18)
        XCTAssertEqual(snapshot.mostActiveDay?.practicedCount, 9)
    }

    func testInsightsDailyMetricIdentifiersAreUnique() {
        let identifiers = MacInsightsSnapshot.preview.dailyMetrics.map(\.id)

        XCTAssertEqual(
            Set(identifiers).count,
            identifiers.count
        )
    }

    func testInsightsMetricsDoNotContainNegativeValues() {
        let snapshot = MacInsightsSnapshot.preview

        XCTAssertGreaterThanOrEqual(snapshot.reviewedThisWeek, 0)
        XCTAssertGreaterThanOrEqual(snapshot.practicedThisWeek, 0)
        XCTAssertGreaterThanOrEqual(snapshot.accuracyPercent, 0)
        XCTAssertLessThanOrEqual(snapshot.accuracyPercent, 100)
        XCTAssertGreaterThanOrEqual(snapshot.streakDays, 0)
        XCTAssertGreaterThanOrEqual(snapshot.difficultWordCount, 0)

        for metric in snapshot.dailyMetrics {
            XCTAssertGreaterThanOrEqual(metric.reviewedCount, 0)
            XCTAssertGreaterThanOrEqual(metric.practicedCount, 0)
        }
    }

    func testAssistantMessagePreservesRoleAndContent() {
        let message = MacAssistantMessage(
            role: .assistant,
            content: "A concise explanation."
        )

        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "A concise explanation.")
    }

    @MainActor
    func testPreferencesLoadPersistedValues() {
        let expected = MacPreferences(
            appearance: .dark,
            defaultDestination: .vocabulary,
            showInMenuBar: true,
            launchAtLogin: true,
            dailyGoal: 30,
            playAudioAutomatically: true,
            enableAssistantFeatures: false
        )
        let persistence = InMemoryMacPreferencesPersistence(
            preferences: expected
        )

        let preferences = MacPreferencesStore(
            persistence: persistence
        )

        XCTAssertEqual(preferences.appearance, .dark)
        XCTAssertEqual(
            preferences.defaultDestination,
            .vocabulary
        )
        XCTAssertTrue(preferences.showInMenuBar)
        XCTAssertTrue(preferences.launchAtLogin)
        XCTAssertEqual(preferences.dailyGoal, 30)
        XCTAssertTrue(preferences.playAudioAutomatically)
        XCTAssertFalse(preferences.enableAssistantFeatures)
    }

    @MainActor
    func testPreferencesPersistUpdates() {
        let persistence = InMemoryMacPreferencesPersistence()
        let preferences = MacPreferencesStore(
            persistence: persistence
        )

        preferences.setAppearance(.light)
        preferences.setDefaultDestination(.practice)
        preferences.setShowInMenuBar(true)
        preferences.setLaunchAtLogin(true)
        preferences.setDailyGoal(35)
        preferences.setPlayAudioAutomatically(true)
        preferences.setEnableAssistantFeatures(false)

        XCTAssertEqual(
            persistence.load(),
            MacPreferences(
                appearance: .light,
                defaultDestination: .practice,
                showInMenuBar: true,
                launchAtLogin: true,
                dailyGoal: 35,
                playAudioAutomatically: true,
                enableAssistantFeatures: false
            )
        )
    }

    @MainActor
    func testPreferencesClampDailyGoal() {
        let preferences = MacPreferencesStore(
            persistence: InMemoryMacPreferencesPersistence()
        )

        preferences.setDailyGoal(0)
        XCTAssertEqual(preferences.dailyGoal, 1)

        preferences.setDailyGoal(101)
        XCTAssertEqual(preferences.dailyGoal, 100)
    }

    @MainActor
    func testPreferencesResetToDefaults() {
        let persistence = InMemoryMacPreferencesPersistence(
            preferences: MacPreferences(
                appearance: .dark,
                defaultDestination: .review,
                showInMenuBar: false,
                menuBarBadgeStyle: .iconOnly,
                quickLookupHotkey: .disabled,
                launchAtLogin: false,
                hideDockIcon: false,
                dailyGoal: 50,
                playAudioAutomatically: true,
                enableAssistantFeatures: false
            )
        )
        let preferences = MacPreferencesStore(
            persistence: persistence
        )

        preferences.reset()

        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertEqual(preferences.defaultDestination, .today)
        XCTAssertTrue(preferences.showInMenuBar)
        XCTAssertEqual(preferences.menuBarBadgeStyle, .dueCount)
        XCTAssertEqual(preferences.quickLookupHotkey, .optionSpace)
        XCTAssertFalse(preferences.launchAtLogin)
        XCTAssertFalse(preferences.hideDockIcon)
        XCTAssertEqual(preferences.dailyGoal, 20)
        XCTAssertFalse(preferences.playAudioAutomatically)
        XCTAssertTrue(preferences.enableAssistantFeatures)
        XCTAssertEqual(persistence.load(), .default)
    }

    @MainActor
    func testPreferencesPersistMenuBarBadgeAndQuickLookupHotkey() {
        let persistence = InMemoryMacPreferencesPersistence()
        let preferences = MacPreferencesStore(
            persistence: persistence
        )

        preferences.setMenuBarBadgeStyle(.dotOnly)
        preferences.setQuickLookupHotkey(.commandShiftSpace)

        XCTAssertEqual(preferences.menuBarBadgeStyle, .dotOnly)
        XCTAssertEqual(preferences.quickLookupHotkey, .commandShiftSpace)
        XCTAssertEqual(persistence.load().menuBarBadgeStyle, .dotOnly)
        XCTAssertEqual(persistence.load().quickLookupHotkey, .commandShiftSpace)
        XCTAssertEqual(
            MacPreferencesStore.QuickLookupHotkey.commandShiftSpace.badgeLabel,
            "⇧⌘Space"
        )
    }

    @MainActor
    func testReviewStoreRestoresCardForUndo() async {
        let store = MacReviewStore(
            repository: PreviewMacReviewRepository(),
            ledger: MacActivityLedger(
                persistence: InMemoryMacActivityLedgerPersistence()
            )
        )
        await store.load()
        let initialCount = store.cards.count
        guard let firstCard = store.cards.first else {
            XCTFail("Expected preview review cards")
            return
        }

        let submitted = await store.submit(cardID: firstCard.id, grade: .good)
        XCTAssertTrue(submitted)
        XCTAssertEqual(store.cards.count, initialCount - 1)

        store.restoreCard(firstCard, at: 0)
        XCTAssertEqual(store.cards.count, initialCount)
        XCTAssertEqual(store.cards.first, firstCard)
    }

    func testDefaultDestinationMapsToAppDestination() {
        XCTAssertEqual(
            MacPreferencesStore.DefaultDestination.today.destination,
            .today
        )
        XCTAssertEqual(
            MacPreferencesStore.DefaultDestination.vocabulary.destination,
            .vocabulary
        )
        XCTAssertEqual(
            MacPreferencesStore.DefaultDestination.review.destination,
            .review
        )
        XCTAssertEqual(
            MacPreferencesStore.DefaultDestination.practice.destination,
            .practice
        )
    }

    func testAllDestinationsHaveDisplayMetadata() {
        for destination in MacDestination.allCases {
            XCTAssertFalse(destination.title.isEmpty)
            XCTAssertFalse(destination.systemImage.isEmpty)
        }
    }

    @MainActor
    func testActivityLedgerTracksFavoritesNotesAndStreaks() {
        let persistence = InMemoryMacActivityLedgerPersistence()
        let ledger = MacActivityLedger(persistence: persistence)

        XCTAssertTrue(ledger.toggleFavorite("concise"))
        XCTAssertTrue(ledger.isFavorite("concise"))

        ledger.setPersonalNote("Remember for IELTS writing", for: "concise")
        XCTAssertEqual(
            ledger.personalNote(for: "concise"),
            "Remember for IELTS writing"
        )

        ledger.recordReview(cardID: "concise", grade: .good)
        ledger.recordPractice(
            activityKind: .multipleChoice,
            questionCount: 4,
            correctCount: 3
        )

        XCTAssertEqual(ledger.completedReviewsToday(), 1)
        XCTAssertEqual(ledger.completedActivitiesToday(), 5)
        XCTAssertEqual(ledger.streakDays(), 1)

        let insights = ledger.insightsSnapshot(difficultWordCount: 2)
        XCTAssertEqual(insights.reviewedThisWeek, 1)
        XCTAssertEqual(insights.practicedThisWeek, 4)
        XCTAssertEqual(insights.difficultWordCount, 2)
        XCTAssertEqual(insights.dailyMetrics.count, 7)
    }

    @MainActor
    func testDynamicPracticeGenerationUsesVocabularyItems() {
        let generated = MacPracticeQuestion.generate(
            for: .multipleChoice,
            from: MacVocabularyItem.previewItems,
            maxCount: 4
        )

        XCTAssertEqual(generated.count, 4)
        for question in generated {
            XCTAssertTrue(question.options.contains(question.correctAnswer))
        }
    }

    func testImportParserClassifiesNewAndDuplicateWords() {
        let input = """
        word,meaning
        concise,already saved
        meticulous,very careful
        高效,efficient
        """
        let candidates = MacImportParser.extractCandidates(
            from: input,
            existingItems: MacVocabularyItem.previewItems
        )

        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(
            candidates.first(where: { $0.id == "concise" })?.status,
            .duplicate
        )
        XCTAssertEqual(
            candidates.first(where: { $0.id == "meticulous" })?.status,
            .new
        )
        XCTAssertEqual(
            candidates.first(where: { $0.id == "高效" })?.language,
            .chinese
        )
    }

    func testSQLiteDatabaseUpsertsAndSearchesWithFTS5() {
        let database = MacSQLiteVocabularyDatabase(inMemory: true)
        database.upsertItems(MacVocabularyItem.previewItems)

        let all = database.fetchAllItems()
        XCTAssertEqual(all.count, MacVocabularyItem.previewItems.count)

        let ftsMatches = database.searchItems(query: "recover")
        XCTAssertEqual(ftsMatches.first?.id, "resilient")

        database.deleteItem(id: "resilient")
        XCTAssertFalse(
            database.fetchAllItems().contains(where: { $0.id == "resilient" })
        )
    }

    func testClientPromptsGenerateChineseConversationPromptWithVoices() {
        let prompt = ClientPrompts.conversation(
            index: ["朋友", "咖啡"],
            selectedWord: "朋友",
            format: "conversation",
            language: .chinese,
            availableVoices: [("edge-tts/zh-CN-XiaoxiaoNeural", "Xiaoxiao")],
            autoSelectVoices: true
        )

        XCTAssertTrue(prompt.contains("Chinese (Hán ngữ giao tiếp)"))
        XCTAssertTrue(prompt.contains("\"pinyin\""))
        XCTAssertTrue(prompt.contains("edge-tts/zh-CN-XiaoxiaoNeural"))
        XCTAssertFalse(prompt.contains("everyday English listening passage"))
    }

    func testClientPromptsGenerateEnglishConversationPromptByDefault() {
        let prompt = ClientPrompts.conversation(
            index: ["mitigate"],
            selectedWord: nil,
            format: "auto"
        )

        XCTAssertTrue(prompt.contains("everyday English listening passage"))
        XCTAssertFalse(prompt.contains("CRITICAL 3-PART FORMAT RULE PER LINE"))
    }

    func testAssistantServiceVocabularyIndexFiltersByLanguageAndPriority() throws {
        let json = """
        [
          {"slug": "mitigate", "word": "mitigate", "language": "en", "level": "new"},
          {"slug": "zh-1", "word": "谢谢", "language": "zh-CN", "level": "mastered"},
          {"slug": "zh-2", "word": "朋友", "language": "zh-CN", "level": "learning"},
          {"slug": "zh-3", "word": "你好", "language": "zh-CN", "level": "new"}
        ]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([Card].self, from: json)

        let chinese = AssistantService.vocabularyIndex(from: cards, language: .chinese)
        let english = AssistantService.vocabularyIndex(from: cards, language: .english)

        XCTAssertEqual(chinese, ["你好", "朋友", "谢谢"])
        XCTAssertEqual(english, ["mitigate"])
    }
}
