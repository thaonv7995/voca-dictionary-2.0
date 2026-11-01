# Voca for macOS — Architecture

> Technical architecture, module boundaries, state ownership, platform integration, migration strategy, and engineering standards for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Software Architecture Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Current Apple project:** `ios/project.yml`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca for macOS should be built.

It covers:

- Architecture goals.
- Repository and project organization.
- Native target strategy.
- Shared iOS and macOS code.
- Module and feature boundaries.
- Dependency direction.
- State ownership.
- Navigation and window architecture.
- Networking and authentication.
- Persistence and synchronization interfaces.
- Audio, AI, OCR, widgets, App Intents, and system integrations.
- AppKit interoperability.
- Security boundaries.
- Testing seams.
- Migration from the current iOS project.
- Build configurations and release boundaries.

This document does not define final visual styling or the detailed behavior of every feature.

---

## 2. Current repository assessment

The existing repository contains:

```text
voca-dictionary/
├── backend/
├── docs/
├── ios/
├── web/
└── scripts/
```

The Apple client currently lives in:

```text
ios/
├── Shared/
├── Voca/
├── VocaWidget/
├── VocaUITests/
├── Voca.xcodeproj/
└── project.yml
```

The current XcodeGen project defines:

- `Voca`, an iOS application.
- `VocaWidgetExtension`, an iOS WidgetKit extension.
- `VocaUITests`, an iOS UI test bundle.

It currently targets iOS only.

### 2.1 Current application shell

The current iOS application uses:

- SwiftUI application lifecycle.
- Observation-based stores.
- An `AuthStore` environment dependency.
- An `AppRouter` environment dependency.
- A root authentication phase switch.
- URL routing for widget and speech actions.

Current application flow:

```text
VocaApp
└── RootView
    ├── Loading
    ├── Login
    └── Home
```

### 2.2 Existing reusable core

The following areas are strong candidates for shared Apple-platform code:

```text
Core/
├── Audio/
│   ├── AudioPlayer.swift
│   └── TTSService.swift
├── Auth/
│   ├── AuthStore.swift
│   └── KeychainStore.swift
├── Cache/
│   └── AppCache.swift
├── Models/
│   ├── Card.swift
│   ├── User.swift
│   ├── StudyModels.swift
│   ├── PracticeModels.swift
│   ├── ConversationModels.swift
│   ├── ArticleSpeakingModels.swift
│   └── SettingsModels.swift
├── Networking/
│   ├── ApiClient.swift
│   ├── ApiError.swift
│   ├── AppConfig.swift
│   ├── Envelope.swift
│   └── TokenManager.swift
└── Services/
    ├── CardsService.swift
    ├── StudyService.swift
    ├── AssistantService.swift
    ├── SettingsService.swift
    └── ClientPrompts.swift
```

### 2.3 Existing feature areas

The current iOS client already separates several features:

```text
Features/
├── Assistant/
├── Auth/
├── Dictionary/
├── Home/
├── Settings/
├── Study/
└── Today/
```

These feature folders provide a useful inventory, but their views and navigation should not be copied directly into the macOS application.

### 2.4 Architecture risks in the current structure

Before reuse, the codebase must be checked for:

- UIKit-only imports.
- iOS-only APIs.
- Device-specific URL assumptions.
- Shared services that directly create UI.
- Global singleton state.
- Main-actor networking work.
- Models coupled to views.
- Direct `UserDefaults` usage.
- Keychain access-group assumptions.
- Widget App Group assumptions.
- Services that instantiate their own dependencies internally.
- Hard-coded production or simulator configuration.

The migration should preserve current iOS behavior while moving reusable code behind explicit interfaces.

---

## 3. Architecture goals

### ARC-GOAL-001 — Build a native macOS product

The macOS application must use SwiftUI and macOS interaction patterns. Shared code must not force iOS navigation or layout into the Mac target.

### ARC-GOAL-002 — Share domain behavior, not entire screens

The two applications should share:

- Models.
- API contracts.
- Authentication behavior.
- FSRS and study behavior.
- Services.
- Persistence interfaces.
- Synchronization behavior.
- App Intent domain actions.

They should generally not share:

- Root navigation.
- Toolbars.
- Tables and inspectors.
- Window management.
- Menu commands.
- Platform-specific settings presentation.

### ARC-GOAL-003 — Make offline support an architectural capability

Offline behavior must be implemented through repositories and synchronization services rather than added independently to individual views.

### ARC-GOAL-004 — Keep feature state testable

Feature logic should be testable without launching a SwiftUI scene, making a real network request, opening Keychain, or invoking macOS UI.

### ARC-GOAL-005 — Centralize system integration

Quick Lookup, menu bar, Spotlight, widgets, App Intents, notifications, and the main application must use shared domain operations.

### ARC-GOAL-006 — Protect the existing iOS application

Migration must be incremental. The iOS target should remain buildable and releasable during macOS development.

### ARC-GOAL-007 — Avoid premature module fragmentation

Logical boundaries should be clear from the beginning, but the project should not create dozens of packages before build-time or ownership needs justify them.

---

## 4. Architectural style

The recommended architecture combines:

- Feature-oriented organization.
- Layered dependency direction.
- Protocol-based infrastructure boundaries.
- Observation-based presentation state.
- Repository-based data access.
- Actor-isolated mutable services.
- Typed routing.
- Dependency injection through a composed application environment.

High-level layers:

```text
┌───────────────────────────────────────────────────────────────┐
│ Presentation                                                  │
│ macOS scenes, views, commands, inspectors, feature state      │
├───────────────────────────────────────────────────────────────┤
│ Application                                                   │
│ use cases, orchestration, routing, sync coordination          │
├───────────────────────────────────────────────────────────────┤
│ Domain                                                        │
│ entities, value types, rules, repository interfaces           │
├───────────────────────────────────────────────────────────────┤
│ Infrastructure                                                │
│ API, database, Keychain, audio, Vision, Spotlight, filesystem │
└───────────────────────────────────────────────────────────────┘
```

Dependency direction:

```text
Presentation → Application → Domain
Infrastructure ─────────────→ Domain
Application uses Infrastructure through Domain protocols
```

