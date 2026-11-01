# Voca for macOS — Delivery Roadmap

> Phased implementation plan, dependencies, technical gates, backend blockers, risks, staffing assumptions, release criteria, and decision checkpoints for delivering the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Delivery and Implementation Roadmap
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related testing strategy:** [`macos-testing.md`](macos-testing.md)
- **Related security specification:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document converts the macOS product and architecture specifications into an executable implementation plan.

It defines:

- Delivery phases.
- Phase objectives.
- Dependencies.
- Entry and exit criteria.
- Backend blockers.
- Shared-code extraction.
- macOS target bootstrap.
- Prototype scope.
- Offline milestones.
- Quick Lookup and menu bar milestones.
- System integrations.
- Practice, AI, and import milestones.
- Testing and security gates.
- Resourcing assumptions.
- Decision checkpoints.
- Release criteria.
- Major risks and mitigations.

The roadmap is intentionally capability-driven rather than calendar-driven. Dates should be assigned only after:

- Backend capability audit.
- Existing iOS code audit.
- Persistence decision.
- Team capacity review.
- Signing and distribution decision.

---

## 2. Delivery principles

### ROAD-PRN-001 — Keep iOS releasable

The existing iOS application must continue to build and operate throughout macOS development.

### ROAD-PRN-002 — Prove boundaries before reorganizing the repository

Add the first macOS target inside the current Apple project before moving the repository from `ios/` to `apple/`.

### ROAD-PRN-003 — Deliver vertical slices

Each milestone should produce a demonstrable user journey rather than only infrastructure.

### ROAD-PRN-004 — Build the Mac product, not an enlarged iPhone application

Shared code should focus on:

- Domain models.
- Networking.
- Authentication.
- Services.
- Persistence.
- Synchronization.

macOS should own:

- Navigation.
- Windows.
- Toolbar.
- Table.
- Inspector.
- Menus.
- System integrations.

### ROAD-PRN-005 — Offline writes follow idempotency

Do not ship offline review or high-risk offline mutations before backend idempotency and reconciliation behavior are verified.

### ROAD-PRN-006 — Privacy precedes ambient integration

Menu bar, widgets, Spotlight, Services, and notifications must not ship before signed-out cleanup and account-isolation tests pass.

### ROAD-PRN-007 — Optional systems cannot block the core app

AI, OCR, widgets, Spotlight, menu bar, and Quick Lookup failures must not make Vocabulary or Review unusable.

### ROAD-PRN-008 — Every phase removes uncertainty

Each phase should answer specific product or technical questions before the next investment begins.

---

## 3. Roadmap summary

```text
Phase 0  Audit and decisions
Phase 1  macOS target and application shell
Phase 2  Shared authentication and networking
Phase 3  Vocabulary vertical slice
Phase 4  Review vertical slice
Phase 5  Local persistence and offline reads
Phase 6  Mutation queue and synchronization
Phase 7  Quick Lookup
Phase 8  Today and menu bar
Phase 9  System integrations
Phase 10 Practice and AI
Phase 11 Import and capture
Phase 12 Hardening, beta, and release
Phase 13 Post-release expansion
```

### 3.1 Critical path

```text
Audit
→ macOS target
→ shared authentication
→ shared networking
→ vocabulary
→ review
→ persistence
→ idempotent sync
→ Quick Lookup
→ hardening
→ release
```

### 3.2 Parallel tracks

Potential parallel work:

```text
Product and design
Backend capability work
Shared-code extraction
macOS presentation
Persistence and synchronization
Testing and CI
Security and release engineering
```

---

## 4. Release train

Recommended release stages:

```text
Technical Prototype
Internal Alpha
Private Beta
Release Candidate
Public Release
Post-release Differentiation
```

### 4.1 Technical Prototype

Purpose:

- Validate target creation.
- Validate shared-code compilation.
- Validate native navigation and table behavior.

Not intended for daily use.

### 4.2 Internal Alpha

Purpose:

- Complete core vocabulary and review journeys.
- Start daily dogfooding.
- Find architecture and lifecycle issues.

### 4.3 Private Beta

Purpose:

- Validate realistic data.
- Validate multiple Macs and accounts.
- Validate migration and offline behavior.
- Collect qualitative feedback.

### 4.4 Release Candidate

Purpose:

- Freeze scope.
- Resolve release blockers.
- Validate signing, notarization, migration, privacy, performance, and support readiness.

### 4.5 Public Release

Purpose:

- Deliver reliable vocabulary and review workflows.
- Include selected macOS differentiators that satisfy release gates.

---

## 5. Phase 0 — Audit and decisions

### Objective

Understand the existing codebase and resolve decisions that affect every later phase.

### 5.1 Existing-code audit

Inspect:

- `ios/project.yml`.
- Application entry and root flow.
- Authentication store.
- Keychain store.
- Token manager.
- API client.
- API errors and envelopes.
- Card models.
- Study models.
- Services.
- Audio player.
- TTS service.
- Widget shared store.
- Feature-state patterns.
- iOS-only imports.
- Backend API contracts.

### 5.2 Reuse classification

Classify every relevant component:

```text
Reusable unchanged
Reusable after cleanup
Platform-specific
Replace
Backend-dependent
Unknown
```

### 5.3 Required architecture decisions

Resolve:

- Minimum macOS deployment target.
- Xcode and Swift version.
- macOS bundle identifier.
- Distribution channel.
- App Sandbox.
- Persistence technology.
- Initial repository placement.
- Local Swift package timing.
- Keychain access-group policy.
- App Group identifiers.
- Analytics and crash-report tooling.

### 5.4 Backend capability audit

Confirm:

- Stable entity IDs.
- Entity revisions.
- Incremental change feed.
- Mutation idempotency.
- Review-event idempotency.
- Soft deletion and restore.
- Batch card creation.
- Due-summary endpoint.
- AI streaming format.
- TTS behavior.

### 5.5 CI audit

Confirm:

- macOS build runner.
- Signing environment.
- XcodeGen version.
- iOS regression build.
- Test result retention.
- Secret management.

### 5.6 Deliverables

- Reuse audit.
- Backend capability matrix.
- Initial architecture decision records.
- Risk register.
- Prototype implementation plan.
- Initial test-target plan.

### 5.7 Exit criteria

- No unknown high-risk dependency blocks target creation.
- Persistence decision has an owner and deadline.
- Distribution and signing direction are documented.
- Backend blockers are assigned.
- iOS baseline build is recorded.

---

## 6. Phase 1 — macOS target and application shell

### Objective

Create a buildable native macOS application without disrupting iOS.

### 6.1 Project changes

Add:

```text
VocaMac
VocaMacTests
VocaMacUITests
```

Initial source location:

```text
ios/VocaMac/
```

### 6.2 Application shell

Implement:

- macOS app entry.
- Authentication phase root.
- Main workspace scene.
- Settings scene.
- Typed route foundation.
- Scene coordinator.
- Basic commands.
- Window sizing and restoration.

### 6.3 Main workspace

Implement:

- `NavigationSplitView`.
- Sidebar.
- Today placeholder.
- Vocabulary placeholder.
- Review placeholder.
- Settings entry.
- Toolbar foundation.

### 6.4 Design foundation

Implement:

- Semantic colors.
- Typography tokens.
- Spacing tokens.
- Layout metrics.
- Core loading, empty, and error states.
- Preview catalog.

### 6.5 Test foundation

Add:

- App launch test.
- Sidebar navigation test.
- Settings-open test.
- Window minimum-size test.
- Shared-module compilation on iOS and macOS.

### 6.6 Exit criteria

- iOS target builds.
- macOS target builds.
- macOS application launches.
- Main workspace and Settings open.
- Typed routes compile.
- No accidental UIKit dependency exists in macOS target.
- CI runs both platform builds.

### 6.7 Decision checkpoint

Review:

- Source boundaries.
- Root navigation.
- Window model.
- Whether local Swift-package extraction should begin.

---

## 7. Phase 2 — Shared authentication and networking

### Objective

Sign in on macOS and load authenticated data through shared services.

### 7.1 Authentication extraction

Refactor as necessary:

- Auth session model.
- Keychain protocol.
- Credential store.
- Token refresh coordinator.
- Account bootstrap.
- Sign-out behavior.

### 7.2 Networking extraction

Refactor:

- API transport.
- Request definitions.
- Authentication middleware.
- Envelope decoding.
- Error mapping.
- Retry rules.
- Event-stream transport.

### 7.3 macOS authentication UI

Implement:

- Sign in.
- Loading state.
- Invalid credentials.
- Server unavailable.
- Reauthentication.
- Sign out.

### 7.4 Security controls

Verify:

- Password is not persisted.
- Tokens are stored only through Keychain.
- Logs redact authorization values.
- Server identity partitions credentials.

### 7.5 Tests

- Concurrent refresh.
- Refresh failure.
- Sign-out cleanup.
- Wrong-server credentials.
- Authentication UI flow.
- macOS relaunch session restoration.

### 7.6 Exit criteria

- macOS signs in to a supported backend.
- Token refresh is serialized.
- Authenticated request succeeds.
- Sign out removes credentials.
- iOS authentication regression suite passes.
- No secret appears in logs or diagnostics.

### 7.7 Decision checkpoint

Review:

- Shared package boundaries.
- Custom-server policy.
- Signed-out local-data policy.

---

## 8. Phase 3 — Vocabulary vertical slice

### Objective

Deliver a useful native macOS vocabulary-management workflow.

### 8.1 Scope

Implement:

- All Words collection.
- English and Chinese language selection.
- Table presentation.
- Search.
- Sort.
- Single selection.
- Word detail.
- Inspector foundation.
- Pronunciation.
- Add Word.
- Favorite.

### 8.2 Optional alpha scope

Add if foundation is stable:

- Tags.
- Personal notes.
- Multi-selection.
- Batch favorite.
- Context menus.
- Separate word window.

### 8.3 Architecture

Introduce:

- Shared vocabulary domain model.
- Vocabulary repository protocol.
- Remote-backed repository.
- Lookup use case.
- Add Word use case.
- Speech protocol.

### 8.4 UX validation

Validate:

- Table density.
- Default columns.
- Detail width.
- Inspector behavior.
- Chinese Hanzi and pinyin hierarchy.
- Toolbar overflow.

### 8.5 Tests

- Search cancellation.
- Stable selection.
- Add duplicate.
- Existing shared dictionary result.
- Pronunciation.
- English and Chinese rows.
- Keyboard-only workflow.
- 10,000-card synthetic table.

### 8.6 Exit criteria

