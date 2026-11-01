# Voca for macOS — Testing and Quality Strategy

> Test architecture, environments, fixtures, automation, accessibility, performance, security, continuous integration, and release-quality gates for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Testing and Quality Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Related security specification:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca for macOS will be verified before and after release.

It covers:

- Test architecture.
- Test targets.
- Unit tests.
- Repository and persistence tests.
- Networking tests.
- Integration tests.
- UI tests.
- Accessibility tests.
- Performance and energy tests.
- Security and privacy tests.
- Synchronization and offline tests.
- Review-event idempotency tests.
- Quick Lookup and menu bar tests.
- System-integration tests.
- AI streaming and structured-output tests.
- Import parser and fuzz tests.
- Fixtures and builders.
- Test environments.
- Continuous integration.
- Flaky-test management.
- Release-quality gates.
- Production validation.

The primary objective is:

> Every acknowledged user action must remain correct, durable, private, accessible, and recoverable across application restarts, network failures, synchronization, and account changes.

---

## 2. Quality principles

### TEST-PRN-001 — Test behavior at the lowest reliable layer

Use:

- Domain tests for rules.
- Use-case tests for orchestration.
- Repository tests for persistence.
- Integration tests for boundaries.
- UI tests only for user-visible workflows.

Do not move all verification into slow end-to-end tests.

### TEST-PRN-002 — Critical failures are injected deliberately

Voca must be tested under:

- Network loss.
- Process termination.
- Token expiry.
- Disk failure.
- Migration failure.
- Duplicate requests.
- Out-of-order responses.
- Account switch.

### TEST-PRN-003 — Time is controlled

Due dates, daily goals, streaks, retry schedules, and cache expiry must use an injectable clock.

### TEST-PRN-004 — Test data is synthetic

Fixtures must not contain:

- Real credentials.
- Real personal notes.
- Production exports.
- Actual user conversations.
- Sensitive documents.

### TEST-PRN-005 — Accessibility is a release condition

Keyboard, VoiceOver, larger text, contrast, and reduced-motion behavior are part of acceptance, not optional polish.

### TEST-PRN-006 — Privacy is testable

Tests must verify that private marker values do not appear in:

- Logs.
- Analytics.
- Diagnostics.
- Widgets.
- Spotlight.
- Notifications.

### TEST-PRN-007 — Performance targets use representative data

Large-library and large-import benchmarks must use realistic synthetic datasets.

### TEST-PRN-008 — Flaky tests are defects

A flaky test must be fixed, quarantined with ownership, or removed. It must not be retried indefinitely until green.

### TEST-PRN-009 — macOS behavior requires macOS verification

Window placement, menu commands, Spaces, multiple displays, menu bar, focus, and AppKit bridges require macOS-specific validation.

### TEST-PRN-010 — Release gates are objective

Each release candidate should be evaluated against documented pass criteria, not informal confidence.

---

## 3. Test pyramid

Recommended distribution:

```text
                    ┌───────────────┐
                    │ Exploratory   │
                    │ and manual    │
                 ┌──┴───────────────┴──┐
                 │ macOS UI and system │
              ┌──┴─────────────────────┴──┐
              │ Integration and contract   │
           ┌──┴────────────────────────────┴──┐
           │ Repository and infrastructure     │
        ┌──┴───────────────────────────────────┴──┐
        │ Domain, use-case, state, and utilities   │
        └─────────────────────────────────────────┘
```

The largest test group should be:

- Fast.
- Deterministic.
- Process-local.
- Independent from production services.

---

## 4. Test target topology

Proposed targets:

```text
VocaCoreTests
├── Domain
├── Application
├── Networking
├── Persistence
├── Synchronization
└── Security utilities

VocaMacTests
├── Feature state
├── Routing
├── Commands
├── Window coordination
├── AppKit bridges
└── macOS-specific services

VocaMacUITests
├── Critical journeys
├── Keyboard workflows
├── Accessibility smoke tests
├── Window behavior
└── System integration routing

VocaIntegrationTests
├── Local backend
├── Temporary database
├── Token refresh
├── Incremental sync
└── Review idempotency

VocaPerformanceTests
├── Search
├── Large table
├── Sync
├── Import
├── Spotlight
└── Quick Lookup
```

### 4.1 Shared tests

Shared iOS and macOS behavior belongs in shared test targets:

- Models.
- API decoding.
- Repository contracts.
- Review grades.
- Synchronization.
- AI schemas.

### 4.2 Platform tests

macOS-specific tests cover:

- Window scenes.
- Menu commands.
- Quick Lookup panel.
- Menu bar.
- Spotlight.
- Services.
- Drag and drop.
- File access.
- Multiple windows.

---

## 5. Test environments

### 5.1 Pure unit environment

Uses:

- In-memory repositories.
- Test clock.
- Deterministic UUID generator.
- Stubbed speech.
- Stubbed analytics.
- No file system where unnecessary.
- No network.

### 5.2 Infrastructure environment

Uses:

- Temporary directories.
- Temporary database.
- URL protocol transport stub.
- Synthetic audio and image fixtures.
- Controlled Keychain substitute.

### 5.3 Local integration environment

Uses:

- Local backend.
- Dedicated test database.
- Stub AI provider.
- Stub TTS provider.
- Synthetic accounts.
- Deterministic server time.