The Domain layer must not import:

- SwiftUI.
- AppKit.
- UIKit.
- WidgetKit.
- Vision.
- Core Spotlight.

---

## 5. Proposed repository direction

### 5.1 Target structure

The long-term structure should represent Apple platforms rather than keeping macOS subordinate to an `ios` folder.

```text
apple/
├── project.yml
├── Config/
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── Secrets.example.xcconfig
├── Packages/
│   └── VocaCore/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── VocaDomain/
│       │   ├── VocaNetworking/
│       │   ├── VocaPersistence/
│       │   ├── VocaServices/
│       │   └── VocaDesignSystem/
│       └── Tests/
├── iOS/
│   ├── App/
│   ├── Features/
│   ├── Resources/
│   └── SupportingFiles/
├── macOS/
│   ├── App/
│   ├── Features/
│   ├── Commands/
│   ├── MenuBar/
│   ├── QuickLookup/
│   ├── Integrations/
│   ├── Resources/
│   └── SupportingFiles/
├── Widgets/
│   ├── Shared/
│   ├── iOS/
│   └── macOS/
├── AppIntents/
├── Shared/
│   └── Generated/
└── Tests/
    ├── Integration/
    ├── iOSUITests/
    └── macOSUITests/
```

### 5.2 Incremental structure

The long-term move to `apple/` should not be the first code change.

The initial macOS prototype can be added under the existing project:

```text
ios/
├── Shared/
├── Voca/
├── VocaMac/
├── VocaWidget/
├── VocaMacTests/
├── VocaMacUITests/
└── project.yml
```

Recommended sequence:

1. Add explicit shared source groups.
2. Add `VocaMac` target.
3. Validate compilation and dependencies.
4. Extract reusable code from `Voca` gradually.
5. Establish shared tests.
6. Move the full Apple project to `apple/` only after paths stabilize.

This avoids combining a filesystem migration with the first macOS implementation.

---

## 6. Target topology

Proposed Xcode targets:

```text
Voca                 iOS application
VocaMac              macOS application
VocaWidget           iOS widget extension
VocaMacWidget        macOS widget extension
VocaCoreTests        shared unit tests
VocaTests            iOS tests
VocaMacTests         macOS tests
VocaUITests          iOS UI tests
VocaMacUITests       macOS UI tests
```

Potential later targets:

```text
VocaShareExtension
VocaServices
VocaQuickLookExtension
```

Extensions should be introduced only after confirming that App Intents or application Services cannot fulfill the requirement more simply.

### 6.1 Shared Swift package

A local Swift package is recommended after the first prototype proves the source boundaries.

Initial package products:

```text
VocaDomain
VocaNetworking
VocaServices
VocaPersistence
VocaDesignSystem
```

Avoid a single `VocaCore` module that eventually becomes a dependency container for every concern.

### 6.2 Module dependency graph

```text
VocaDomain
├── no app module dependencies
└── Foundation only where practical

VocaNetworking
├── VocaDomain
└── Foundation

VocaPersistence
├── VocaDomain
└── selected local database framework

VocaServices
├── VocaDomain
├── VocaNetworking
└── VocaPersistence abstractions

VocaDesignSystem
├── SwiftUI
└── no feature dependencies

VocaMac
├── VocaDomain
├── VocaServices
├── VocaPersistence
└── VocaDesignSystem

Voca
├── VocaDomain
├── VocaServices
├── VocaPersistence
└── VocaDesignSystem
```

Feature modules must not import each other casually. Cross-feature behavior should pass through application-level use cases or navigation intents.

---

## 7. Domain layer

The Domain layer defines product concepts independent of UI and infrastructure.

### 7.1 Core entities

Candidate entities:

```text
Account
User
DictionaryEntry
UserCard
CardContent
CardLanguage
Meaning
Example
Pronunciation
Tag
Topic
StudyState
ReviewEvent
ReviewGrade
ReviewSession
PracticeSession
AssistantConversation
SmartList
ImportCandidate
SyncOperation
```

### 7.2 Identifier types

Use semantic identifier wrappers instead of passing unrelated string identifiers everywhere.

Illustrative design:

```swift
struct UserCardID: Hashable, Codable, Sendable {
    let rawValue: String
}

struct ReviewSessionID: Hashable, Codable, Sendable {
    let rawValue: UUID
}
```

Benefits:

- Prevent accidental identifier mixups.
- Improve route safety.
- Improve repository signatures.
- Make test fixtures clearer.

### 7.3 Domain values

Use enums and value types for:

- Language.
- Learning level.
- Review grade.
- Sync status.
- Content source.
- Audio voice.
- Import status.
- Practice type.

Avoid UI-specific flags in core models.

### 7.4 Domain rules

Domain behavior includes:

- Whether a card is due.
- Whether an action can be queued offline.
- Duplicate matching.
- Language-specific validation.
- Review-grade semantics.
- Smart List predicates.
- Synchronization conflict classification.

The backend remains authoritative where server behavior defines the final schedule or permission. Local rules should mirror or prepare interactions without silently diverging from server behavior.

### 7.5 Sendable conformance

Domain models crossing actor boundaries should conform to `Sendable` where valid.

Mutable reference types should not be used as transport values between actors.

---

## 8. Application layer

The Application layer implements use cases.

Examples:

```text
SignIn
SignOut
BootstrapAccount
LoadToday
SearchVocabulary
SaveWord
UpdateUserCard
DeleteUserCards
StartReviewSession
SubmitReviewGrade
ResumeReviewSession
GeneratePractice
SendAssistantMessage
ImportVocabulary
SynchronizeAccount
IndexVocabularyInSpotlight
HandleDeepLink
```

### 8.1 Use-case properties

Each use case should:

- Have explicit input.
- Return explicit output.
- Use repository protocols.
- Be independent of SwiftUI.
- Be cancellable where appropriate.
- Define offline behavior.
- Map infrastructure errors into application errors.

### 8.2 Example use-case contract

```swift
protocol AddWordUseCase: Sendable {
    func execute(
        query: String,
        language: CardLanguage,
        source: WordCaptureSource
    ) async throws -> AddWordResult
}
```