- User can search, inspect, pronounce, and add a word.
- Duplicate card creation is prevented.
- English and Chinese content render correctly.
- Table remains responsive with realistic data.
- Main actions have menu and keyboard equivalents.
- VoiceOver can navigate the primary workflow.

### 8.7 Internal Alpha milestone

This phase may produce the first internal alpha if authentication and data loading are sufficiently stable.

---

## 9. Phase 4 — Review vertical slice

### Objective

Deliver reliable FSRS review on macOS.

### 9.1 Scope

Implement:

- Review overview.
- Due count.
- Stable session identity.
- Prompt state.
- Reveal.
- Again, Hard, Good, Easy.
- Keyboard shortcuts.
- Pronunciation.
- Progress.
- Pause.
- Resume.
- Summary.

### 9.2 Focus window

Implement:

- Dedicated Review scene.
- Full-screen support.
- Stable grade controls.
- Window-close pause.

### 9.3 Domain behavior

Introduce:

- Review repository.
- Review session model.
- Review event model.
- Submit Grade use case.
- Session recovery.

### 9.4 Online-first limit

If backend idempotency is not yet confirmed:

- Ship internal review as online-only.
- Persist session recovery locally.
- Do not advertise robust offline review.

### 9.5 Tests

- Grade disabled before reveal.
- Rapid repeated key input.
- Pause and resume.
- Relaunch recovery.
- English card.
- Chinese card.
- Audio failure.
- Session summary.

### 9.6 Exit criteria

- One grade action creates one local review event.
- Session progress survives ordinary window closure.
- Keyboard-only workflow completes.
- Summary is accurate.
- Existing iOS grade semantics remain compatible.

### 9.7 Decision checkpoint

Review:

- Backend idempotency.
- Offline-review feasibility.
- Grade-undo feasibility.
- Review-window behavior.

---

## 10. Phase 5 — Local persistence and offline reads

### Objective

Make previously synchronized vocabulary available immediately and offline.

### 10.1 Persistence

Implement:

- Account-scoped local store.
- Schema versioning.
- Vocabulary records.
- Study-state records.
- Tags and relationships.
- Review sessions.
- Sync metadata.
- Full-text search.

### 10.2 Repository migration

Change read path:

```text
Remote-backed repository
→ local-read repository with remote refresh
```

### 10.3 Bootstrap

Implement:

- Initial account download.
- Transactional batch apply.
- Progress.
- Resume or restart.

### 10.4 Offline behavior

Enable:

- Vocabulary browse.
- Search.
- Word detail.
- Cached pronunciation.
- Cached Today snapshot foundation.

### 10.5 Migration strategy

Add:

- Fresh schema.
- Prior-schema fixture process.
- Backup and repair foundation.

### 10.6 Tests

- Account isolation.
- Search normalization.
- Large database.
- Bootstrap interruption.
- Offline relaunch.
- Migration.
- Corruption detection.

### 10.7 Exit criteria

- Previously synchronized vocabulary loads without network.
- Local search meets performance target.
- Database is account-isolated.
- Initial bootstrap is recoverable.
- Migration suite exists.
- Local storage contains no credentials.

---

## 11. Phase 6 — Mutation queue and synchronization

### Objective

Support durable offline metadata changes and safe remote reconciliation.

### 11.1 Mutation queue

Implement:

- Stable operation IDs.
- Queue states.
- Dependency handling.
- Safe coalescing.
- Retry and backoff.
- Permanent-failure state.
- Activity view.

### 11.2 Initial offline writes

Enable in order:

1. Favorite.
2. Tags.
3. Personal notes.
4. Level where supported.
5. Add Word.
6. Move to Trash where backend supports it.

### 11.3 Incremental pull

Implement:

- Sync cursor.
- Paginated changes.
- Transactional page apply.
- Tombstones.
- Full resynchronization.

### 11.4 Conflict policies

Implement:

- Favorite latest intent.
- Tag set operations.
- Personal-note conflict preservation.
- Remote deletion with local work.

### 11.5 Offline review

Enable only after:

- Backend accepts stable idempotency keys.
- Duplicate submission returns prior result.
- Event ordering is defined.
- Reconciliation tests pass.

### 11.6 Tests

- Restart with pending queue.
- Timeout before server receipt.
- Timeout after acceptance.
- Note conflict.
- Remote deletion.
- Account switch.
- Cursor failure.
- Offline review.

### 11.7 Exit criteria

- Supported offline changes survive restart.
- Retry does not duplicate accepted operations.
- Personal notes are never silently overwritten.
- Activity exposes actionable failures.
- Incremental pull is restart-safe.
- Offline review ships only if exactly-once tests pass.

### 11.8 Private Beta prerequisite

The application should not enter private beta with advertised offline writes until this phase passes its reliability gates.

---

## 12. Phase 7 — Quick Lookup

### Objective

Deliver the primary macOS differentiator.

### 12.1 Scope

Implement:

- Global configurable shortcut.
- Single floating panel.
- Active-display placement.
- Current-Space behavior.
- Local lookup.
- Remote fallback.
- English and Chinese result layouts.
- Pronunciation.
- Add to Voca.
- Existing-card state.
- Open Detail.
- Ask Assistant route.

### 12.2 Privacy scope

Add:

- Clipboard suggestion preference.
- Local clipboard validation.
- No automatic upload.
- Secret-like-content suppression.