### 5.4 UI-test environment

Uses launch arguments such as:

```text
--uitesting
--reset-local-state
--fixture-account standard
--stub-network success
--disable-animations
```

These arguments must not create production backdoors.

### 5.5 Staging environment

Used for:

- Authentication integration.
- Signing and entitlements.
- Notifications.
- Widget timelines.
- Spotlight.
- App Intents.
- Limited end-to-end smoke tests.

Production data must not be copied into staging.

---

## 6. Deterministic test dependencies

### 6.1 Clock

```swift
protocol VocaClock: Sendable {
    var now: Date { get }
    func sleep(for duration: Duration) async throws
}
```

Test clock supports:

- Manual advancement.
- Scheduled task control.
- Day-boundary testing.
- Retry testing.

### 6.2 UUID generator

Use deterministic IDs for:

- Review events.
- Sessions.
- Mutations.
- Import jobs.
- AI requests.

### 6.3 Random source

Inject seeded randomness for:

- Review queues.
- Practice distractors.
- Recommendations.
- Word of the day.

### 6.4 Locale and calendar

Tests explicitly set:

- Locale.
- Calendar.
- Time zone.
- First weekday.

### 6.5 Connectivity

Use a controlled connectivity source:

```text
Online
Offline
Constrained
Transitioning
```

### 6.6 File system

Tests use temporary directories and explicit cleanup.

---

## 7. Fixture strategy

### 7.1 Fixture categories

```text
Accounts
Vocabulary
Study state
Review events
Smart Lists
AI responses
Imports
Widget snapshots
Deep links
Errors
```

### 7.2 Vocabulary fixture set

Include:

- English words.
- Chinese words.
- Pinyin with tone marks.
- Vietnamese meanings.
- Long meanings.
- Missing fields.
- Favorites.
- Tags.
- Notes.
- Due and future cards.
- Deleted cards.
- Pending local cards.

### 7.3 Naming

Use descriptive names:

```text
englishDueCard
chineseCardWithPinyin
pendingOfflineNote
deletedFavoriteCard
conflictingPersonalNote
```

### 7.4 Builders

Provide builders with valid defaults:

```swift
let card = UserCardFixture.make(
    word: "concise",
    dueAt: clock.now
)
```

Tests should override only relevant fields.

### 7.5 Golden data

Version-controlled fixtures are appropriate for:

- API decoding.
- Migration.
- Import schemas.
- AI structured output.

Avoid large opaque binary fixtures when a small synthetic fixture is sufficient.

### 7.6 Sensitive marker fixtures

Use recognizable synthetic markers:

```text
TEST_SECRET_REFRESH_TOKEN
TEST_PRIVATE_NOTE_MARKER
TEST_AI_PROMPT_MARKER
TEST_CLIPBOARD_MARKER
```

Security tests verify these markers never appear in prohibited outputs.

---

## 8. Domain tests

### 8.1 Vocabulary

Test:

- Normalization.
- Duplicate classification.
- Language validation.
- Tag normalization.
- Smart List predicates.
- Search ranking inputs.

### 8.2 Review

Test:

- Grade mapping.
- Session progress.
- Queue invariants.
- Exactly-once event creation.
- Invalid-card removal.
- Partial completion.

### 8.3 Today

Test:

- Primary-action priority.
- Goal contribution.
- Streak calculation.
- Recommendation rules.
- Language summary.

### 8.4 Practice

Test:

- Vocabulary-source selection.
- Context minimization.
- Structured exercise validation.
- Scoring.
- No FSRS mutation.

### 8.5 Import

Test:

- Candidate normalization.
- Stop-term rules.
- Candidate ranking.
- Duplicate grouping.
- Validation severity.

### 8.6 Security

Test:

- Sensitive-data classification.
- Log allowlist.
- Deep-link validation.
- Export-field policy.
- Account-bound identity.

---

## 9. Use-case tests

Required use-case coverage:

```text
BootstrapAccount
SignIn
SignOut
LoadToday
SearchVocabulary
AddWord
UpdateCard
DeleteCards
StartReviewSession
SubmitReviewGrade
ResumeReviewSession
GeneratePractice
SendAssistantMessage
ImportVocabulary
SynchronizeAccount
HandleDeepLink
IndexSpotlight
```

### 9.1 Structure

Each test verifies:

- Input.
- Dependency calls.
- Output.
- State mutation.
- Error mapping.
- Cancellation.
- Privacy-relevant side effects.

### 9.2 Negative paths

Every mutating use case should include:

- Validation failure.
- Authentication required.
- Offline behavior.
- Storage failure.
- Remote failure.
- Duplicate retry.
- Cancellation where supported.

---

## 10. Feature-state tests

### 10.1 General pattern

Test:

- Initial phase.
- Loading.
- Success.
- Empty.
- Error.
- Retry.
- Cancellation.
- Stale response suppression.

### 10.2 Vocabulary

- Query debounce.
- Old search result ignored.
- Selection preserved after refresh.
- Selection cleared after deletion.
- Multi-selection batch state.
- Inspector switching.

### 10.3 Review

- Grade disabled before reveal.
- One accepted grade.
- Rapid repeated key input.
- Pause.
- Resume.
- Completion.