The main app, Quick Lookup, menu bar, Service, and App Intent should call the same use case.

### 8.3 Application errors

Application-facing error categories:

```text
AuthenticationRequired
PermissionDenied
ValidationFailed
NetworkUnavailable
RemoteFailure
Conflict
NotFound
UnsupportedContent
StorageFailure
Cancelled
Unknown
```

Infrastructure-specific details should remain available for diagnostics without leaking directly into user-facing copy.

---

## 9. Repository layer

Repositories provide stable domain access independent of whether data comes from local storage, remote APIs, or synchronization.

### 9.1 Repository interfaces

Candidate protocols:

```swift
protocol VocabularyRepository: Sendable {
    func cards(matching query: VocabularyQuery) async throws -> [UserCard]
    func card(id: UserCardID) async throws -> UserCard?
    func save(_ command: SaveCardCommand) async throws -> UserCard
    func update(_ command: UpdateCardCommand) async throws -> UserCard
    func delete(ids: Set<UserCardID>) async throws
}

protocol ReviewRepository: Sendable {
    func dueCards(for request: DueCardsRequest) async throws -> [UserCard]
    func submit(_ event: ReviewEvent) async throws -> StudyState
}

protocol SettingsRepository: Sendable {
    func load() async throws -> UserSettings
    func update(_ settings: UserSettings) async throws -> UserSettings
}
```

### 9.2 Local-first composition

The preferred repository flow is:

```text
View
→ Feature State
→ Use Case
→ Repository
→ Local Store
→ Return local result
→ Sync remote changes
→ Update local store
→ Notify observers
```

Not every endpoint must become local-first immediately. Migration can proceed by feature:

1. Read-through cache.
2. Local vocabulary reads.
3. Queued writes.
4. Offline review.
5. Full incremental synchronization.

### 9.3 Repository ownership

Views must not instantiate:

- `ApiClient`.
- Database contexts.
- Keychain stores.
- URL sessions.

Feature state receives use cases or repositories from the application environment.

---

## 10. Dependency injection

### 10.1 Application environment

Compose dependencies once near the application root.

Illustrative structure:

```swift
@MainActor
@Observable
final class AppEnvironment {
    let auth: AuthSession
    let vocabulary: VocabularyRepository
    let reviews: ReviewRepository
    let settings: SettingsRepository
    let assistant: AssistantRepository
    let speech: SpeechService
    let sync: SyncCoordinator
    let router: AppRouter
}
```

The final implementation should avoid turning `AppEnvironment` into a service locator used everywhere.

Preferred injection levels:

- App and scene dependencies at the environment level.
- Feature-specific dependencies through feature initializers.
- Small view dependencies as values or closures.

### 10.2 Production composition

```text
Production App
├── URLSession API transport
├── Keychain credential store
├── Local database
├── Remote repositories
├── Synchronizing repositories
├── AVFoundation speech
├── Vision OCR
├── Core Spotlight index
└── User notification scheduler
```

### 10.3 Preview composition

SwiftUI previews use:

- In-memory repositories.
- Deterministic sample data.
- Stub speech service.
- Stub clock.
- No Keychain.
- No real network.

### 10.4 Test composition

Tests use:

- Recording repositories.
- Failure-injection stores.
- Deterministic scheduler or clock.
- Temporary database.
- Mock URL protocol for transport tests.

---

## 11. State ownership

### 11.1 Application state

Application-level state:

- Authentication session.
- Active account.
- Global connectivity.
- Synchronization status.
- User settings.
- Entitlements or feature capabilities.
- Pending external routes.

### 11.2 Window state

Each main window owns:

- Current route.
- Sidebar selection.
- Navigation path.
- Vocabulary search and filters.
- Selected cards.
- Inspector visibility.
- Layout mode.
- Window-specific sheets.

### 11.3 Feature state

Feature state owns:

- Current loading phase.
- Data required by the feature.
- User input.
- Selection within the feature.
- Feature errors.
- Active asynchronous tasks.

### 11.4 Entity state

Canonical entities should come from repositories or a local store, not be duplicated independently in each feature.

A feature may keep an editable draft, but it must distinguish:

```text
Persisted entity
Editable draft
Save operation
Conflict state
```

### 11.5 Observation

Use Observation for UI-facing state where available.

Rules:

- UI state mutation occurs on `MainActor`.
- Network and database work must not run synchronously on `MainActor`.
- Long-lived services should use actors when they own mutable concurrent state.
- Avoid publishing entire large collections for a one-row update if the persistence/query layer can provide narrower changes.

---

## 12. Navigation architecture

### 12.1 Typed routes

Routes follow the model defined in `macos-information-architecture.md`.

Required characteristics:

- Typed.
- Hashable.
- Codable where restoration is safe.
- Based on stable identifiers.
- Independent from views.

### 12.2 Router responsibilities

The application router:

- Parses external URLs.
- Resolves pending authenticated routes.
- Opens the appropriate scene.
- Selects canonical destinations.
- Handles unavailable entities.

It should not:

- Fetch all feature data itself.
- Own vocabulary entities.
- Play audio directly.
- Contain feature business logic.

The current `AppRouter` directly performs TTS for a URL route. During migration, this should become an application action handled through a use case or command dispatcher.

### 12.3 Scene coordinator

macOS requires scene-level operations:

- Open word window.
- Open review window.
- Open Settings.
- Activate main window.
- Open Quick Lookup.

Use a small platform-specific scene coordinator rather than spreading `NSApplication` and `NSWindow` calls through features.

### 12.4 Deep-link flow

```text
External URL
→ URL parser
→ Typed route
→ Authentication gate
→ Scene coordinator
→ Window router
→ Feature loads entity
```

---

## 13. Networking architecture

### 13.1 Existing client

The existing iOS `ApiClient`, `Envelope`, `ApiError`, `TokenManager`, and service types should be audited first.

The goal is to reuse verified behavior while separating:

- Transport.
- Authentication.
- Endpoint definitions.
- DTO decoding.
- Domain mapping.
- Retry policy.
- SSE streaming.

### 13.2 Transport protocol