### 12.3 Lifecycle

Support:

- Main window open.
- Main window closed.
- Multiple displays.
- Full-screen application.
- Account signed out.
- Offline state.

### 12.4 Performance targets

Validate:

- Panel ready for typing within agreed target.
- Local exact result within agreed target.
- Shortcut listener has acceptable idle energy use.

### 12.5 Tests

- One panel only.
- Focus restoration.
- Stale result suppression.
- Multiple displays.
- Different Spaces.
- Offline save.
- Clipboard privacy.
- VoiceOver.

### 12.6 Exit criteria

- Quick Lookup opens reliably from another app.
- Correct display and focus behavior pass.
- Local results do not require network.
- Add Word uses the shared idempotent use case.
- Query and clipboard text are absent from logs and analytics.
- Accessibility and performance targets pass.

### 12.7 Decision checkpoint

Review:

- Default shortcut.
- Outside-click dismissal.
- Clipboard-suggestion default.
- Open Detail window policy.

---

## 13. Phase 8 — Today and menu bar

### Objective

Deliver a coherent daily-learning entry point and ambient companion.

### 13.1 Today scope

Implement:

- Primary daily action.
- Due summary.
- Daily goal.
- Active-session continuation.
- Difficult words.
- Recent vocabulary.
- Weekly summary.
- Deterministic recommendation.

### 13.2 Menu bar scope

Implement:

- Optional menu bar item.
- Configurable due count.
- Cached summary.
- Quick Lookup.
- Quick Add through Quick Lookup.
- Open Voca.
- Settings.
- Quit.

### 13.3 Mini Review

Implement after review idempotency:

- Five-card session.
- Reveal.
- Four grades.
- Pronunciation.
- Pending-sync state.

### 13.4 Launch at login

Implement:

- Optional launch.
- Background start.
- No automatic main-window opening.

### 13.5 Privacy

Implement:

- Hide menu-bar vocabulary.
- Signed-out cleanup.
- Private account switch.

### 13.6 Energy

Profile:

- Idle application.
- Menu bar with main window closed.
- Periodic refresh.
- Shortcut listener.

### 13.7 Exit criteria

- Today chooses the correct primary action.
- Daily goal does not double-count retries.
- Menu bar works with no main window.
- Mini Review cannot conflict with a full active session.
- Signed-out menu bar contains no prior private data.
- Launch at login works.
- Idle energy is within agreed target.

---

## 14. Phase 9 — System integrations

### Objective

Make Voca available through native macOS surfaces.

### 14.1 Delivery order

Recommended:

1. Typed deep links.
2. App Intents.
3. Spotlight.
4. Notifications.
5. Widgets.
6. macOS Services.

### 14.2 App Intents

Initial:

- Show Due Count.
- Look Up Word.
- Add Word.
- Pronounce Word.
- Start Review.

### 14.3 Spotlight

Index:

- Saved word.
- Pronunciation or pinyin.
- Concise meaning.
- Canonical deep link.

### 14.4 Notifications

Implement:

- Review reminder.
- Pause Today.
- Remind Later.
- Private-content mode.

### 14.5 Widgets

Initial:

- Due Count.
- Word of the Day.
- Today Summary.

Use:

- Versioned App Group snapshot.

### 14.6 Services

Initial:

- Look Up in Voca.
- Add to Voca.
- Explain with Voca.

### 14.7 Exit criteria

- All shipped integrations use shared use cases.
- Signed-out cleanup removes private projections.
- Widgets do not access broad credentials.
- Spotlight excludes notes and AI conversations.
- Selected text is not uploaded automatically.
- Deep-link security tests pass.

---

## 15. Phase 10 — Practice and AI

### Objective

Deliver contextual practice grounded in the user's vocabulary.

### 15.1 Initial practice scope

Recommended:

- Multiple-choice drills.
- Reading comprehension.
- One productive writing activity.
- Word comparison.

### 15.2 Assistant scope

Implement:

- Conversation list.
- Context inspector.
- Explain.
- Compare.
- Examples.
- Correct Sentence.
- Streaming.
- Stop.
- Retry.

### 15.3 Conversation scope

Implement after core Assistant is stable:

- Scenario setup.
- Text turns.
- Correction timing.
- TTS.
- Summary.

Microphone input may be deferred.

### 15.4 Validation

Implement:

- Structured-output schema.
- Exercise validation.
- Bounded repair.
- Generated-content labeling.

### 15.5 Privacy

Implement:

- Personal notes excluded by default.
- Long-context preview.
- Provider identity.
- Keychain provider credentials.
- No prompt content in logs.

### 15.6 Exit criteria

- Practice uses visible vocabulary sources.
- Generated exercise structure validates.
- Practice does not silently alter FSRS.
- Streaming can be stopped.
- User drafts survive failure.
- AI transmission is explicit.
- Provider keys remain in Keychain.
- Accessibility tests pass.

---

## 16. Phase 11 — Import and capture

### Objective

Convert external content into reviewed vocabulary candidates.

### 16.1 Delivery order

Recommended:

1. Plain text.
2. CSV.
3. Voca JSON.
4. Image OCR.
5. PDF extraction.
6. Scanned-PDF OCR.
7. AI enrichment.
8. Export.

### 16.2 Core scope

Implement:

- Dedicated Import window.
- Job lifecycle.
- Candidate table.
- Language detection.
- Duplicate classification.
- Candidate editing.
- Batch commit.
- Partial summary.

