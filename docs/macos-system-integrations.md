# Voca for macOS — System Integrations

> Product, architecture, privacy, authentication, deep-linking, testing, and acceptance specification for integrating Voca with macOS system experiences.

## Document status

- **Status:** Draft
- **Document type:** Feature and Architecture Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Related Quick Lookup specification:** [`macos-quick-lookup.md`](macos-quick-lookup.md)
- **Related menu bar specification:** [`macos-menu-bar.md`](macos-menu-bar.md)
- **Primary requirement group:** `SYS-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca integrates with macOS beyond its main application windows.

It covers:

- App Intents.
- Shortcuts.
- App Entities.
- Spotlight.
- macOS Services.
- Widgets.
- Notifications.
- Deep links.
- Launch at login.
- Extension and process boundaries.
- Shared App Group snapshots.
- Authentication.
- Signed-out cleanup.
- Privacy.
- Accessibility.
- Performance.
- Testing.
- Acceptance criteria.

These integrations allow Voca to participate naturally in the user's daily Mac workflow without duplicating business logic across extensions and system surfaces.

---

## 2. Product intent

System integrations should make Voca available at the moment a learning need occurs.

Examples:

- Search a saved word from Spotlight.
- Add a selected word through Services.
- Ask Siri or Shortcuts how many cards are due.
- Start a review from a widget.
- Receive a useful review reminder.
- Run a Shortcut that looks up clipboard text.
- Open the exact Voca word from another application.

The integrations should:

- Be useful independently.
- Share canonical use cases.
- Respect authentication state.
- Minimize exposed data.
- Work from local data where possible.
- Route complex work into the full application.
- Remain consistent across iOS and macOS where they share an intent.

They should not:

- Reimplement networking independently.
- Initialize the entire main application for a simple due-count request.
- Expose personal notes through system search.
- upload clipboard content automatically.
- Pretend an action completed when it only opened the app.

---

## 3. Principles

### SYS-PRN-001 — One domain action, multiple surfaces

The main app, menu bar, widgets, Spotlight, Services, Shortcuts, and App Intents must call shared application use cases.

### SYS-PRN-002 — Prefer completion without opening the app

Simple actions should complete in place when:

- Required input is available.
- Authentication is valid.
- No conflict needs user judgment.
- The operation is safe in the current process.

### SYS-PRN-003 — Open the app for complex interaction

Open a canonical route when an action requires:

- Authentication.
- Conflict resolution.
- A long form.
- Multiple candidates.
- Document preview.
- Extended AI output.

### SYS-PRN-004 — Local data first

Due count, saved-word lookup, widget summaries, and Spotlight content should use local synchronized data where possible.

### SYS-PRN-005 — Private by default

System integrations should expose the minimum data necessary.

### SYS-PRN-006 — Signed-out cleanup is immediate

When the active account signs out, private widgets, Spotlight entries, snapshots, and pending route data must be cleared.

### SYS-PRN-007 — Deep links are typed and validated

All system surfaces route through one canonical route parser.

### SYS-PRN-008 — Extensions stay lightweight

Extensions must initialize only the dependencies required for the requested action.

---

## 4. Integration inventory

Planned integrations:

```text
App Intents
├── Add Word
├── Look Up Word
├── Pronounce Word
├── Show Due Count
├── Start Review
├── Review Five Cards
├── Explain Text
├── Generate Quiz
└── Open Today's Session

Spotlight
├── Saved vocabulary
├── Smart Lists where useful
└── Application shortcuts

macOS Services
├── Look Up in Voca
├── Add to Voca
├── Explain with Voca
└── Extract Vocabulary with Voca

Widgets
├── Due Count
├── Daily Goal
├── Word of the Day
├── Streak
├── Interactive Flashcard
└── Today Summary

Notifications
├── Review Reminder
├── Daily Goal Reminder
├── Sync Action Required
└── Long Operation Completed

Deep Links
├── Today
├── Vocabulary
├── Word Detail
├── Review
├── Practice
├── Assistant
├── Insights
└── Quick Lookup
```

---

## 5. Architecture overview

```text
System Surface
     │
     ▼
Intent / Extension Adapter
     │
     ▼
Shared Application Use Case
     │
     ├────────► Local Repository
     │
     ├────────► Authentication Session
     │
     ├────────► Mutation Queue
     │
     └────────► Remote Service when required