### 10.4 Quick Lookup

- Clipboard suggestion is not submitted.
- Local result appears first.
- Stale remote result ignored.
- Existing local pending card counts as saved.

### 10.5 Assistant

- Stream starts.
- Deltas append correctly.
- User scrolling disables auto-follow.
- Stop changes state.
- Retry creates one new request.

---

## 11. Repository contract tests

Every repository implementation should pass a shared contract suite.

### 11.1 Vocabulary contract

- Save and retrieve card.
- Query by language.
- Search normalization.
- Favorite filter.
- Tag relation.
- Soft delete.
- Restore.
- Account isolation.

### 11.2 Review contract

- Due-card query.
- Unique operation ID.
- Transactional grade.
- Session progress.
- Pending-event ordering.

### 11.3 Settings contract

- Device-local setting.
- Account setting.
- Secret reference exclusion.

### 11.4 Contract implementations

Run against:

- In-memory repository.
- Local database repository.
- Synchronizing repository where applicable.

---

## 12. Database tests

### 12.1 Schema

- Fresh creation.
- Required indexes.
- Constraints.
- Foreign relationships.
- Unique operation IDs.

### 12.2 Transactions

Verify rollback for:

- Review event plus session progress.
- Import chunk.
- Sync page.
- Card and tags.

### 12.3 Queries

- Search.
- Pagination.
- Sorting.
- Smart Lists.
- Due state.
- Trash.

### 12.4 Account isolation

Insert identical IDs under different synthetic account contexts where model permits.

Verify queries never cross the active account boundary.

### 12.5 Concurrency

Test:

- Concurrent reads.
- Serialized writes.
- Sync update during search.
- Cancellation.

### 12.6 Corruption recovery

Use controlled invalid stores to verify:

- Open failure.
- Integrity failure.
- Backup restoration.
- Rebuild while preserving pending work.

---

## 13. Migration tests

### 13.1 Fixture per released schema

Keep a database fixture for each supported prior release schema.

### 13.2 Migration assertions

- Schema version advances.
- Data remains correct.
- Pending mutations remain.
- Review events remain unique.
- Account ownership remains.
- FTS index rebuilds.

### 13.3 Interrupted migration

Terminate at controlled migration checkpoints.

On relaunch:

- Resume.
- Roll back.
- Restore backup.

according to migration design.

### 13.4 Payload migration

Test old queued mutation payloads:

- Successfully transform.
- Remain recoverable if transformation is impossible.

### 13.5 Performance

Benchmark migrations with realistic large stores.

---

## 14. Networking tests

### 14.1 Transport stub

Support:

- Status codes.
- Headers.
- Delayed response.
- Chunked stream.
- Redirect.
- Timeout.
- Connection loss.
- Invalid body.

### 14.2 Decoding

Test:

- Valid envelope.
- Missing optional field.
- Unknown enum.
- Invalid date.
- Malformed JSON.
- Oversized content.

### 14.3 Authentication

- Authorization header added.
- Header redacted from logs.
- One serialized token refresh.
- Concurrent requests await refresh.
- Retry occurs once.
- Refresh failure signs out safely.

### 14.4 Retry

- Idempotent GET retries.
- Non-idempotent request does not blindly retry.
- Idempotency-key mutation safely retries.
- Rate-limit guidance is respected.

### 14.5 Redirect

Verify authorization is not forwarded to an unrelated origin.

### 14.6 Cancellation

Cancel:

- Search.
- AI stream.
- Import upload.
- Remote TTS.

Verify callbacks do not mutate obsolete state.

---

## 15. Synchronization tests

### 15.1 Pull cycle

- Initial bootstrap.
- One page.
- Multiple pages.
- Cursor commit.
- Page rollback.
- Cursor expiry.
- Full rebuild.

### 15.2 Push cycle

- One mutation.
- Independent mutations.
- Dependent mutations.
- Safe coalescing.
- Permanent failure.
- Retry scheduling.

### 15.3 Conflict

- Favorite conflict.
- Tag add and remove.
- Divergent note.
- Smart List edit.
- Remote deletion with local update.

### 15.4 Process restart

Terminate while:

- Pending.
- In flight.
- Applying remote page.
- Updating derived data.

Verify restart-safe behavior.

### 15.5 Connectivity transition

```text
Online → Offline
Offline → Online
Online → Constrained
```

Verify one sync coordinator and no duplicate job.

### 15.6 Account switch

- Old account sync cancels.
- Queue remains bound to old account.
- New account uses its own token and store.

---

## 16. Review idempotency tests

These tests are release-critical.

### 16.1 Rapid duplicate input

Press grade key repeatedly.

Expected:

- One local review event.
- One session advancement.

### 16.2 Timeout before receipt

Client sends request and server does not receive it.

Expected:

- Same operation ID retries.
- One accepted event.

### 16.3 Timeout after acceptance

Server accepts event but response is lost.

Expected:

- Retry uses same operation ID.
- Server returns prior outcome.
- FSRS state changes once.

### 16.4 Process termination

Terminate after local transaction but before UI advancement.

Expected:

- Resume detects completed event.
- No duplicate event is created.

### 16.5 Offline sequence

Create multiple events for one card where supported by valid workflow.

Expected:

- Events submit in deterministic order.

### 16.6 Cross-device conflict

Another device reviews the card.

Expected:

- Server reconciliation is applied.
- Local event is preserved or resolved by contract.
- No silent loss occurs.

### 16.7 Release gate

Offline FSRS review cannot ship unless these tests pass against the actual backend contract.

---

## 17. Today tests

### 17.1 Primary-action matrix

Test:

```text
Signed out
First run
Active review
Due cards
Goal incomplete
Goal complete
No cards due
Offline with cache
Offline without cache
Action-required sync
```

### 17.2 Daily goal

- Accepted review contributes once.
- Duplicate event does not contribute twice.
- Offline event contributes provisionally.
- Time-zone change.
- Goal change.
- Day boundary.

### 17.3 Streak

- Consecutive days.
- Missed day.
- Travel.
- Offline reconciliation.
- Duplicate event.

### 17.4 Recommendation

- Deterministic source.
- Explainable reason.
- Dismissal.
- Offline capability.
- Deleted source cards.

---

## 18. Quick Lookup tests

### 18.1 Invocation

- Main app open.
- Main app closed.
- Another app active.
- Full-screen app.
- Multiple displays.
- Different Spaces.

### 18.2 Window

- One panel only.
- Correct display.
- Visible frame.
- Search field focused.
- Escape dismissal.
- Outside-click policy.
- Prior app focus restoration.

### 18.3 Lookup

- Exact local result.
- Cached dictionary.
- Remote result.
- Multiple candidates.
- No result.
- Offline.
- Authentication required.

### 18.4 Concurrency

- Rapid query replacement.
- Old remote response arrives last.
- Cancelled lookup cannot update UI.

### 18.5 Save

- New word.
- Existing word.
- Pending local word.
- Offline save.
- Repeated shortcut.

### 18.6 Clipboard

- Preference disabled.
- Valid short word.
- Long text.
- Secret-like token.
- No automatic network request.
- Raw clipboard value absent from logs.

### 18.7 Performance

Measure:

- Cold presentation.
- Warm presentation.
- Local exact search.
- Broad local search.
- Idle shortcut-listener energy.

---

## 19. Menu bar tests

### 19.1 Enablement

- Enable.
- Disable.
- Relaunch.
- Independent Quick Lookup setting.

### 19.2 Lifecycle

- Main window closed.
- Menu bar remains.
- Open Voca creates or restores window.
- Quit terminates ambient services.

### 19.3 State

- Signed in.
- Signed out.
- Due cards.
- Goal complete.
- Offline.
- Action required.
- Active review.

### 19.4 Mini Review

- Five cards.
- Fewer than five.
- Rapid grade input.
- Pause.
- Offline.
- Full-session conflict.

### 19.5 Launch at login

- Starts in background.
- Main window remains closed.
- Shortcut registration.
- Signed-out state.

### 19.6 Energy

Measure:

- Idle CPU.
- Wakeups.
- Refresh frequency.
- Memory with no main window.

---

## 20. AppKit bridge tests

### 20.1 Protocol tests

Test feature behavior against fake bridge implementations.

### 20.2 Integration tests

Verify:

- Main-thread access.
- Window creation.
- Window focus.
- Panel positioning.
- First responder.
- Display disconnection.
- App activation.

### 20.3 Manual matrix

Some behavior requires manual testing:

- Spaces.
- Stage Manager.
- Multiple displays.
- Full-screen applications.
- Mission Control.
- Different Dock positions.

The matrix must be completed for release candidates.

---

## 21. AI and streaming tests

### 21.1 Stream parser

- Start event.
- Text deltas.
- Unicode split across chunks.
- Structured item.
- Completion.
- Error.
- Unexpected event.

### 21.2 Request state

- Send once.
- Cancel.
- Retry.
- Partial response.
- Continue where supported.
- Account switch during stream.

### 21.3 Rendering

- Markdown.
- Long response.
- Tables.
- Unsafe HTML.
- External links.
- Chinese and Vietnamese text.

### 21.4 Context privacy

- Notes excluded.
- Clipboard excluded.
- Imported text requires preview.
- Only selected cards included.
- Cross-account card rejected.

### 21.5 Structured practice

- Valid drill.
- Missing answer ID.
- Duplicate choices.
- Wrong language.
- Excess question count.
- Unknown target card.
- One bounded repair.

### 21.6 Logging

Synthetic prompt and response markers must be absent from:

- Logs.
- Analytics.
- Diagnostics.
- Crash breadcrumbs.

---

## 22. Import and parser tests

### 22.1 CSV

- Common delimiters.
- Embedded delimiter.
- Quoted multiline field.
- Alternate encodings.
- Missing header.
- Duplicate headers.
- Formula-style content.
- Large file.

### 22.2 JSON

- Current schema.
- Prior schema.
- Future schema.
- Unknown optional fields.
- Wrong types.
- Excessive nesting.
- Excessive array size.

### 22.3 PDF

- Text PDF.
- Scanned PDF.
- Mixed PDF.
- Encrypted PDF.
- Corrupt PDF.
- Large PDF.
- Multiple columns.

### 22.4 OCR

- English.
- Chinese.
- Mixed content.
- Rotation.
- Low contrast.
- Cancellation.
- Low-confidence correction.