### 16.3 File security

Implement:

- Security-scoped access.
- Size limits.
- Temporary-file retention.
- Malformed-input handling.
- CSV injection mitigation.

### 16.4 AI enrichment

Enable only after:

- Transmission preview.
- Provider selection.
- Candidate-level payload minimization.
- Prompt-injection protections.

### 16.5 Exit criteria

- No multi-item source saves before confirmation.
- OCR and extraction run locally by default.
- Duplicate classification is accurate.
- Large jobs can cancel and recover.
- Partial commit does not duplicate on retry.
- Temporary files are cleaned.
- Export privacy defaults pass.

---

## 17. Phase 12 — Hardening, beta, and release

### Objective

Turn implemented capability into a releasable, supportable product.

### 17.1 Scope freeze

At release-candidate entry:

- No new major feature.
- Only blocker fixes, critical usability fixes, performance work, security work, and documentation updates.

### 17.2 Reliability

Complete:

- Migration matrix.
- Corruption recovery.
- Offline workday tests.
- Account-switch tests.
- Sleep and wake.
- Time-zone changes.
- Network transitions.
- Crash recovery.

### 17.3 Accessibility

Complete:

- Keyboard matrix.
- VoiceOver matrix.
- Larger text.
- Increased Contrast.
- Reduce Motion.

### 17.4 Performance

Complete:

- 10,000-card normal dataset.
- 50,000-card stress dataset.
- Large sync.
- Quick Lookup latency.
- Large import.
- AI conversation memory.

### 17.5 Energy

Complete:

- Idle app.
- Menu bar mode.
- Shortcut listener.
- Periodic refresh.
- Low Power Mode.

### 17.6 Security

Complete:

- Secret scan.
- Account isolation.
- Sign-out cleanup.
- Local-data removal.
- Diagnostics marker scan.
- Entitlement review.
- Dependency review.

### 17.7 Packaging

Complete:

- Release configuration.
- Signing.
- Entitlements.
- Notarization.
- Clean install.
- Upgrade.
- Uninstall guidance.
- Privacy strings.
- Crash and support setup.

### 17.8 Documentation

Complete:

- User help.
- Privacy explanation.
- Offline limitations.
- Keyboard shortcuts.
- Known issues.
- Support diagnostics procedure.
- Release notes.

### 17.9 Exit criteria

- All release gates in `macos-testing.md` pass.
- All release security gates pass.
- No Severity 0 or Severity 1 defect remains.
- Critical backend contracts are verified.
- Signing and notarization pass.
- Clean install and upgrade pass.
- Rollback or release-withdrawal plan exists.

---

## 18. Phase 13 — Post-release expansion

Potential priorities:

- Interactive review widgets.
- Microphone conversation practice.
- Advanced Hanzi writing.
- Synced Assistant history.
- Advanced Smart Lists.
- Anki import adapter.
- Share Extension.
- Browser capture.
- Additional Insights.
- Multiple account support.
- Team or enterprise configuration.
- Local-model experimentation.

Each feature requires:

- Clear user value.
- Privacy review.
- Performance review.
- Dependency impact.
- Deletion and migration behavior.

---

## 19. MVP scope

Recommended minimum public release:

### Required

- Native macOS target.
- Authentication.
- Today.
- Vocabulary table.
- Search and sort.
- Word detail.
- Add Word.
- Favorite and tags.
- English and Chinese.
- Pronunciation.
- Full Review.
- Local vocabulary reads.
- Reliable synchronization.
- Quick Lookup.
- Settings.
- Keyboard navigation.
- VoiceOver support.
- Signing and notarization.

### Strongly preferred

- Personal notes.
- Multi-selection.
- Due-count menu bar.
- Launch at login.
- Spotlight.
- Basic CSV import.

### May defer

- Widgets.
- Services.
- Full Assistant.
- Conversation practice.
- PDF OCR.
- Advanced Insights.
- Interactive flashcard widgets.
- Offline FSRS review if backend idempotency is incomplete.

---

## 20. Differentiation release scope

After core reliability, the macOS differentiation release may include:

- Quick Lookup.
- Menu bar companion.
- Mini Review.
- Spotlight.
- App Intents.
- Widgets.
- Drag-and-drop capture.
- OCR.
- Practice and Assistant.

Quick Lookup should remain the first differentiation priority because it:

- Solves a Mac-specific workflow.
- Reuses Vocabulary, lookup, audio, and Add Word.
- Provides value even without the full AI feature set.

---

## 21. Backend workstream

### 21.1 Capability matrix

Track every backend dependency as:

```text
Available
Available with changes
Planned
Blocked
Not required
```

### 21.2 Highest-priority backend work

1. Stable identifiers.
2. Entity revisions.
3. Review-event idempotency.
4. Incremental synchronization.
5. Tombstones.
6. Batch card creation.
7. Due summary.
8. Streaming contracts.

### 21.3 Review idempotency contract

Required:

```text
Same operation ID
→ one accepted event
→ same authoritative result on retry
```

### 21.4 Incremental sync contract

Required:

- Cursor.
- Ordered changes.
- Tombstones.
- Transaction-safe pages.
- Cursor expiry behavior.

### 21.5 Batch mutation contract

Preferred:

- Per-item operation ID.
- Per-item result.
- Retryable flag.
- Current revision.
- Existing-entity response.