```swift
protocol HTTPTransport: Sendable {
    func send<Response: Decodable & Sendable>(
        _ request: APIRequest<Response>
    ) async throws -> Response
}
```

Streaming should use a separate abstraction:

```swift
protocol EventStreamTransport: Sendable {
    func stream<Event: Decodable & Sendable>(
        _ request: EventStreamRequest<Event>
    ) -> AsyncThrowingStream<Event, Error>
}
```

### 13.3 Request pipeline

```text
Endpoint
→ Request construction
→ Authentication header
→ Transport
→ HTTP validation
→ Envelope decoding
→ DTO
→ Domain mapping
```

### 13.4 Token refresh

Refresh rotation must be serialized.

Required behavior:

1. Multiple requests receive an authentication failure.
2. Only one refresh request is started.
3. Concurrent callers await the same refresh result.
4. Tokens are updated atomically.
5. Eligible requests retry once.
6. Refresh failure transitions the session to signed out.

`TokenManager` is a candidate for actor isolation.

### 13.5 Retry policy

Automatic retry is allowed only when:

- The request is idempotent.
- A retry key or operation identifier prevents duplication.
- The failure is transient.

Do not blindly retry:

- Review submissions.
- Word creation.
- Destructive operations.
- AI generation that incurs cost.

### 13.6 Cancellation

Search, AI streams, imports, and OCR must support cancellation.

Feature state should cancel requests when:

- Query changes.
- Window closes.
- User explicitly cancels.
- A newer operation supersedes an older one.

### 13.7 Diagnostics

Network diagnostics may include:

- Endpoint category.
- Status code.
- Duration.
- Retry count.
- Request identifier.

They must not include:

- Authorization headers.
- Passwords.
- API keys.
- AI prompt content.
- Document content.

---

## 14. Authentication architecture

### 14.1 Session model

Recommended phases:

```swift
enum AuthPhase {
    case bootstrapping
    case signedOut
    case authenticating
    case signedIn(AccountSession)
    case requiresReauthentication(reason: ReauthenticationReason)
}
```

### 14.2 Credential storage

Keychain stores:

- Refresh token.
- Access token only if persistent access storage is required.
- Provider credentials.
- Per-server session identifiers.

Non-sensitive preferences may remain in application preferences.

### 14.3 Account isolation

Local data must be partitioned by stable account identity.

On account change:

- Cancel account-scoped tasks.
- Tear down account repositories.
- Clear account-bound views.
- Switch local data namespace.
- Rebuild Spotlight index where necessary.
- Update widgets and menu bar state.

### 14.4 Sign-out behavior

Sign out:

1. Attempts remote revocation.
2. Removes credentials.
3. Stops synchronization.
4. Removes private widget state.
5. Removes or protects Spotlight entries.
6. Dismisses authenticated windows.
7. Applies the documented local-cache retention policy.

---

## 15. Persistence architecture

### 15.1 Persistence goals

The local store supports:

- Fast vocabulary browsing.
- Offline read access.
- Due-card availability.
- Review event queue.
- Pending mutations.
- Smart Lists.
- Import progress.
- Sync cursors.
- Audio and resource metadata.

### 15.2 Technology decision

The implementation should evaluate:

- SwiftData.
- Direct SQLite through a maintained library.

Decision criteria:

- Deterministic migrations.
- Compound queries.
- Full-text search.
- Batch upsert performance.
- Transaction control.
- Testability.
- Extension access.
- Conflict and mutation metadata.

The repository interfaces must prevent the decision from leaking into feature views.

### 15.3 Proposed local records

```text
AccountRecord
DictionaryEntryRecord
UserCardRecord
MeaningRecord
ExampleRecord
TagRecord
UserCardTagRecord
StudyStateRecord
ReviewEventRecord
SmartListRecord
PendingMutationRecord
SyncCursorRecord
AssistantConversationRecord
AssistantMessageRecord
AudioCacheRecord
ImportJobRecord
```

### 15.4 Record metadata

Synchronizable records should include:

```text
accountID
remoteID
localRevision
remoteRevision or version
createdAt
updatedAt
deletedAt where tombstones are needed
syncState
lastSyncError
```

### 15.5 Transactions

Use transactions for operations that must remain consistent:

- Applying a remote sync page.
- Saving a review event and updating local study state.
- Importing confirmed cards.
- Updating card-tag relationships.
- Deleting an account partition.

### 15.6 Full-text search

Vocabulary search should support:

- Word.
- Normalized word.
- Meanings.
- Pinyin.
- User notes where privacy policy permits.

Search normalization must be language-aware and documented.

---

## 16. Synchronization architecture

### 16.1 Sync coordinator

The synchronization coordinator is account-scoped and actor-isolated.

Responsibilities:

- Trigger pull.
- Trigger push.
- Serialize conflicting jobs.
- Maintain sync state.
- Apply retry policy.
- Publish meaningful status.
- Avoid duplicate background work.

### 16.2 Sync phases

```text
Idle
Preparing
Pushing pending mutations
Pulling remote changes
Applying changes
Indexing integrations
Completed
Offline
Action required
```

### 16.3 Triggers

Synchronization may run:

- After authentication.
- When the application becomes active.
- After a local mutation.
- After network reconnection.
- On manual refresh.
- Before selected external actions where stale data is unsafe.

Avoid constant polling.

### 16.4 Mutation queue

Each queued mutation includes:

```text
operationID
accountID
entityType
entityID
operationType
payload
createdAt
attemptCount
nextAttemptAt
idempotencyKey
dependencyOperationID
lastError
```

### 16.5 Review events

Review events require special protection:

- Generate a stable client operation ID.
- Persist before remote submission.
- Submit idempotently where backend support exists.
- Never discard after a transient failure.
- Never submit twice after an ambiguous response without reconciliation.

If the backend does not support idempotency keys, add that backend capability before declaring robust offline review complete.

### 16.6 Conflict handling

Suggested initial policies:

- Shared dictionary content: server wins.
- User tags: merge where safe.
- Favorite state: latest accepted mutation wins.
- Personal notes: preserve both versions or prompt on conflict.
- FSRS state: server reconciliation based on review events.
- Deleted entries: use tombstones until all pending operations are reconciled.