### 22.5 Fuzzing

Fuzz:

- CSV parser.
- JSON decoder.
- Route parser.
- Candidate normalizer.
- Markdown renderer.
- AI structured-output decoder.

### 22.6 Resource limits

Verify graceful handling of:

- File-size limit.
- Page limit.
- Row limit.
- Candidate limit.
- Memory pressure.

---

## 23. System-integration tests

### 23.1 App Intents

- Parameter validation.
- Entity resolution.
- Signed-out state.
- Offline result.
- Mutation result.
- App-opening route.

### 23.2 Spotlight

- Initial index.
- Incremental update.
- Delete.
- Restore.
- Sign out.
- Disable integration.
- Exact deep link.

### 23.3 Widgets

- Snapshot decoding.
- Unsupported schema.
- Privacy mode.
- Signed out.
- Account switch.
- Deep-link action.

### 23.4 Notifications

- Permission denied.
- Reminder scheduling.
- Pause Today.
- Route action.
- Privacy copy.
- Sign-out cleanup.

### 23.5 Services

- Short word.
- Passage.
- Unsupported content.
- No automatic save.
- No automatic AI transmission.

### 23.6 App Group

- Atomic replacement.
- Partial-write resistance.
- Account replacement.
- Sign-out clearing.

---

## 24. UI automation strategy

### 24.1 Critical journeys

Automate:

1. Sign in.
2. Open Vocabulary.
3. Search.
4. Select a word.
5. Play pronunciation.
6. Add a word.
7. Start Review.
8. Reveal and grade.
9. Open Settings.
10. Sign out.

### 24.2 Stable identifiers

Use semantic accessibility identifiers:

```text
vocabulary.search
vocabulary.table
word.pronunciation
review.reveal
review.grade.good
quickLookup.query
```

Identifiers should not depend on localized visible text.

### 24.3 Avoid fragile tests

Do not locate controls using:

- Screen coordinates.
- Dynamic data text.
- View hierarchy indexes.
- Timing-only sleeps.

### 24.4 Synchronization

Wait for:

- Accessibility state.
- Explicit test signal.
- Element existence.

Avoid arbitrary fixed delays.

### 24.5 Screenshots

Capture on failure:

- Current app window.
- Test step.
- Safe state description.

Tests must avoid including real private content.

---

## 25. Accessibility testing

### 25.1 Automated checks

Where available, verify:

- Missing labels.
- Invalid traits.
- Small targets.
- Contrast indicators.
- Duplicate identifiers.

### 25.2 Keyboard matrix

Required keyboard-only workflows:

- Vocabulary search and edit.
- Review completion.
- Quick Lookup.
- Mini Review.
- Import CSV.
- Assistant send and stop.
- Settings.

### 25.3 VoiceOver manual matrix

Validate:

- Today.
- Vocabulary table.
- Word detail.
- Review.
- Quick Lookup.
- Menu bar.
- Assistant.
- Import.
- Widgets.

### 25.4 Display settings

Test:

- Larger text.
- Increased Contrast.
- Reduce Motion.
- Different accent colors.
- Light Mode.
- Dark Mode.

### 25.5 Language

Test:

- English UI content.
- Vietnamese UI copy where localized.
- Chinese vocabulary.
- Pinyin.
- Mixed-language rows.

### 25.6 Release gate

No P0 workflow may require pointer-only interaction.

---

## 26. Visual and design-system tests

### 26.1 Preview catalog

Every foundational component should have previews for:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Larger text.
- English.
- Chinese.
- Loading.
- Empty.
- Error.
- Offline.

### 26.2 Snapshot tests

Good candidates:

- Quick Lookup.
- Review states.
- Word detail.
- Table rows.
- Empty states.
- Error states.
- Chinese content.

### 26.3 Limitations

Snapshot tests do not verify:

- Keyboard.
- VoiceOver.
- Focus.
- Native-window behavior.
- Semantic correctness.

### 26.4 Approval

Snapshot changes require:

- Design review where intentional.
- Explanation in the change request.

---

## 27. Performance tests

### 27.1 Vocabulary

Datasets:

```text
1,000 cards
10,000 cards
50,000-card stress set
```

Measure:

- Initial query.
- Search.
- Sort.
- Filter.
- Scroll.
- Selection update.

### 27.2 Synchronization

Measure:

- 10,000 remote changes.
- 1,000 pending mutations.
- Cursor paging.
- Derived-index updates.

### 27.3 Import

Measure:

- 10,000-row CSV.
- 50,000-row stress CSV.
- 100-page PDF.
- 50-page OCR PDF.

### 27.4 Quick Lookup

Measure:

- Panel presentation.
- Local exact result.
- Broad result.
- Warm and cold state.

### 27.5 Assistant

Measure:

- Long conversation rendering.
- Streaming update frequency.
- Cancellation.
- Memory after closing.

### 27.6 Regression thresholds

Each benchmark should define:

- Baseline.
- Warning threshold.
- Failure threshold.
- Owning team or feature.

Do not use one timing threshold across all CI hardware without normalization.

---

## 28. Energy tests

### 28.1 Idle application

Measure:

- Main window open.
- Main window closed.
- Menu bar enabled.
- Quick Lookup listener active.
- Signed out.
- Offline.