---

## 22. Shared-code workstream

### 22.1 Extraction order

Recommended:

1. Models.
2. API envelopes and errors.
3. Transport.
4. Authentication and tokens.
5. Services.
6. Repository interfaces.
7. Audio protocols.
8. Design tokens.

### 22.2 Do not share prematurely

Avoid initially sharing:

- Root app view.
- Home view.
- Toolbar.
- Tab navigation.
- Settings UI.
- Review UI.
- Vocabulary list UI.

### 22.3 Package extraction trigger

Move code into a local Swift package when:

- iOS and macOS both compile the same source.
- Dependency direction is proven.
- Tests can move with the module.
- Build-time impact is understood.

### 22.4 Repository relocation trigger

Move from `ios/` to `apple/` only when:

- macOS target is stable.
- Shared boundaries are stable.
- CI scripts are ready.
- Documentation paths can be updated.
- The move does not coincide with a major release deadline.

---

## 23. Design workstream

### 23.1 Prototype priorities

Design first:

- Main workspace.
- Vocabulary table.
- Word detail.
- Review.
- Quick Lookup.

### 23.2 Component priorities

Implement:

- Semantic tokens.
- Navigation.
- Table rows.
- Word identity.
- Pronunciation.
- Review grades.
- Loading, empty, error, and offline states.

### 23.3 Validation matrix

Every major screen should be reviewed in:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Larger text.
- English.
- Chinese.
- Narrow width.
- Wide width.

### 23.4 User validation

Prototype-test:

- Table density.
- Quick Lookup dismissal.
- Review keyboard mapping.
- Inspector behavior.
- Menu bar usefulness.

---

## 24. Test workstream

### 24.1 Phase 0–2

- Shared test target.
- Transport stubs.
- Test clock.
- Credential substitute.
- CI builds.

### 24.2 Phase 3–4

- Vocabulary state tests.
- Review idempotency foundation.
- macOS UI smoke tests.
- Accessibility identifiers.

### 24.3 Phase 5–6

- Repository contract suites.
- Migration fixtures.
- Failure injection.
- Offline matrices.

### 24.4 Phase 7–9

- AppKit bridge tests.
- Multiple-display matrix.
- Menu bar energy tests.
- Widget and Spotlight cleanup tests.

### 24.5 Phase 10–11

- AI stream fixtures.
- Structured-output validation.
- Import fuzzing.
- Malformed-file testing.

### 24.6 Phase 12

- Full release gates.
- Clean install.
- Upgrade.
- Signing.
- Notarization.
- Security marker scan.

---

## 25. Security workstream

### 25.1 Early requirements

Before prototype:

- Bundle and environment separation.
- Keychain policy.
- App Sandbox direction.
- Secret handling.

### 25.2 Before local persistence

- Account partitioning.
- Database file protection.
- Sign-out policy.
- Local-data deletion design.

### 25.3 Before AI and import

- Explicit transmission.
- Context preview.
- Temporary-file retention.
- Prompt-injection handling.
- Provider-key lifecycle.

### 25.4 Before system integrations

- App Group minimization.
- Spotlight privacy.
- Widget privacy.
- Notification privacy.
- Signed-out cleanup.

### 25.5 Before release

- Entitlement review.
- Secret scan.
- Diagnostics validation.
- Dependency review.
- Signing and notarization.

---

## 26. Resourcing assumptions

The roadmap can be executed by a small team, but duration changes significantly depending on parallel staffing.

### 26.1 Minimum team model

```text
1 Apple-platform engineer
1 backend engineer, part time
1 product and design owner, part time
1 QA or test owner, part time
```

This model requires aggressive scope control.

### 26.2 Recommended team model

```text
2 Apple-platform engineers
1 backend engineer
1 product designer
1 QA or automation engineer
1 product owner
```

### 26.3 Specialized review

Part-time specialist review:

- Accessibility.
- Security.
- Release engineering.
- Chinese-language quality.

### 26.4 Single-engineer priority

If one engineer owns the full implementation:

1. macOS target.
2. Authentication.
3. Vocabulary.
4. Review.
5. Local reads.
6. Quick Lookup.
7. Reliability and release.

Defer:

- Full AI.
- OCR.
- Widgets.
- Advanced import.

---

## 27. Dependency map

```text
Authentication
└── required by all account features

Networking
├── Vocabulary
├── Review
├── AI
└── Synchronization

Vocabulary repository
├── Today
├── Quick Lookup
├── Spotlight
├── Widgets
├── Practice
└── Import

Review repository
├── Today
├── Menu bar
├── Widgets
└── Notifications

Local persistence
├── Offline reads
├── Quick Lookup performance
├── Menu bar snapshot
├── Spotlight
└── Widgets

Idempotency
├── Offline review
├── Mini Review
└── Interactive review widgets
```

---

## 28. Decision checkpoints

### Checkpoint A — After audit

Decide:

- Persistence.
- Deployment target.
- Distribution.
- Repository placement.
- Backend blockers.

### Checkpoint B — After shell

Decide:

- Window model.
- Route model.
- Shared-package extraction.
- Main navigation.

### Checkpoint C — After Vocabulary prototype

Decide:

- Table density.
- Inspector.
- Detail window.
- Search architecture.
- Local-storage timing.

### Checkpoint D — After Review prototype

Decide:

- Offline-review feasibility.
- Focus-window behavior.
- Interval preview.
- Session-expiry policy.

### Checkpoint E — After persistence benchmark

Decide:

- Database technology remains suitable.
- Full-text strategy.
- Store partition model.
- Sync page size.

### Checkpoint F — After Quick Lookup prototype

Decide:

- Default shortcut.
- Clipboard default.
- Outside-click behavior.
- menu bar relationship.

### Checkpoint G — Before private beta

Decide:

- Final beta scope.
- Offline claims.
- Analytics.
- Crash reporting.
- Support workflow.

### Checkpoint H — Before public release

Decide:

- Release blockers.
- Known limitations.
- Minimum backend version.
- Rollback plan.

---

## 29. Risk register

### Risk 1 — Shared code remains iOS-coupled

Impact:

- macOS target accumulates conditionals or duplicated services.

Mitigation:

- Compile shared modules for both platforms early.
- Separate UI from domain behavior.
- Audit imports continuously.

### Risk 2 — Repository reorganization creates churn

Impact:

- Merge conflicts and broken scripts.

Mitigation:

- Delay `ios/` to `apple/` move.
- Use Git moves after boundaries stabilize.

### Risk 3 — Backend lacks idempotency

Impact:

- Offline review and reliable retry cannot ship safely.

Mitigation:

- Make backend idempotency a tracked blocker.
- Keep Review online-only until verified.

### Risk 4 — Persistence choice limits sync

Impact:

- Difficult migrations, slow search, or weak transactions.

Mitigation:

- Prototype realistic FTS, batch upsert, and migration before commitment.

### Risk 5 — Quick Lookup requires broad permissions

Impact:

- Privacy concerns and installation friction.

Mitigation:

- Use a permission-light global-hotkey implementation.
- Prefer Services for selected text.

### Risk 6 — Menu bar consumes excessive energy

Impact:

- Poor user trust and system experience.

Mitigation:

- Cached snapshots.
- Event-driven refresh.
- Energy tests and release gate.

### Risk 7 — AI scope delays core release

Impact:

- Reliable vocabulary and review are postponed.

Mitigation:

- Decouple AI milestone.
- Release core product first if needed.

### Risk 8 — Account switching exposes stale data

Impact:

- Severe privacy failure.

Mitigation:

- Account-scoped stores.
- Private projection cleanup.
- Release-blocking isolation tests.

### Risk 9 — macOS UI copies iOS patterns

Impact:

- Weak desktop usability.

Mitigation:

- Table, inspector, menus, commands, and multi-window prototypes.
- Mac-specific design review.

### Risk 10 — Import processing retains private data

Impact:

- Privacy and storage issues.

Mitigation:

- Retention policy.
- Temporary-file cleanup.
- Local-first processing.

### Risk 11 — Testing arrives too late

Impact:

- Architecture becomes difficult to isolate and verify.

Mitigation:

- Add test clocks, repositories, and CI in early phases.

### Risk 12 — Signing and notarization are delayed

Impact:

- Late release blockers.

Mitigation:

- Produce signed internal build before feature completion.

---

## 30. Scope-control rules

### 30.1 A feature enters a phase only when

- User value is clear.
- Dependencies are available.
- Data ownership is defined.
- Error and offline behavior are defined.
- Testing strategy exists.
- Privacy impact is reviewed.

### 30.2 A feature leaves a release when

- It blocks the critical path.
- Backend support is uncertain.
- Security behavior is unresolved.
- It lacks realistic testing.
- It duplicates a simpler native path.

### 30.3 No hidden MVP expansion

The following are separate scope items:

- Full AI Assistant.
- Conversation speech input.
- PDF OCR.
- Interactive widgets.
- Multiple accounts.
- Browser extensions.

They should not enter MVP indirectly through another feature.

---

## 31. Definition of ready

A phase is ready to begin when:

- Product behavior is documented.
- Open blockers are assigned.
- Required APIs exist or have a committed delivery path.
- Design foundation exists.
- Test environment exists.
- Security constraints are understood.
- The preceding phase's critical exit criteria pass.

---

## 32. Definition of done for a phase

A phase is complete when:

- User-facing scope works.
- Error and empty states work.
- Offline behavior matches documentation.
- Tests pass.
- Accessibility basics pass.
- Performance is measured.
- Privacy requirements pass.
- Documentation is updated.
- Known limitations are recorded.
- iOS regression build passes.

---

## 33. Public-release criteria

### Product

- Today identifies the correct primary action.
- Vocabulary supports efficient desktop management.
- Review is reliable and keyboard-first.
- English and Chinese workflows are usable.
- Quick Lookup provides a strong Mac-specific benefit.

### Reliability

- Acknowledged writes survive restart.
- Review events are not duplicated.
- Migrations preserve user data.
- Account switching does not leak content.

### Offline

- Previously synchronized vocabulary is available.
- Supported edits queue safely.
- Product copy accurately states any Review limitation.

### Accessibility

- P0 workflows work with keyboard and VoiceOver.
- Larger text, Increased Contrast, and Reduce Motion pass.

### Performance

- Large-library targets pass.
- Quick Lookup latency passes.
- Menu bar idle energy passes.

### Security

- Credentials are protected.
- Private system projections clear on sign out.
- AI and import transmission are explicit.
- Diagnostics contain no private markers.

### Distribution