Detailed policies belong in `macos-data-and-sync.md`.

---

## 17. Feature architecture

Each feature should have a predictable internal structure.

```text
FeatureName/
├── Domain/
├── Application/
├── Presentation/
│   ├── FeatureState.swift
│   ├── FeatureView.swift
│   ├── Components/
│   └── Accessibility/
├── Routing/
└── Tests/
```

Small features do not need empty folders. The principle is separation of responsibility, not directory ceremony.

### 17.1 Feature-state pattern

Feature state should expose:

- Renderable state.
- User actions.
- Asynchronous lifecycle.
- Recoverable errors.

Illustrative form:

```swift
@MainActor
@Observable
final class VocabularyFeature {
    enum Phase {
        case idle
        case loading
        case loaded
        case failed(AppError)
    }

    private(set) var phase: Phase = .idle
    private(set) var cards: [UserCard] = []
    var query = ""
    var selection: Set<UserCardID> = []

    func load() async
    func searchChanged()
    func deleteSelection() async
}
```

Avoid placing all application features in one global mutable store.

### 17.2 View responsibilities

Views should:

- Render state.
- Forward user intent.
- Own short-lived presentation state where appropriate.

Views should not:

- Build API requests.
- Decode DTOs.
- Access Keychain.
- Decide sync conflict policy.
- Manipulate database records directly.

---

## 18. macOS presentation architecture

### 18.1 Main workspace

Use:

- `NavigationSplitView`.
- Native toolbar items.
- `Table` for vocabulary.
- `inspector` where supported.
- Dedicated scenes for Settings and auxiliary windows.

AppKit bridges are permitted where native SwiftUI behavior is insufficient.

### 18.2 Window model

The application defines scene identifiers for:

```text
main-workspace
word-detail
review-session
quick-lookup
import
activity
settings
```

Scene creation must go through a platform coordinator so feature code remains testable.

### 18.3 Main commands

`Commands` definitions own:

- Application actions.
- Vocabulary actions.
- Study actions.
- View toggles.
- Window actions.

Commands dispatch typed actions to the active window context.

### 18.4 Active context

The application needs a lightweight active-context bridge to answer:

- Which window is active?
- Which destination is active?
- What vocabulary is selected?
- Is a review session active?
- Can pronunciation run?

This bridge should expose capabilities, not internal view references.

---

## 19. AppKit bridge boundaries

SwiftUI remains the default. AppKit bridges are isolated under:

```text
macOS/Platform/
```

Potential bridges:

- Global keyboard shortcut registration.
- Floating Quick Lookup panel.
- Window activation and placement.
- Spaces and multi-display behavior.
- Advanced table behavior if SwiftUI `Table` is insufficient.
- Selected-text Services.
- First-responder and focus restoration.
- Menu bar edge cases.

### 19.1 Bridge rules

An AppKit bridge must:

- Have a narrow protocol.
- Remain macOS-only.
- Execute UI work on `MainActor`.
- Avoid owning domain state.
- Be replaceable if SwiftUI later supports the behavior.
- Have at least a behavior-level integration test or manual test plan.

### 19.2 Prohibited usage

Do not:

- Pass `NSView` references into domain services.
- Make feature logic depend on `NSApplication.shared`.
- Spread `NSWindow` discovery code through SwiftUI views.
- Store canonical selection only in AppKit delegates.

---

## 20. Quick Lookup architecture

### 20.1 Components

```text
QuickLookupCoordinator
QuickLookupWindowController
QuickLookupFeature
LookupWordUseCase
AddWordUseCase
SpeechService
SceneCoordinator
```

### 20.2 Invocation flow

```text
Global shortcut
→ QuickLookupCoordinator
→ Present panel on active display
→ Focus query field
→ Search local repository
→ Optionally enrich remotely
→ Render result
```

### 20.3 State isolation

Quick Lookup has independent state from:

- Main Vocabulary search.
- Main window selection.
- Menu bar mini review.

It shares:

- Account session.
- Vocabulary repository.
- Lookup use case.
- Add Word use case.
- Speech service.

### 20.4 Global shortcut

The shortcut service exposes:

```swift
protocol GlobalShortcutService: Sendable {
    func register(_ shortcut: KeyboardShortcut) async throws
    func unregister() async
}
```

Shortcut conflicts must produce a recoverable Settings state.

---

## 21. Menu bar architecture

### 21.1 Menu bar state

The menu bar requires a small derived state:

- Authentication state.
- Due count.
- Word of the day.
- Sync warning.
- Mini-review state.

It must not instantiate a second independent repository graph.

### 21.2 Shared environment

The menu bar scene uses the application environment but creates its own presentation state.

### 21.3 Background behavior

Closing the main window must not terminate menu bar functionality when the user has enabled ambient mode.

Quitting the application must terminate:

- Global shortcut handling.
- Menu bar state.
- Sync tasks.
- Audio.
- Pending UI-only tasks.

### 21.4 Mini review

Mini Review uses the same:

- Due-card query.
- Review submission use case.
- Idempotency behavior.

It uses a separate compact presentation.

---

## 22. App Intents and Shortcuts architecture

### 22.1 Intent boundaries

App Intents must call application use cases rather than repositories or API transports directly.

Example:

```text
AddWordIntent
→ IntentDependencyContainer
→ AddWordUseCase
→ VocabularyRepository
```

### 22.2 Authentication

Intent operations that require an account should return:

- A useful authentication-required result.
- An option to open Voca when user interaction is required.

### 22.3 Intent-safe operations

Good background intent operations:

- Show due count.
- Look up a local word.
- Add a word if all input is available.
- Pronounce a supplied word.

Operations requiring richer UI:

- Resolve import conflicts.
- Configure a practice session.
- Review a long AI response.
- Reauthenticate.

These should open a canonical route.

### 22.4 Dependency initialization

Extensions and intents must use a lightweight dependency graph.

They should not initialize:

- Main-window navigation.
- Full analytics.
- All feature states.
- Heavy OCR or AI services unless invoked.

---

## 23. Spotlight architecture

### 23.1 Indexing service