### 28.2 Prohibited idle behavior

Detect:

- Continuous polling.
- Continuous animations.
- Clipboard scanning.
- Excess timers.
- Repeated failed network requests.

### 28.3 Active workflows

Profile:

- Review.
- TTS playback.
- OCR.
- Large sync.
- AI streaming.

### 28.4 Battery behavior

Validate reduced nonessential work during:

- Low Power Mode.
- Battery operation.

---

## 29. Security and privacy tests

### 29.1 Secret storage

Verify secrets are absent from:

- UserDefaults.
- Database.
- App Group.
- Logs.
- Analytics.
- Diagnostics.

### 29.2 Account isolation

Verify:

- Repositories.
- Windows.
- Restoration.
- Widgets.
- Spotlight.
- Notifications.
- App Entities.
- Pending mutations.

### 29.3 Sign-out cleanup

Validate removal from all private projections.

### 29.4 Local-data deletion

Check:

- Database.
- WAL.
- Caches.
- Temporary files.
- Keychain.
- App Group.
- Spotlight.
- Notifications.

### 29.5 Malicious input

- Oversized deep link.
- Cross-account ID.
- Malformed import.
- Unsafe Markdown.
- CSV formula.
- Prompt injection.

### 29.6 Privacy markers

Run marker scanning against generated logs and diagnostics.

### 29.7 Release gate

All high-severity security and privacy tests must pass with no quarantine.

---

## 30. Localization tests

### 30.1 Pseudolocalization

Use expanded strings to detect:

- Toolbar overflow.
- Truncation.
- Fixed-width assumptions.
- Forms with detached labels.

### 30.2 Unicode

Test:

- Vietnamese diacritics.
- Hanzi.
- Pinyin tone marks.
- Combining characters.
- Emoji in user notes.
- Right-to-left text inside imported or user-authored content.

### 30.3 Date and number formatting

Test:

- 12-hour and 24-hour time.
- Different date orders.
- Different first weekdays.
- Relative dates.
- Decimal formatting.

### 30.4 Search normalization

Ensure normalization does not destroy semantically meaningful distinctions.

---

## 31. Manual exploratory testing

### 31.1 Session-based testing

Each exploratory session records:

- Charter.
- Build.
- Environment.
- Duration.
- Findings.
- Follow-up.

### 31.2 Suggested charters

- Power-user keyboard workflow.
- Multi-window usage.
- Offline workday.
- Account switching.
- Chinese-learning workflow.
- Large import.
- Multiple-display Quick Lookup.
- Screen-sharing privacy.
- Accessibility with VoiceOver.

### 31.3 Dogfooding

Internal users should test:

- Realistic large collections.
- Daily Review.
- Menu bar over several days.
- Quick Lookup in common apps.
- Sleep and wake.
- Network transitions.

Do not collect private dogfood content without consent.

---

## 32. Continuous integration

Recommended pipeline:

```text
1. Repository validation
2. Secret and dependency scan
3. Project generation
4. Compile shared modules
5. Compile iOS target
6. Compile macOS target
7. Unit tests
8. Repository and migration tests
9. Integration tests
10. Selected UI tests
11. Accessibility checks
12. Packaging validation
```

### 32.1 Pull-request pipeline

Required:

- Build.
- Unit tests.
- Fast repository tests.
- Static checks.
- Secret scan.

### 32.2 Main-branch pipeline

Adds:

- Integration tests.
- Migration matrix.
- UI smoke tests.
- Snapshot verification.

### 32.3 Nightly pipeline

Adds:

- Large datasets.
- Extended UI suite.
- Performance tests.
- Fuzz tests.
- Energy sampling.
- Local backend end-to-end tests.

### 32.4 Release-candidate pipeline

Adds:

- Full clean build.
- Signing.
- Entitlement inspection.
- Notarization.
- Upgrade from prior release.
- Fresh install.
- Sign-out cleanup.
- Security marker scan.

---

## 33. CI artifacts

On failure, retain:

- Test report.
- Sanitized logs.
- Screenshots from synthetic UI fixtures.
- Crash report.
- Performance metrics.
- Generated project diagnostics.

Do not retain:

- Credentials.
- Production configuration.
- Real user exports.
- Raw private prompts.

Artifact retention must be bounded.

---

## 34. Flaky-test policy

### 34.1 Definition

A test is flaky when identical code and environment can produce both pass and fail without a legitimate behavioral difference.

### 34.2 Response

1. Create an issue.
2. Assign owner.
3. Identify source.
4. Fix promptly.
5. Quarantine only if necessary.

### 34.3 Quarantine

Quarantined tests:

- Run separately.
- Remain visible.
- Have expiry date.
- Do not silently count as passing.

### 34.4 Common causes

- Fixed sleeps.
- Shared global state.
- Real network.
- Uncontrolled clock.
- Random IDs.
- UI focus assumptions.
- Account-state leakage.

### 34.5 Retry

One diagnostic retry may help classify infrastructure instability.

Repeated retries must not be used as a substitute for fixing the test.

---

## 35. Test-data lifecycle

### 35.1 Isolation

Each test receives:

- Unique temporary directory.
- Unique synthetic account.
- Independent database.
- Reset dependency graph.