```

### 5.1 Adapter responsibilities

An integration adapter:

- Converts system input into domain input.
- Validates platform-provided values.
- Invokes one or more application use cases.
- Converts domain output into a system result.
- Opens a canonical route if interaction is required.

It does not:

- Build raw API requests.
- Decode backend envelopes.
- Manipulate database records directly.
- Read credentials directly.
- Create its own sync rules.

### 5.2 Dependency container

System integrations use a lightweight container:

```swift
struct SystemIntegrationDependencies {
    let accountSession: AccountSessionProvider
    let vocabulary: VocabularyRepository
    let review: ReviewRepository
    let lookupWord: LookupWordUseCase
    let addWord: AddWordUseCase
    let speech: SpeechService
    let routes: SystemRouteOpener
}
```

The final implementation may split containers by integration to reduce initialization cost.

---

## 6. App Intents

### 6.1 Purpose

App Intents expose useful Voca actions to:

- Shortcuts.
- Siri.
- Spotlight actions.
- Widgets.
- Other supported system experiences.

### 6.2 Intent design rules

Every intent should have:

- Clear verb-based title.
- Concise description.
- Localized parameters.
- Predictable output.
- Authentication behavior.
- Offline behavior.
- Privacy classification.
- Open-app policy.

### 6.3 Intent categories

#### Read-only

- Look Up Word.
- Show Due Count.
- Get Daily Goal.
- Pronounce Word.

#### Mutating

- Add Word.
- Favorite Word.
- Update Tag where later supported.

#### Session-opening

- Start Review.
- Review Five Cards.
- Open Today.
- Open Word Detail.

#### AI-backed

- Explain Text.
- Generate Quiz.
- Create Reading Practice.

AI-backed intents require explicit execution and connectivity.

---

## 7. App Entities

### 7.1 Vocabulary entity

Saved vocabulary should be represented as an App Entity where appropriate.

Conceptual model:

```swift
struct VocabularyEntity {
    let id: UserCardID
    let word: String
    let language: CardLanguage
    let conciseMeaning: String
    let pronunciation: String?
}
```

### 7.2 Entity identity

Use:

- Stable user-card ID.
- Account-bound lookup.

Do not use:

- Visible word text as the only ID.
- Email.
- Mutable slug without a migration strategy.

### 7.3 Entity display

English:

```text
concise
brief but comprehensive
```

Chinese:

```text
简洁
jiǎnjié · ngắn gọn, súc tích
```

### 7.4 Entity query

Entity queries should support:

- ID resolution.
- Suggested entities.
- Text search.
- Recently used entities where privacy settings permit.

### 7.5 Signed-out behavior

Entity resolution must not expose cached private vocabulary after sign out.

Return:

- Authentication-required response.
- No private result.

### 7.6 Deleted entity

If a referenced entity was deleted:

- Return unavailable.
- Do not substitute another word with similar text.

---

## 8. Intent: Look Up Word

### 8.1 Input

- Word or short phrase.
- Optional language override.

### 8.2 Output

- Canonical word.
- Language.
- Pronunciation or pinyin.
- Concise meaning.
- Saved state.
- Optional deep link.

### 8.3 Execution

```text
Validate input
→ Normalize
→ Search local vocabulary
→ Search cached dictionary
→ Use remote lookup if required and allowed
→ Return concise result
```

### 8.4 App opening

Do not open Voca if a concise result can be returned.

Open Quick Lookup or full detail when:

- Multiple candidates require selection.
- The user requests full detail.
- Authentication is required for remote lookup.

### 8.5 Privacy

The lookup input is not logged in ordinary analytics.

---

## 9. Intent: Add Word

### 9.1 Input

- Word.
- Optional language.
- Optional level.
- Optional tags.
- Optional note.

### 9.2 Behavior

```text
Validate
→ Detect duplicate
→ Resolve dictionary entry
→ Create stable operation ID
→ Persist local user intent
→ Synchronize
→ Return saved result
```

### 9.3 Duplicate

If already saved:

- Return existing entity.
- Report Already in Vocabulary.
- Do not create a duplicate.

### 9.4 Candidate ambiguity

If multiple dictionary entries match:

- Open Voca or Quick Lookup for selection.
- Do not choose silently.

### 9.5 Offline

If enough local content is available:

- Save locally.
- Return Waiting to Sync.

Otherwise:

- Return connectivity-required result.
- Preserve supplied input only through an explicit app route.

### 9.6 Security

API keys and account credentials are never intent parameters.

---

## 10. Intent: Pronounce Word

### 10.1 Input

- Word or Vocabulary Entity.
- Optional language.
- Optional voice.

### 10.2 Behavior

Audio priority:

```text
Cached audio
→ configured Voca TTS
→ approved system speech fallback
```

### 10.3 Output

Return:

- Played successfully.
- Audio unavailable.
- Authentication or connectivity required.

### 10.4 App opening

Do not open the app for ordinary successful pronunciation.

### 10.5 Playback coordination

Intent pronunciation uses the shared playback coordinator and stops other Voca speech where appropriate.

---

## 11. Intent: Show Due Count

### 11.1 Input

Optional:

- Language.

### 11.2 Output

- Total due count.
- English count.
- Chinese count.
- Last-updated time where useful.

### 11.3 Data source

Use local synchronized study state.

Do not block on remote synchronization unless the caller explicitly requests refresh and the platform execution budget permits it.

### 11.4 Stale data

If stale:

- Return count with updated time.
- Avoid claiming the count is live.

### 11.5 Signed out

Return Sign in to view due cards.

---

## 12. Intent: Start Review

### 12.1 Input

Optional:

- Language.
- Maximum card count.
- Collection.

### 12.2 Behavior

Because full review is interactive:

- Open the Review route.
- Apply supplied configuration.
- Resume an active compatible session where appropriate.

### 12.3 Result

The intent reports:

- Review opened.
- Existing session resumed.
- Authentication required.
- No cards due.

### 12.4 No cards due

Do not open an empty Review window unnecessarily.

Return:

```text
No cards are currently due.
```

Optionally offer Practice.

---

## 13. Intent: Review Five Cards

### 13.1 Behavior

Potential execution:

- Open Mini Review through the menu bar.
- Open a compact Review window.
- Open full Review with a five-card limit.

Recommended first implementation:

- Open full Review with a five-card limit unless App Intent interactive execution is proven reliable for the desired UI.

### 13.2 Active session

If a full active session exists:

- Resume it.
- Do not create a conflicting session.

### 13.3 Zero due

Return:

```text
No cards are due.
```

---

## 14. Intent: Explain Text

### 14.1 Input

- Text.
- Optional language.
- Optional explanation level.

### 14.2 Limits

Apply an explicit maximum input size.

Long content routes to the main app's document-analysis workflow.

### 14.3 AI boundary

Before execution, the system action must make clear that content will be sent to the configured AI provider.

### 14.4 Output

For short text:

- Concise explanation.

For long or ambiguous text:

- Open Assistant with context.

### 14.5 Offline

Return that AI explanation requires connectivity unless a local model is later supported.

---

## 15. Intent: Generate Quiz

### 15.1 Input

- Vocabulary entities or Smart List.
- Number of questions.
- Difficulty.
- Language.

### 15.2 Behavior

Because quiz output is interactive:

- Open configured Practice route.
- Generate after app activation or within supported intent behavior.

### 15.3 Validation

Require:

- At least the minimum vocabulary count.
- Accessible selected entities.
- Valid account.

### 15.4 Privacy

Only selected vocabulary is included.

Personal notes are excluded unless explicitly requested.

---

## 16. Shortcuts

### 16.1 Product goal

Shortcuts should let users compose Voca into personal workflows.

Examples:

```text
Get clipboard
→ Look Up Word in Voca
→ Choose from result
→ Add Word to Voca