```swift
protocol VocabularySearchIndex: Sendable {
    func index(_ cards: [UserCardSearchDocument]) async throws
    func remove(ids: [UserCardID]) async throws
    func removeAll(for accountID: AccountID) async throws
}
```

### 23.2 Index source

The local database is the source used to build the Spotlight index.

Do not depend on a full remote fetch during system indexing.

### 23.3 Index update triggers

- Initial synchronization.
- Card add.
- Card update.
- Card delete.
- Account change.
- Reindex command after schema change.

### 23.4 Privacy

The index should contain only:

- Word.
- Concise meaning.
- Language.
- Deep-link identifier.

User notes and private AI conversations should not be indexed by default.

---

## 24. Widget architecture

### 24.1 Shared snapshot

Widgets should read a purpose-built shared snapshot rather than the main application database directly during the first implementation.

Example snapshot:

```text
accountDisplayName
dueCount
dailyGoal
dailyCompleted
streak
wordOfTheDay
updatedAt
privacyMode
```

### 24.2 Shared container

Use an App Group with distinct versioned keys or files.

The current `WidgetSharedStore` should be evaluated for:

- Platform neutrality.
- Atomic writes.
- Schema versioning.
- Account isolation.
- Signed-out cleanup.

### 24.3 Interactive actions

Widget actions use App Intents.

Opening the application uses canonical routes.

---

## 25. Audio and speech architecture

### 25.1 Service interface

```swift
protocol SpeechService: Sendable {
    func speak(_ request: SpeechRequest) async throws
    func stop() async
    func availableVoices(for language: CardLanguage) async -> [SpeechVoice]
}
```

### 25.2 Playback coordinator

Only one application-level playback coordinator should own active speech playback.

This prevents:

- Main app and menu bar playing over each other.
- Review auto-play conflicting with a manual word preview.
- Stale playback continuing after sign out.

### 25.3 Audio source priority

Suggested order:

1. Valid cached audio.
2. Backend-provided audio.
3. Configured TTS provider.
4. Supported system speech fallback, if product-approved.

### 25.4 Current code migration

`AudioPlayer` and `TTSService` should be audited for:

- AVFoundation portability to macOS.
- Main-actor assumptions.
- Direct service construction.
- Cancellation.
- Audio-session APIs that exist only on iOS.

---

## 26. AI and streaming architecture

### 26.1 Assistant service

The existing `AssistantService` is a candidate for shared code after verifying:

- SSE parsing.
- Cancellation.
- Request context.
- Error mapping.
- Main-actor isolation.

### 26.2 Conversation model

Separate:

- Conversation domain.
- Stored messages.
- Streaming draft message.
- Prompt context.
- Provider configuration.

### 26.3 Streaming state

```text
Idle
Preparing
Streaming
Cancelling
Completed
Failed
```

Partial streaming content should not be persisted as a completed assistant message until the completion policy allows it.

### 26.4 Context assembly

Context assembly is an application service:

```text
Selected word IDs
Smart List ID
Imported text reference
Language
Level
Practice mode
→ AssistantContextBuilder
→ Validated request context
```

Views should not concatenate prompts directly.

### 26.5 Privacy boundary

The context builder must expose a preview or summary for document-based operations.

Passive app state must not trigger AI transmission.

---

## 27. OCR and import architecture

### 27.1 Import pipeline

```text
Input
→ Type detection
→ Security-scoped access
→ Extraction
→ Text normalization
→ Language detection
→ Candidate generation
→ Duplicate lookup
→ User review
→ Card creation
→ Completion report
```

### 27.2 Import-job model

```text
ImportJob
├── source metadata
├── phase
├── progress
├── extracted text reference
├── candidates
├── validation errors
└── completion result
```

### 27.3 File access

For sandboxed macOS:

- Use open panels.
- Use security-scoped URLs when required.
- Do not retain file access longer than needed.
- Persist bookmarks only for features that genuinely need future access.

### 27.4 OCR service

```swift
protocol TextRecognitionService: Sendable {
    func recognizeText(
        from source: RecognitionSource,
        languages: [RecognitionLanguage]
    ) -> AsyncThrowingStream<RecognitionProgress, Error>
}
```

Vision implementation remains infrastructure-specific.

### 27.5 Import cancellation

Cancellation must:

- Stop extraction where supported.
- Release file access.
- Remove unneeded temporary files.
- Preserve confirmed vocabulary already committed.

---

## 28. Notifications architecture

### 28.1 Notification scheduler

```swift
protocol ReviewNotificationScheduler: Sendable {
    func requestAuthorization() async throws -> NotificationPermission
    func updateSchedule(_ schedule: ReviewReminderSchedule) async throws
    func removePendingReminders() async
}
```

### 28.2 Scheduling source

Notifications derive from:

- User reminder settings.
- Due-card summary.
- Daily completion state.

They must not schedule one notification per card.

### 28.3 Routing

Notification actions resolve through the canonical router:

```text
Review Now → /review
Open Word → /vocabulary/word/{id}
Sync Issue → /activity
```

---

## 29. Settings architecture

### 29.1 Settings categories

```text
Device settings
├── Window restoration
├── Menu bar visibility
├── Global shortcut
├── Launch at login
└── Local cache behavior

Account settings
├── Daily goal
├── Reminder preferences
├── Learning preferences
└── Language preferences

Secret settings
├── Provider API keys
└── Account credentials
```

### 29.2 Storage

- Device settings: application preferences.
- Account settings: backend plus local cache.
- Secrets: Keychain.

### 29.3 Draft and save behavior

Simple device settings may save immediately.

Remote settings should:

- Create an editable draft where multiple fields are related.
- Validate before submission.
- Preserve input on failure.
- Update the cached canonical settings after success.

---

## 30. Security architecture

### 30.1 Trust boundaries

```text
User interface
Local process
Keychain
Local database
App Group container
Backend
AI provider
Imported files
System indexes
```

Each boundary requires deliberate data minimization.

### 30.2 Secret handling

Secrets must not enter:

- Domain entities.
- Widgets.
- Spotlight.
- Logs.
- Analytics.
- Crash breadcrumbs.
- Clipboard.

### 30.3 Local database

The database should:

- Be account-partitioned.
- Use file protection available on macOS.
- Avoid storing raw credentials.
- Support complete account-data deletion.

Field-level encryption for personal notes should be evaluated in the dedicated security document.

### 30.4 Clipboard

Clipboard monitoring:

- Is disabled by default.
- Uses event-efficient observation.
- Processes local candidate detection first.
- Does not persist raw content.
- Does not invoke AI automatically.

### 30.5 Diagnostics

Diagnostics export uses an allowlist of fields rather than attempting to redact arbitrary object dumps.

---

## 31. Concurrency model

### 31.1 Main actor

The following are main-actor isolated:

- SwiftUI feature state.
- Routers.
- Scene coordination.
- Window and AppKit bridges.
- UI command context.

### 31.2 Actors

Candidates for actor isolation:

- Token refresh coordinator.
- Sync coordinator.
- Audio playback coordinator.
- Import-job coordinator.
- Spotlight index coordinator.
- Database writer where the persistence library requires serialization.

### 31.3 Structured concurrency

Use structured tasks for feature work.

Avoid detached tasks unless:

- Isolation requirements are understood.
- Cancellation ownership is explicit.
- Required values are Sendable.

### 31.4 Task ownership

Every long-running task must have an owner:

- Feature state.
- Account session.
- Window.
- Application service.

Owners cancel tasks when their lifecycle ends.

---

## 32. Logging and observability

### 32.1 Logging categories

```text
application
authentication
networking
database
synchronization
review
audio
assistant
import
quick-lookup
system-integration
```

### 32.2 Structured fields

Safe fields:

- Operation category.
- Duration.
- Status.
- Error category.
- Retry count.
- Entity type.
- Non-sensitive request ID.

Unsafe fields:

- Word notes.
- Imported text.
- AI prompt.
- Password.
- Tokens.
- API keys.
- Full server response bodies.

### 32.3 User-visible Activity

Activity is not a raw log viewer.

It displays:

- Pending changes.
- Failed sync operations.
- Import progress.
- Recoverable account issues.

---

## 33. Testing architecture

### 33.1 Domain tests

Cover:

- Duplicate matching.
- Language validation.
- Review event creation.
- Smart List predicates.
- Error mapping.
- Conflict classification.

### 33.2 Use-case tests

Cover:

- Add word.
- Delete selected words.
- Start and resume review.
- Submit grade.
- Offline queue behavior.
- AI context assembly.
- Import confirmation.

### 33.3 Repository tests

Cover:

- Local and remote mapping.
- Transactions.
- Query behavior.
- Pagination.
- Tombstones.
- Sync application.

### 33.4 Networking tests

Use deterministic transport stubs or URL protocol interception to test:

- Envelope decoding.
- Refresh rotation.
- Concurrent authentication failures.
- Retry eligibility.
- SSE event parsing.
- Cancellation.

### 33.5 Presentation tests

Feature-state tests cover:

- Loading transitions.
- Search cancellation.
- Selection preservation.
- Error recovery.
- Batch actions.

### 33.6 UI tests

macOS UI tests cover critical journeys:

- Sign in.
- Search vocabulary.
- Select a word.
- Play pronunciation.
- Start review.
- Reveal and grade.
- Open Settings.
- Invoke Quick Lookup.

### 33.7 Integration tests

Run selected tests against:

- A local backend.
- A temporary local database.
- Stubbed AI and TTS services.

Production-server UI tests should remain limited and isolated.

---

## 34. Build and configuration

### 34.1 Configurations

Recommended:

```text
Debug
Staging
Release
```

### 34.2 Configuration values

Configuration may include:

- Base URL.
- Logging level.
- Feature flags.
- AI defaults.
- App Group identifier.
- Keychain access group.
- URL scheme.

Secrets must not be committed in project files.

### 34.3 Bundle identifiers

Illustrative identifiers:

```text
site.thaonv.voca
site.thaonv.voca.widget
site.thaonv.voca.mac
site.thaonv.voca.mac.widget
site.thaonv.voca.mac.uitests
```

Final identifiers require signing and App Group review.

### 34.4 Feature flags

Early macOS features may use compile-time or locally configured flags:

```text
quickLookupEnabled
menuBarEnabled
offlineWritesEnabled
spotlightEnabled
clipboardAssistantEnabled
```

Flags should have:

- An owner.
- A default.
- A removal condition.
- No secret behavior.

---

## 35. Migration plan

## Phase 0 — Audit

Inspect:

- Existing core models.
- API client.
- Token manager.
- Keychain store.
- Services.
- Audio.
- Widget store.
- Feature-state patterns.
- iOS-only imports.

Deliverable:

```text
Reusable
Reusable after cleanup
iOS-only
Replace
Unknown
```

## Phase 1 — Define shared interfaces

Introduce:

- Domain identifiers.
- Repository protocols.
- Speech protocol.
- Credential-store protocol.
- HTTP transport protocol.
- Clock abstraction where scheduling behavior requires it.

Do not move directories yet.

## Phase 2 — macOS target shell

Add:

- `VocaMac` target.
- macOS app entry.
- Authentication shell.
- Main workspace.
- Sidebar.
- Empty Vocabulary feature.
- macOS tests.

Exit criterion:

- Both iOS and macOS targets build.

## Phase 3 — Networking reuse

Move or adapt:

- API client.
- Envelopes.
- Errors.
- Token refresh.
- App configuration.
- Cards service.

Exit criterion:

- Both applications authenticate and load vocabulary through shared networking code.

## Phase 4 — Shared domain and repositories

Introduce:

- Shared card models.
- Vocabulary repository.
- Review repository.
- Settings repository.
- Domain mapping.

Exit criterion:

- macOS Vocabulary table and word detail use shared domain operations.

## Phase 5 — Persistence

Add:

- Local database.
- Read-through cache.
- Local vocabulary query.
- Account partitioning.
- Migration tests.

Exit criterion:

- Previously synchronized vocabulary loads offline.

## Phase 6 — Reviews and sync

Add:

- Review-session use cases.
- Pending review queue.
- Sync coordinator.
- Activity state.

Exit criterion:

- Offline-safe review behavior passes idempotency tests.