### 35.2 Cleanup

Cleanup occurs:

- After test.
- On suite startup for abandoned prior artifacts.

### 35.3 Reproducibility

Failures should record:

- Fixture name.
- Seed.
- Clock value.
- Locale.
- Time zone.

### 35.4 Shared test accounts

Avoid shared mutable staging accounts for parallel tests.

Use disposable accounts or deterministic reset.

---

## 36. Coverage expectations

Coverage percentage alone is not a release criterion.

Required behavioral coverage:

- Every domain rule.
- Every mutating use case.
- Every migration.
- Every sync conflict policy.
- Every canonical deep-link route.
- Every security cleanup path.
- Every P0 user journey.

High-risk modules should have stronger branch coverage:

- Authentication.
- Review events.
- Mutation queue.
- Database migration.
- Deep-link parsing.
- Import parsing.
- AI structured validation.

---

## 37. Defect severity

### Severity 0 — Release blocker

Examples:

- Credential exposure.
- Cross-account data exposure.
- Permanent data loss.
- Duplicate review scheduling.
- Application cannot launch.

### Severity 1 — Critical

Examples:

- Core Review unusable.
- Sign in broadly broken.
- Offline mutations lost.
- Main Vocabulary inaccessible.
- Accessibility blocker in P0 workflow.

### Severity 2 — Major

Examples:

- Important feature failure with workaround.
- Incorrect count.
- Import partial failure not reported.
- Quick Lookup unreliable in common configuration.

### Severity 3 — Minor

Examples:

- Visual defect.
- Low-impact copy issue.
- Edge-case shortcut conflict.

Severity criteria should include:

- User impact.
- Data risk.
- Privacy risk.
- Reproducibility.
- Workaround.

---

## 38. Release quality gates

The release candidate must satisfy:

### Build

- [ ] Clean macOS build succeeds.
- [ ] Clean iOS build remains successful.
- [ ] Project generation is reproducible.
- [ ] No unexpected warnings in critical modules.

### Unit and integration

- [ ] Required suites pass.
- [ ] No release-critical test is quarantined.
- [ ] Migration matrix passes.
- [ ] Review idempotency passes against backend contract.

### UI

- [ ] P0 journeys pass.
- [ ] Keyboard-only workflows pass.
- [ ] Window restoration passes.
- [ ] Quick Lookup and menu bar lifecycle pass.

### Accessibility

- [ ] VoiceOver P0 matrix passes.
- [ ] Larger text passes.
- [ ] Increased Contrast passes.
- [ ] Reduce Motion passes.
- [ ] No pointer-only P0 action remains.

### Performance

- [ ] Large-library targets pass.
- [ ] Quick Lookup targets pass.
- [ ] Sync and import stay within agreed thresholds.
- [ ] No critical memory regression.

### Energy

- [ ] No continuous idle polling.
- [ ] Menu bar idle profile is acceptable.
- [ ] Global shortcut listener is efficient.

### Security and privacy

- [ ] Secret scan passes.
- [ ] Account isolation passes.
- [ ] Sign-out cleanup passes.
- [ ] Diagnostics marker scan passes.
- [ ] Entitlements are reviewed.
- [ ] Notarization succeeds.

### Product

- [ ] Requirement traceability is current.
- [ ] Known limitations are documented.
- [ ] Release notes are prepared.
- [ ] Blocking open decisions are resolved.

---

## 39. Production validation

### 39.1 Post-release indicators

Monitor only privacy-safe signals:

- Launch failure rate.
- Authentication error category.
- Sync failure category.
- Migration failure.
- Crash-free sessions.
- Review submission errors.
- Import failure categories.

### 39.2 Canary release

If distribution permits:

- Release to a limited audience.
- Validate migrations.
- Validate signing and entitlements.
- Validate background behavior.

### 39.3 Rollback

Prepare:

- Release withdrawal process.
- Minimum supported version policy.
- Backend compatibility strategy.
- Database forward-compatibility plan.

### 39.4 Emergency disablement

Feature flags may disable:

- Quick Lookup shortcut.
- AI provider integration.
- Offline writes.
- Spotlight.
- Interactive widgets.

Core local data must remain accessible when an optional integration is disabled.

---

## 40. Requirement traceability

This test strategy validates:

- `APP-*`: scenes, windows, commands, restoration, and lifecycle.
- `AUTH-*`: sign in, refresh, sign out, and account isolation.
- `TODAY-*`: daily-state and recommendation matrices.
- `VOC-*`: table, search, filters, selection, editing, and batch actions.
- `LANG-*`: English, Chinese, pinyin, TTS, and Hanzi behavior.
- `REV-*`: reveal, grade, idempotency, pause, resume, and offline review.
- `QUICK-*`: global panel, search, save, focus, and multi-display behavior.
- `MENU-*`: popover, Mini Review, lifecycle, and energy.
- `AI-*`: context, streaming, validation, cancellation, and privacy.
- `CAP-*`: parsing, OCR, duplicates, import, export, and security.
- `SYS-*`: App Intents, Spotlight, widgets, Services, and notifications.
- `SYNC-*`: queue, conflict, cursor, persistence, and recovery.
- `SEC-*`: credentials, privacy, cleanup, diagnostics, and malicious input.
- `A11Y-*`: keyboard, VoiceOver, contrast, larger text, and reduced motion.
- `PERF-*`: search, large collections, sync, import, and energy.
- `REL-*`: crash recovery, migration, retry, and exactly-once behavior.