Every weekday at 08:00
→ Show Due Count
→ If count > 0, Open Today's Session

Select text
→ Explain with Voca
→ Save explanation to Notes
```

### 16.2 Shortcut action design

Actions should:

- Accept structured inputs.
- Return useful structured outputs.
- Avoid requiring the app for simple data retrieval.
- Produce actionable errors.

### 16.3 Suggested shortcuts

Voca may publish suggested shortcuts:

- Add Clipboard Word.
- Review Five Cards.
- Start Morning Review.
- Pronounce Clipboard Text.
- Explain Selected Text.

### 16.4 Automation safety

Mutating shortcuts must remain deliberate.

Avoid suggested automations that:

- Save all clipboard changes.
- Upload selected text without user awareness.
- Generate costly AI content repeatedly.

### 16.5 Parameters

Use clear language:

```text
Word
Language
Vocabulary List
Question Count
Difficulty
```

Avoid exposing backend terminology.

---

## 17. Spotlight

### 17.1 Indexed content

Initial:

- Saved vocabulary cards.

Potential later:

- Smart Lists.
- Voca destinations.
- Recent practice sessions.

### 17.2 Vocabulary Spotlight document

Fields:

- Stable searchable identity.
- Word or Hanzi.
- Concise meaning.
- Language.
- Pronunciation or pinyin where useful.
- Deep link.
- Voca icon.
- Updated timestamp.

### 17.3 Excluded content

Do not index by default:

- Personal notes.
- Review history.
- AI conversations.
- Provider configuration.
- Tags that may reveal private projects.
- Imported document text.

### 17.4 Search keywords

Potential:

- Canonical word.
- Normalized word.
- Pinyin.
- Concise meaning.

Do not overpopulate keywords with every example sentence.

### 17.5 Result action

Default:

```text
Spotlight result
→ Activate Voca
→ Open exact word detail
```

### 17.6 Index update

Trigger after committed local changes:

- Initial sync.
- Add.
- Relevant update.
- Restore.
- Delete.

### 17.7 Index deletion

Remove when:

- User card is deleted.
- Account signs out.
- User disables Spotlight integration.
- Local account data is removed.

### 17.8 Reindex

Settings or diagnostics may provide:

```text
Rebuild Spotlight Index
```

Reindexing:

- Uses local data.
- Runs in background.
- Does not block Vocabulary.

### 17.9 Privacy preference

Setting:

```text
Show saved vocabulary in Spotlight
```

Product decision required for the default.

Recommended:

- Explain during integration onboarding.
- Respect enterprise or privacy-sensitive use cases.

---

## 18. Spotlight indexing architecture

### 18.1 Service

```swift
protocol VocabularySearchIndex: Sendable {
    func index(_ documents: [VocabularySearchDocument]) async throws
    func remove(ids: [UserCardID]) async throws
    func removeAll(for accountID: AccountID) async throws
    func rebuild(for accountID: AccountID) async throws
}
```

### 18.2 Source

Committed local records are the source.

### 18.3 Queueing

Index updates use a separate derived-data queue.

Spotlight failure must not roll back domain persistence.

### 18.4 Batch behavior

Large initial indexes:

- Process in batches.
- Support cancellation.
- Store progress if necessary.
- Avoid blocking the main actor.

### 18.5 Account identity

Search identifiers must locate data only within the active authorized account.

---

## 19. macOS Services

### 19.1 Purpose

Services let users operate on selected text in compatible macOS applications.

### 19.2 Initial Services

```text
Look Up in Voca
Add to Voca
Explain with Voca
Extract Vocabulary with Voca
```

### 19.3 Look Up in Voca

Input:

- Short selected text.

Behavior:

- Open Quick Lookup.
- Prefill selection.
- Start lookup.

Saving remains explicit.

### 19.4 Add to Voca

Input:

- Short selected text.

Behavior:

- Open Quick Lookup in add-ready state.
- Detect language.
- Resolve duplicates.
- Require confirmation.

Do not silently create a card from an arbitrary selection.

### 19.5 Explain with Voca

Input:

- Word, sentence, or short passage.

Behavior:

- Open Assistant with the selected text as visible context.
- Require explicit AI action if opening alone would otherwise upload content.

Preferred privacy behavior:

```text
Open context preview
→ user confirms Explain
→ content is transmitted
```

### 19.6 Extract Vocabulary with Voca

Input:

- Passage.

Behavior:

- Open import and extraction preview.
- Show candidates.
- Require selection before saving.

### 19.7 Input validation

Reject or reroute:

- Empty text.
- Extremely large text.
- Binary data.
- Unsupported content.

### 19.8 Service availability

Services may need to appear only where relevant data types are selected.

### 19.9 Authentication

If signed out:

- Open sign in.
- Preserve selected text only as long as needed and under explicit privacy policy.

---

## 20. Services architecture

### 20.1 Preferred implementation order

Evaluate:

1. App Intents exposed through system experiences.
2. Native application Services.
3. Share Extension only where required.

Choose the simplest supported mechanism that provides reliable selected-text behavior.

### 20.2 Adapter

The Services adapter:

- Receives pasteboard data.
- Validates supported text.
- Creates a typed integration request.
- Opens the appropriate Voca route.

### 20.3 No direct network

The adapter must not send selected text directly to a backend.

### 20.4 Memory lifetime

Selected text:

- Exists only for the active flow.
- Is not logged.
- Is not written to general clipboard history.
- Is discarded after cancellation.

---

## 21. Widgets

### 21.1 Widget families

Candidate families:

#### Small

- Due Count.
- Word of the Day.
- Streak.

#### Medium

- Daily Goal.
- Word of the Day with meaning.
- Compact flashcard.

#### Large

- Today Summary.
- Due count by language.
- Goal.
- Recent vocabulary.
- Start Review.

### 21.2 Initial release recommendation

Start with:

- Small Due Count.
- Medium Word of the Day.
- Medium Today Summary.

Add interactive flashcards after App Intent review behavior is proven.

### 21.3 Widget data

Widgets read a versioned App Group snapshot.

They do not:

- Open the full local database.
- Read Keychain credentials.
- Make arbitrary authenticated network calls.

### 21.4 Snapshot fields

```text
schemaVersion
isSignedIn
privacyMode
dueCount
englishDueCount
chineseDueCount
dailyGoalValue
dailyGoalTarget
streak
wordOfTheDay
updatedAt
```

### 21.5 Refresh

Update snapshot after:

- Sign in.
- Sync.
- Add Word.
- Review Grade.
- Goal update.
- Local day change.
- Sign out.

### 21.6 Stale data

Widget may display:

```text
Updated 2 hours ago
```

when relevant.

It must not imply live data if the snapshot is stale.

### 21.7 Signed-out state

Show:

- Open Voca to Sign In.

Clear:

- Word content.
- Counts.
- User progress.

---

## 22. Due Count widget

### 22.1 Content

- Due count.
- Short action label.

Example:

```text
24 due
Start Review
```

### 22.2 Tap behavior

```text
Open /review
```

### 22.3 No due cards

```text
Caught up
Next review tomorrow
```

where next due data is available.

### 22.4 Privacy

No vocabulary text is required.

---

## 23. Word of the Day widget

### 23.1 Content

English:

- Word.
- Pronunciation.
- Concise meaning.

Chinese:

- Hanzi.
- Pinyin.
- Vietnamese meaning.

### 23.2 Tap behavior

```text
Open exact word detail
```

### 23.3 Audio

An interactive pronunciation action may use App Intent if reliable.

Otherwise:

- Open word detail.

### 23.4 Privacy

Setting:

```text
Show vocabulary on widgets
```

When disabled:

- Replace with due or goal summary.

---

## 24. Today Summary widget

### 24.1 Content

- Due count.
- Daily-goal progress.
- Streak.
- Primary action.

### 24.2 Action

Priority:

```text
Resume active review
→ Start Review
→ Open Today
```

### 24.3 Consistency

The widget's primary action should match the Today dashboard's current high-level state where possible.

---

## 25. Interactive flashcard widget

### 25.1 Scope

Potential later feature:

- Show prompt.
- Reveal.
- Play pronunciation.
- Record a grade.

### 25.2 Risk

FSRS grading requires:

- Durable event persistence.
- Authentication.
- Idempotency.
- Correct session behavior.
- Widget execution reliability.

### 25.3 Release condition

Do not ship interactive widget grading until:

- Review event idempotency is verified.
- App Intent can persist locally safely.
- Widget state refresh is reliable.

### 25.4 Alternative

Use a nongraded flashcard preview that opens full Review for grading.

---

## 26. Widget snapshot architecture

### 26.1 Atomic writes

```text
Build snapshot
→ Encode
→ Write temporary file
→ Validate
→ Replace current snapshot atomically
→ Request widget reload
```

### 26.2 Versioning

Every snapshot includes:

```text
schemaVersion
```

Widget behavior for unsupported future version:

- Show safe fallback.
- Open Voca.

### 26.3 Account isolation

Snapshot contains only the active account.

Switching account:

- Replaces snapshot atomically.
- Never merges data.

### 26.4 Cleanup

Clear on:

- Sign out.
- Remove local account data.
- Disable widgets' private content.

---

## 27. Notifications

### 27.1 Notification types

Initial:

```text
Review Reminder
Daily Goal Reminder
Synchronization Action Required
Long Operation Completed
```

### 27.2 Principles

- Permission is requested in context.
- Reminders are configurable.
- Stable unchanged state does not produce repeated alerts.
- Notifications act on meaningful state.
- Content respects privacy preferences.

### 27.3 Review Reminder

Trigger based on:

- User schedule.
- Due-card availability.
- Pause Reminders Today state.

Actions:

- Review Now.
- Remind in One Hour.
- Pause Today.

### 27.4 Daily Goal Reminder

Optional.

Trigger:

- Configured time.
- Goal incomplete.
- User has not paused reminders.

Avoid sending both review and goal reminders for the same state within a short period.

### 27.5 Sync Action Required

Use only when:

- User action is required.
- Pending work is at risk or blocked.

Do not notify for:

- Ordinary offline status.
- One transient failed retry.
- Successful sync.

### 27.6 Long Operation Completed

Used for:

- Large import.
- OCR extraction.
- Export.

Only notify if:

- Operation continued in background.
- App is not active.
- Notification is useful.

---

## 28. Notification privacy

### 28.1 Content modes

Settings:

```text
Show detailed notification content
Show private summary only
```

### 28.2 Private summary

Examples:

```text
Voca has cards ready for review.
```

```text
A Voca operation needs your attention.
```

### 28.3 Detailed content

May show:

- Due count.
- Goal progress.
- Import name where safe.

Avoid:

- Specific personal notes.
- Imported text.
- AI prompt.
- Provider errors containing private data.

---

## 29. Notification routing

### 29.1 Review Now

```text
voca://review
```

### 29.2 Open Today

```text
voca://today
```

### 29.3 Sync Action Required

```text
voca://activity
```

### 29.4 Import completed

```text
voca://import/{importJobID}
```

### 29.5 Deleted or unavailable target

If the target no longer exists:

- Open the nearest valid destination.
- Explain the item is unavailable.

---

## 30. Deep-link contract

### 30.1 Scheme

```text
voca://
```

### 30.2 Routes

```text
voca://today
voca://vocabulary
voca://vocabulary/word/{userCardID}
voca://vocabulary/favorites
voca://vocabulary/recent
voca://vocabulary/difficult
voca://vocabulary/due
voca://vocabulary/smart/{smartListID}
voca://review
voca://review/start
voca://practice/{practiceType}
voca://assistant
voca://assistant/conversation/{conversationID}
voca://conversation
voca://insights/{report}
voca://activity
voca://quick-lookup
voca://quick-lookup?query={encodedQuery}
```

### 30.3 Validation

Validate:

- Scheme.
- Host.
- Path shape.
- Identifier format.
- Query length.
- Supported language and enum values.

### 30.4 Authentication gate

For protected routes:

1. Parse typed route.
2. Store safe pending route.
3. Authenticate.
4. Resolve account ownership.
5. Open route.

### 30.5 Pending-route privacy

Do not persist:

- Raw selected text.
- Large AI prompts.
- Clipboard content.

without an explicit secure continuation design.

### 30.6 Unknown route

- Do not crash.
- Open Voca main window.
- Show unsupported-link message where useful.

### 30.7 Malicious input

Reject:

- Excessively long query.
- Path traversal-like input.
- Unsupported schemes.
- Token-like parameters.
- Cross-account entity references.

---

## 31. URL router architecture

### 31.1 Parser

```swift
protocol AppRouteParser: Sendable {
    func parse(_ url: URL) throws -> AppRoute
}
```

### 31.2 Opener

```swift
@MainActor
protocol AppRouteOpener {
    func open(_ route: AppRoute)
}
```

### 31.3 Separation

The parser:

- Validates syntax.
- Returns typed route.

The opener:

- Selects scene.
- Applies authentication gate.
- Loads entity.
- Presents unavailable state.

### 31.4 Migration from current router

The current iOS router behavior should evolve from:

- Card-slug state.
- Direct speech side effects.

to:

- Typed routes.
- Application use cases.
- Scene coordination.

Speech URLs should invoke a speech command through a use case rather than make the router construct a TTS service directly.

---

## 32. Authentication across integrations

### 32.1 Authentication states

```text
Signed In
Signed Out
Refresh Required
Reauthentication Required
Account Removed
```

### 32.2 Read-only integration

May use local data when:

- Account session is still valid under policy.
- Private data remains authorized.

### 32.3 Mutating integration

Requires:

- Valid account identity.
- Local durable mutation capability.
- Reauthentication for sensitive operations where required.

### 32.4 Extension credentials

Extensions should not receive raw general-purpose credentials unless architecture review proves it necessary and safe.

Preferred:

- Use shared local snapshots.
- Open main app for authenticated mutation.
- Use narrowly scoped shared Keychain access only for approved intents.

### 32.5 Account switch

After account switch:

- Update intent entity queries.
- Replace widget snapshot.
- Rebuild Spotlight.
- Cancel old account integration tasks.
- Clear pending deep links tied to old account.

---

## 33. App Group strategy

### 33.1 Purpose

App Group stores only data required across:

- Main app.
- Widgets.
- Approved extensions.

### 33.2 Allowed data

- Versioned widget snapshot.
- Pending widget route.
- Nonsecret feature flags required by extension.
- Shared nonprivate resources where necessary.

### 33.3 Disallowed by default

- Full account database.
- Refresh token.
- Provider API keys.
- Personal notes.
- AI conversations.
- Clipboard content.
- Imported documents.

### 33.4 File naming

Use:

```text
widget-snapshot-v1.json
pending-route-v1.json
integration-config-v1.json
```

### 33.5 Atomicity

All shared snapshots use atomic replacement.

### 33.6 Cleanup

Clear account-scoped files on:

- Sign out.
- Account switch.
- Remove local data.

---

## 34. Extension dependency boundaries

### 34.1 Shared

Extensions may depend on:

- Domain value types.
- App Intent definitions.
- Lightweight snapshot decoder.
- Route definitions.
- Localized strings.
- Design tokens appropriate to widgets.

### 34.2 Avoid

Extensions should not depend on:

- Main app router implementation.
- Main SwiftUI feature tree.
- Full synchronization coordinator.
- Full AI client.
- Import pipeline.
- AppKit window coordinator.

### 34.3 Build-time enforcement

Separate modules should make invalid dependency direction difficult.

### 34.4 Initialization budget

Widgets and intents must initialize quickly.

Heavy services should load only when invoked.

---

## 35. Signed-out cleanup

### 35.1 Immediate actions

On sign out:

- Remove widget private snapshot.
- Reload widgets.
- Remove Spotlight records for the account.
- Clear App Group pending routes.
- Clear menu bar private snapshot.
- Cancel account-scoped intent jobs.
- Unschedule private notifications.
- Remove account credentials according to auth policy.

### 35.2 Retained local data

If local cache is retained:

- It remains inaccessible to system integrations.
- It is not indexed.
- It is not shown in widgets.
- It is not returned by App Entity queries.

### 35.3 Failure cleanup

If Spotlight deletion or widget reload fails:

- Retry promptly.
- Record safe action-required diagnostics.
- Prefer hiding private content through snapshot replacement immediately.

---

## 36. Accessibility

### 36.1 App Intents

Intent names and parameters should be:

- Distinct.
- Concise.
- Localized.
- Understandable when spoken.

Avoid similar names such as:

```text
Open Review
Start Review
Review Now
```

unless their behavior clearly differs.

### 36.2 Siri phrases

Suggested phrases must:

- Use natural localized wording.
- Avoid requiring pronunciation of internal product terminology.
- Distinguish Voca from generic dictionary actions.

### 36.3 Spotlight

Result titles and subtitles must remain understandable with VoiceOver.

### 36.4 Widgets

Widgets require:

- Accessible labels for summary values.
- Meaningful button names.
- No color-only state.
- Larger-text validation.
- Increased-contrast validation.

### 36.5 Notifications

Notification actions use direct names:

- Review Now.
- Remind Me Later.
- Open Activity.

### 36.6 Services

Service names should describe the result:

- Look Up in Voca.
- Add to Voca.
- Explain with Voca.

---

## 37. Privacy matrix

### App Intents

May receive:

- Explicit word.
- Explicit selected entities.
- Explicit text for AI action.

Must not receive automatically:

- Clipboard history.
- Personal notes.
- Unrelated vocabulary.

### Spotlight

May index:

- Word.
- Pronunciation or pinyin.
- Concise meaning.

Excluded by default:

- Notes.
- Review history.
- AI content.

### Widgets

May show:

- Due count.
- Goal.
- Streak.
- Word of the day with permission.

Excluded:

- Notes.
- Credentials.
- AI conversations.

### Notifications

May show:

- Due count with detailed-content permission.
- Generic reminders.

Excluded:

- Notes.
- Imported text.
- AI prompt.

### Services

May process:

- Current explicit selection.

Must not persist after cancellation.

---

## 38. Performance and energy

### 38.1 App Intents

Simple local intents should return promptly without launching full application state.

### 38.2 Spotlight

- Index in batches.
- Avoid reindexing unchanged cards.
- Debounce bursts of changes.
- Rebuild only when required.

### 38.3 Widgets

- Decode small snapshots.
- Avoid networking.
- Avoid database initialization.
- Keep timelines conservative.

### 38.4 Notifications

- Recompute schedule after meaningful changes.
- Avoid rescheduling every card mutation.

### 38.5 Services

- Open target surface quickly.
- Defer remote work until the app surface is ready.

### 38.6 Background activity

System integrations must not create:

- Continuous polling.
- Continuous clipboard scanning.
- Repeated AI requests.
- Repeated full Spotlight rebuilding.

---

## 39. Error behavior

### 39.1 Intent error categories

```text
Authentication Required
No Matching Word
Ambiguous Result
Offline
Service Unavailable
Permission Denied
Validation Failed
Open Voca to Continue
```

### 39.2 Spotlight indexing error

- Vocabulary remains saved.
- Index retry is separate.
- Surface action only after repeated failure.

### 39.3 Widget snapshot error

- Show last valid snapshot if safe.
- Otherwise show Open Voca.
- Never display partially decoded private data.

### 39.4 Service input error

Examples:

```text
Select a word or short phrase.
The selected text is too long for Quick Lookup.
Open Voca to extract vocabulary from this passage.
```

### 39.5 Notification action failure

Open the closest safe route and display an actionable in-app message.

---

## 40. Testing strategy

### 40.1 App Intent tests

- Parameter validation.
- Local lookup.
- Remote lookup.
- Duplicate Add Word.
- Offline add.
- Due count.
- Signed-out state.
- Open-app routing.
- AI consent boundary.

### 40.2 Entity tests

- ID resolution.
- Search.
- Suggested entities.
- Deleted entity.
- Cross-account entity.
- Account switch.

### 40.3 Spotlight tests

- Initial index.
- Incremental update.
- Delete.
- Restore.
- Sign out.
- Disable integration.
- Rebuild.
- Deep-link exact entity.

### 40.4 Services tests

- One word.
- Short phrase.
- Long paragraph.
- Unsupported input.
- Signed out.
- No automatic save.
- No automatic AI upload.

### 40.5 Widget tests

- Signed in.
- Signed out.
- Due cards.
- No due cards.
- Goal complete.
- Privacy mode.
- Stale snapshot.
- Unsupported snapshot version.
- Account switch.
- Deep-link action.

### 40.6 Notification tests

- Permission denied.
- Review reminder.
- Pause Today.
- Remind Later.
- Duplicate suppression.
- Privacy summary.
- Action routing.
- Action-required sync.

### 40.7 Deep-link tests

- Every canonical route.
- Unknown route.
- Invalid ID.
- Excessively long query.
- Signed-out continuation.
- Deleted entity.
- Cross-account entity.

### 40.8 Cleanup tests

- Sign out clears widget.
- Sign out clears Spotlight.
- Sign out unschedules private notifications.
- Sign out clears pending routes.
- Retained database remains inaccessible.

### 40.9 Accessibility tests

- Intent names.
- Widget labels.
- Spotlight result labels.
- Notification actions.
- Service names.
- Larger-text widgets.
- Increased Contrast.

### 40.10 Performance tests

- 10,000-card Spotlight index.
- Incremental indexing burst.
- Widget snapshot decoding.
- Intent cold launch.
- Intent warm launch.
- Sign-out cleanup duration.

---

## 41. Requirement traceability

### `SYS-001` — Spotlight indexing

Covered by:

- Indexed content.
- Privacy exclusions.
- Incremental updates.
- Deletion.
- Deep links.
- Rebuild.

### `SYS-002` — App Intents

Covered by:

- Intent inventory.
- Shared use cases.
- Parameters.
- Authentication.
- Offline behavior.

### `SYS-003` — Shortcuts

Covered by:

- Structured inputs and outputs.
- Suggested shortcuts.
- Automation safety.
- Composition examples.

### `SYS-004` — Widgets

Covered by:

- Widget families.
- App Group snapshot.
- Interactive actions.
- Signed-out behavior.
- Privacy.

### `SYS-005` — Notifications

Covered by:

- Reminder types.
- Scheduling principles.
- Privacy.
- Actions.
- Deep-link routing.

### `SYS-006` — Launch at login

Detailed primarily in [`macos-menu-bar.md`](macos-menu-bar.md), with integration lifecycle and signed-out behavior supported here.

---

## 42. Acceptance scenarios

### Scenario A — Shortcut due count

1. Run Show Due Count in Shortcuts.
2. Keep the main app closed.

Expected:

- Local due count returns.
- Main app does not open.
- Updated time is included when data is stale.

### Scenario B — Add Word intent

1. Run Add Word with a new English word.
2. Run it again with the same input.

Expected:

- First action creates one user card.
- Second returns Already in Vocabulary.
- No duplicate is created.

### Scenario C — Ambiguous Add Word

1. Run Add Word with an ambiguous phrase.

Expected:

- Voca opens a candidate-selection route.
- No silent save occurs.

### Scenario D — Spotlight vocabulary

1. Search a saved word in Spotlight.
2. Open the result.

Expected:

- Exact word detail opens.
- Correct active account is used.

### Scenario E — Spotlight deletion

1. Delete a saved word.
2. Search Spotlight after indexing completes.

Expected:

- Deleted result is absent.

### Scenario F — Sign out

1. Sign out of Voca.
2. Inspect widgets and Spotlight.

Expected:

- Private word content and counts disappear.
- Entity queries return no account data.

### Scenario G — Service lookup

1. Select a word in another app.
2. Choose Look Up in Voca.

Expected:

- Quick Lookup opens with the selection.
- The word is not automatically saved.

### Scenario H — Service explanation

1. Select a sentence.
2. Choose Explain with Voca.

Expected:

- Voca opens context preview.
- Text is not sent to AI until user confirms.

### Scenario I — Due widget

1. Add the Due Count widget.
2. Complete reviews.

Expected:

- Snapshot updates.
- Selecting widget opens Review.

### Scenario J — Widget privacy

1. Disable vocabulary content on widgets.

Expected:

- Word-of-the-day content disappears.
- Due or goal summary remains.

### Scenario K — Notification reminder

1. Configure a review reminder.
2. Let due cards remain.
3. Receive notification.
4. Choose Review Now.

Expected:

- Review route opens.
- Duplicate reminder is not immediately sent.

### Scenario L — Pause reminders

1. Choose Pause Today.

Expected:

- Additional daily reminders are suppressed.
- Due dates and daily-goal state remain unchanged.

### Scenario M — Deep link while signed out

1. Open a valid word deep link while signed out.
2. Sign in.

Expected:

- Safe pending route resumes.
- Exact accessible word opens.

### Scenario N — Malicious deep link

1. Open an excessively long or malformed URL.

Expected:

- Input is rejected.
- App does not crash.
- No token-like input is logged.

### Scenario O — Account switch

1. Index account A.
2. Switch to account B.

Expected:

- A's Spotlight and widget content is removed.
- B's data appears only after valid local snapshot or sync.

---

## 43. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. System integrations call shared application use cases.
2. Simple intents complete without opening the main application.
3. Complex or ambiguous work opens a canonical route.
4. Saved vocabulary is represented as an account-bound App Entity.
5. Spotlight indexes word identity and concise meaning, not personal notes.
6. Spotlight integration is user-controllable.
7. macOS Services never save or upload selected text automatically.
8. Widgets read a compact versioned App Group snapshot.
9. Widgets do not access the full account database or Keychain credentials.
10. Interactive FSRS grading in widgets is deferred until idempotent local intent execution is proven.
11. Notification actions alter reminder behavior, not FSRS scheduling.
12. All integrations clear private projections on sign out.
13. Deep links use typed routes and stable IDs.
14. The router does not perform domain side effects directly.
15. Extension targets depend on lightweight shared modules, not the full main application.

---

## 44. Open questions

1. Which App Intents are supported consistently across the selected macOS deployment target?
2. Should Spotlight indexing be enabled by default?
3. Should Spotlight index concise meanings or only word identity?
4. Can unauthenticated users use Look Up Word?
5. Which intents may access shared Keychain credentials?
6. Should Add Word complete fully inside an intent when remote lookup is required?
7. Which Services mechanism provides the most reliable selected-text integration?
8. Is a Share Extension necessary on macOS?
9. Should Services preserve selected text across authentication?
10. Which widget families will ship first?
11. Should Word of the Day use private vocabulary by default?
12. Should widgets expose pronunciation actions?
13. When can interactive widget grading safely ship?
14. How frequently should widget timelines refresh?
15. Does the backend expose a lightweight due-summary endpoint?
16. Which notification types are necessary for the first release?
17. Should Daily Goal Reminder be separate from Review Reminder?
18. How long may a pending authenticated deep link remain?
19. Should Smart Lists be App Entities?
20. Which routes should also support universal links?

---

## 45. Security review checklist

- [ ] Intent inputs have size limits.
- [ ] Entity resolution is account-bound.
- [ ] Cross-account IDs are rejected.
- [ ] Selected text is not logged.
- [ ] Selected text is not uploaded before explicit action.
- [ ] Widgets contain no credentials.
- [ ] Spotlight excludes notes and AI conversations.
- [ ] Signed-out cleanup removes private projections.
- [ ] Deep-link parameters cannot include credentials.
- [ ] Unknown URLs fail safely.
- [ ] App Group files are versioned and atomic.
- [ ] Extension dependencies are minimal.
- [ ] Notification content respects privacy settings.
- [ ] AI intents explain provider transmission.

---

## 46. Definition of done

System integrations are complete for the macOS differentiation release when:

- Core App Intents use shared domain actions.
- Shortcuts receive useful structured inputs and outputs.
- Saved vocabulary appears in Spotlight according to privacy settings.
- Spotlight results open exact word detail.
- macOS Services handle selected text without automatic saving or upload.
- Initial widgets display current local snapshots.
- Signed-out widgets expose no private content.
- Review reminders are configurable and nonduplicative.
- Notification actions route correctly.
- Deep links are typed, validated, and authentication-aware.
- Account switching removes stale system projections.
- Extensions initialize only required dependencies.
- App Group snapshots are atomic and versioned.
- VoiceOver and localization behavior pass for all shipped surfaces.
- Performance, energy, cleanup, and privacy tests pass.
- Critical acceptance scenarios have automated or documented manual coverage.

---

## 47. Next document

The next document should be:

```text
docs/macos-practice-and-ai.md
```

It should define:

- Practice information architecture.
- Drills.
- Reading comprehension.
- Listening.
- Writing.
- Assistant workspace.
- Conversation practice.
- Context selection.
- AI request lifecycle.
- Streaming.
- Provider and model settings.
- Cancellation.
- Content persistence.
- Vocabulary grounding.
- Generated-content labeling.
- Privacy and explicit transmission.
- Offline behavior.
- Cost control.
- Accessibility.
- Testing and acceptance criteria mapped to `AI-*`.