## Phase 7 — macOS integrations

Add:

- Quick Lookup.
- Global shortcut.
- Menu bar.
- Spotlight.
- App Intents.
- Widgets.

Exit criterion:

- All integrations use shared use cases and canonical routes.

## Phase 8 — Repository relocation

After source boundaries stabilize:

- Move Apple code under `apple/`.
- Update scripts and documentation.
- Preserve history through Git moves.
- Regenerate project.
- Verify CI.

---

## 36. Initial prototype architecture

The first prototype should intentionally use fewer layers than the final offline system while preserving correct seams.

### Prototype components

```text
VocaMacApp
├── AppEnvironment
├── AuthSession
├── AppRouter
├── MainWorkspace
├── VocabularyFeature
├── VocabularyRepository
│   └── RemoteVocabularyRepository
├── CardsService
├── ApiClient
├── TokenManager
├── KeychainStore
└── SpeechService
```

### Prototype flow

```text
Launch
→ Bootstrap credentials
→ Sign in if needed
→ Main workspace
→ Load vocabulary
→ Search table
→ Select word
→ Inspector
→ Play pronunciation
```

### Prototype constraints

The prototype must not:

- Put API calls directly in views.
- Create a second authentication implementation.
- Copy all iOS views.
- Introduce offline writes before idempotency design.
- Build Quick Lookup before shared lookup and save use cases exist.

---

## 37. Architecture decision records required

The following decisions should receive ADR entries in `macos-decisions.md`:

1. Native SwiftUI rather than Electron or a permanent web view.
2. macOS-specific presentation with shared domain services.
3. Initial macOS target inside the current Apple project.
4. Eventual migration from `ios/` to `apple/`.
5. Local Swift package timing.
6. Persistence technology.
7. Minimum macOS deployment target.
8. Local-first repository strategy.
9. Review idempotency contract.
10. Quick Lookup window implementation.
11. Global shortcut technology.
12. Spotlight privacy policy.
13. Widget snapshot format.
14. AI conversation persistence.
15. App Group and Keychain access-group strategy.

---

## 38. Architecture validation checklist

### Shared code

- [ ] Shared models compile for iOS and macOS.
- [ ] Shared services contain no accidental UIKit or AppKit import.
- [ ] Platform resources are separated.
- [ ] Widget code uses a versioned shared contract.

### State

- [ ] Application, window, feature, and entity state have identified owners.
- [ ] Long-running tasks have cancellation owners.
- [ ] Main-actor work is limited to presentation state.

### Networking

- [ ] Token refresh is serialized.
- [ ] Streaming supports cancellation.
- [ ] Non-idempotent requests are not blindly retried.
- [ ] Sensitive headers are redacted.

### Persistence

- [ ] Records are partitioned by account.
- [ ] Migrations are tested.
- [ ] Batch upsert is transactional.
- [ ] Search is benchmarked.

### Synchronization

- [ ] Pending operations survive restart.
- [ ] Review submissions have stable operation IDs.
- [ ] Conflict policies are explicit.
- [ ] Sign out safely stops synchronization.

### macOS

- [ ] Window operations are behind a coordinator.
- [ ] AppKit bridges are isolated.
- [ ] Commands use active context.
- [ ] Quick Lookup does not duplicate repositories.
- [ ] Menu bar idle energy usage is measured.

### Security

- [ ] Secrets remain in Keychain.
- [ ] Widgets and Spotlight contain no secrets.
- [ ] Clipboard monitoring is opt-in.
- [ ] Diagnostics use an allowlist.

### Testing

- [ ] Use cases work with in-memory repositories.
- [ ] API decoding has fixtures.
- [ ] macOS critical paths have UI tests.
- [ ] Accessibility identifiers are stable.

---

## 39. Risks and mitigations

### Risk: Shared code remains coupled to iOS

Mitigation:

- Compile shared targets for both platforms early.
- Add platform-import checks.
- Move UI-independent behavior before feature views.

### Risk: AppEnvironment becomes a service locator

Mitigation:

- Inject feature dependencies through initializers.
- Keep environment use near scene boundaries.
- Avoid arbitrary environment lookup from domain code.

### Risk: Local-first architecture delays the first UI

Mitigation:

- Build remote-backed repositories first.
- Preserve repository interfaces.
- Add local persistence in a later milestone.

### Risk: Synchronization corrupts review state

Mitigation:

- Persist stable review event IDs.
- Require backend idempotency.
- Test ambiguous network failures.
- Make server reconciliation explicit.

### Risk: Too many modules slow development

Mitigation:

- Begin with logical source groups.
- Extract packages after dependency boundaries are proven.
- Measure build time before further splitting.

### Risk: macOS integrations create duplicate logic

Mitigation:

- Require all integrations to use shared application use cases.
- Prohibit direct API calls from widgets and intents.

### Risk: Relocating `ios/` creates unnecessary churn

Mitigation:

- Add the macOS prototype in place.
- Move to `apple/` only after source boundaries stabilize.

---

## 40. Definition of done

This architecture is considered implemented when:

- iOS and macOS applications build from the same generated project.
- Shared domain and networking code compile on both platforms.
- macOS has platform-specific presentation and navigation.
- Authentication and token refresh are shared and tested.
- Views access data through use cases or repositories.
- Local data is account-partitioned.
- Review events have safe synchronization semantics.
- Quick Lookup, menu bar, Spotlight, widgets, and App Intents use shared domain operations.
- Platform bridges are isolated.
- Critical use cases can be tested without UI or network access.
- Signing, entitlements, and extension boundaries are documented.
- The existing iOS application remains operational throughout migration.

---

## 41. Next document

The next document should be:

```text
docs/macos-design-system.md
```

It should define:

- Brand application.
- Semantic colors.
- Typography.
- Spacing and sizing.
- Window and column dimensions.
- Table density.
- Toolbar rules.
- Sidebar styling.
- Inspector patterns.
- Buttons and controls.
- Empty, loading, and error states.
- Light and Dark Mode.
- Accessibility.
- Motion.
- English and Chinese content presentation.
- Component inventory.
- Design tokens shared with iOS versus macOS-specific components.