---

## 41. Acceptance scenarios

### Scenario A — Pull request

1. Change shared networking code.
2. Open a pull request.

Expected:

- iOS and macOS compile.
- Unit and transport tests run.
- Secret scan runs.

### Scenario B — Migration

1. Install prior database fixture.
2. Launch release candidate.

Expected:

- Migration succeeds.
- Pending work remains.
- Vocabulary and review state remain correct.

### Scenario C — Offline workday

1. Synchronize.
2. Disconnect.
3. Search, edit notes, review, and complete cached practice.
4. Restart.
5. Reconnect.

Expected:

- Local work survives.
- Operations synchronize once.
- No duplicate review occurs.

### Scenario D — Account switch

1. Use Account A across all system surfaces.
2. Switch to Account B.

Expected:

- No Account A data remains visible or actionable.

### Scenario E — Quick Lookup

1. Use different displays and Spaces.
2. Perform rapid queries.
3. Save offline.

Expected:

- Correct placement.
- No stale results.
- One saved card.

### Scenario F — Accessibility

1. Enable VoiceOver and larger text.
2. Complete Add Word and Review using keyboard.

Expected:

- No pointer is required.
- Labels, focus, and progress are understandable.

### Scenario G — Diagnostics

1. Use synthetic private markers.
2. Trigger failures.
3. Export diagnostics.

Expected:

- Private markers are absent.
- Operational details remain useful.

### Scenario H — Large library

1. Load 50,000 synthetic cards.
2. Search, sort, filter, and scroll.

Expected:

- UI remains responsive within agreed stress thresholds.
- Selection remains stable.

### Scenario I — AI malformed response

1. Return invalid drill structure.

Expected:

- Invalid controls are not rendered.
- Repair or Regenerate is offered.

### Scenario J — Release packaging

1. Archive release build.
2. Sign and notarize.
3. Install cleanly.
4. Upgrade prior build.

Expected:

- Both install paths work.
- Entitlements match review.
- Data remains intact.

---

## 42. Decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Shared domain and repository behavior uses shared contract tests.
2. Time, UUIDs, randomness, locale, and connectivity are injectable in tests.
3. Production network services are never required by unit tests.
4. Every released database schema receives a migration fixture.
5. Offline review requires passing exactly-once tests against the actual backend.
6. P0 workflows require keyboard and VoiceOver validation.
7. Quick Lookup receives dedicated multiple-display and Spaces coverage.
8. Menu bar idle energy is a release metric.
9. AI structured content is validated before UI rendering.
10. Import and route parsers receive fuzz and boundary testing.
11. Security diagnostics use synthetic marker scanning.
12. Flaky tests require ownership and expiry when quarantined.
13. Pull requests compile both Apple platform targets.
14. Release candidates must pass clean install and upgrade testing.

---

## 43. Open questions

1. Which XCTest and Swift Testing combinations will be used?
2. Which macOS versions will CI exercise?
3. Which Mac architectures require native CI coverage?
4. Is a dedicated physical Mac test pool available?
5. Which local backend setup is fastest and most deterministic?
6. How are disposable staging accounts provisioned?
7. Which snapshot-testing framework, if any, will be adopted?
8. Which accessibility-audit tooling is available in CI?
9. What are the final Quick Lookup latency thresholds?
10. What are the acceptable menu bar idle wakeup and CPU targets?
11. Which performance thresholds can be stable across CI hardware?
12. How will multiple-display behavior be automated versus tested manually?
13. Which fuzzing tooling will be used for Swift parsers?
14. Which dependency and secret scanners will be mandatory?
15. What code-coverage reporting is required?
16. How long will CI artifacts be retained?
17. Which UI tests run on every pull request?
18. What staging data-reset API is needed?
19. Which production health signals are essential and privacy-safe?
20. What is the supported rollback strategy after a database migration?

---

## 44. Definition of done

The testing and quality system is ready when:

- Test targets exist for shared and macOS-specific code.
- Deterministic test dependencies are available.
- Synthetic fixture builders cover English and Chinese data.
- Repository contract suites run against real persistence.
- Every migration has automated coverage.
- Networking and token-refresh tests are deterministic.
- Synchronization failure injection works.
- Review idempotency tests pass.
- Critical UI journeys are automated.
- Quick Lookup and menu bar have macOS-specific validation.
- Accessibility matrices are documented and executed.
- Large-library, sync, import, and energy benchmarks exist.
- Security marker scans run automatically.
- CI builds both iOS and macOS.
- Flaky-test policy is enforced.
- Release gates are represented in the release checklist.

---

## 45. Next document

The next document should be:

```text
docs/macos-roadmap.md
```

It should define:

- Delivery phases.
- Dependencies.
- Backend blockers.
- macOS target bootstrap.
- Shared-code extraction.
- Prototype scope.
- Offline milestones.
- Quick Lookup milestone.
- Menu bar and system integrations.
- AI and import milestones.
- Testing and security gates.
- Release criteria.
- Risks.
- Resourcing assumptions.
- Decision checkpoints.