- Signing succeeds.
- Notarization succeeds.
- Clean install succeeds.
- Upgrade succeeds.
- Support and rollback processes exist.

---

## 34. Success measures

Privacy-safe product measures may include:

- Successful app launches.
- Review-session completion.
- Quick Lookup invocation success.
- Lookup-to-save conversion without word content.
- Synchronization success.
- Import completion.
- Crash-free sessions.
- Accessibility defect rate.
- Support incidents by category.

Do not use:

- Vocabulary content.
- Search query.
- Personal notes.
- AI prompts or responses.
- Imported text.

as product analytics dimensions.

---

## 35. Documentation deliverables

Before implementation:

- Architecture decisions.
- Feature specifications.
- Test strategy.
- Security requirements.

Before beta:

- Setup guide.
- Known limitations.
- Offline behavior.
- Keyboard shortcuts.
- Privacy behavior.

Before release:

- User help.
- Release notes.
- Support guide.
- Diagnostics guide.
- Upgrade notes.
- Data-deletion guide.

---

## 36. Roadmap tracking format

Each roadmap item should track:

```text
Identifier
Title
Phase
Owner
Status
Dependencies
Backend requirement
Design requirement
Test requirement
Security requirement
Release gate
Decision link
```

Recommended status values:

```text
Proposed
Ready
In Progress
Blocked
In Validation
Done
Deferred
```

---

## 37. Initial implementation backlog

Recommended first engineering tasks:

1. Audit shared Swift files for platform imports.
2. Add macOS target to `ios/project.yml`.
3. Add `VocaMac/App/VocaMacApp.swift`.
4. Add macOS root authentication shell.
5. Add typed `AppRoute`.
6. Add scene coordinator protocol.
7. Add `NavigationSplitView` workspace.
8. Add semantic design tokens.
9. Extract HTTP transport protocol.
10. Extract credential-store protocol.
11. Add macOS test targets.
12. Add shared build in CI.
13. Implement Vocabulary repository protocol.
14. Build remote-backed Vocabulary table.
15. Implement word detail and pronunciation.

---

## 38. First prototype acceptance

The first demonstrable prototype should support:

1. Launch macOS app.
2. Sign in.
3. Open Vocabulary.
4. Load cards.
5. Search.
6. Select a word.
7. Read meaning.
8. Play pronunciation.
9. Add a word.
10. Sign out.

Prototype constraints:

- May be online-only.
- May use remote-backed repositories.
- Must not call APIs directly from views.
- Must preserve iOS build.
- Must use native macOS navigation and table behavior.

---

## 39. Private beta acceptance

Private beta should support:

- Daily use over multiple days.
- Local vocabulary reads.
- Durable supported writes.
- Full Review.
- Quick Lookup.
- Account sign out and return.
- Database migration.
- Offline and reconnect.
- Diagnostic export.
- Signed and notarized distribution.

Beta must exclude or clearly label:

- Incomplete offline review.
- Experimental AI generation.
- Unsupported file import.
- Unverified system integrations.

---

## 40. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Add the first macOS target inside the existing Apple project.
2. Delay repository relocation until shared boundaries stabilize.
3. Keep iOS buildability as a phase exit criterion.
4. Deliver Vocabulary and Review before broad system integrations.
5. Introduce local persistence before ambient widgets and Spotlight.
6. Keep offline review blocked until backend idempotency is verified.
7. Prioritize Quick Lookup as the first Mac-specific differentiator.
8. Keep menu bar optional and energy-gated.
9. Treat AI and advanced import as separable release scope.
10. Require signed internal builds before feature completion.
11. Require clean install and upgrade for release candidates.
12. Use objective testing, accessibility, performance, and security release gates.

---

## 41. Open questions

1. What is the final MVP scope?
2. What is the target distribution channel?
3. What minimum macOS version will ship?
4. Which Xcode and Swift versions are required?
5. How many Apple-platform engineers are available?
6. Can backend work proceed in parallel?
7. Which persistence technology will be selected?
8. Does the backend support review idempotency today?
9. Does the backend support incremental synchronization?
10. Does the backend support soft deletion and restore?
11. Which features must be available offline at public release?
12. Is Quick Lookup required for MVP or the differentiation release?
13. Is the menu bar companion required for MVP?
14. Which App Intents and widgets are required for first release?
15. Which AI practice mode provides the highest initial value?
16. Is PDF OCR required before public release?
17. Which analytics and crash-report tools will be used?
18. What performance targets apply to supported Mac hardware?
19. How will private beta builds be distributed?
20. What backend version-compatibility policy is required?

---

## 42. Definition of done

The roadmap is ready for active execution when:

- Every phase has an owner.
- MVP scope is approved.
- Backend blockers are assigned.
- Persistence and distribution decisions have deadlines.
- CI can build iOS and macOS.
- Prototype backlog is prioritized.
- Test and security work begin with Phase 1.
- Decision checkpoints are scheduled.
- Beta and release gates are accepted.
- Deferred features are explicitly separated from committed scope.

---

## 43. Next document

The next document should be:

```text
docs/macos-decisions.md
```

It should define:

- Architecture Decision Record format.
- Accepted decisions.
- Proposed decisions.
- Deferred decisions.
- Rejected alternatives.
- Decision owners.
- Review dates.
- Consequences.
- Superseded decisions.
- Links to supporting specifications and implementation work.
