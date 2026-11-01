# Voca for macOS — Decision Register

> Architecture Decision Record index for product, architecture, data, security, testing, and delivery decisions affecting the native Voca macOS application.

## Document status

- **Status:** Active Draft
- **Document type:** Architecture Decision Register
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related roadmap:** [`macos-roadmap.md`](macos-roadmap.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document records significant decisions for Voca on macOS.

It exists to:

- Preserve why a decision was made.
- Separate accepted decisions from proposals.
- Prevent resolved questions from repeatedly reopening without new evidence.
- Document alternatives and consequences.
- Link product, architecture, security, testing, and implementation work.
- Make superseded decisions traceable.
- Identify decisions that block implementation.

This register is not a replacement for feature specifications. It records choices that influence multiple features, modules, or release phases.

---

## 2. Decision categories

Decision identifiers use these prefixes:

```text
ADR-APP       Application structure and lifecycle
ADR-ARCH      Architecture and module boundaries
ADR-DATA      Persistence and synchronization
ADR-AUTH      Authentication and account management
ADR-UX        Product and interaction behavior
ADR-DESIGN    Visual and component system
ADR-REVIEW    Review and scheduling
ADR-QUICK     Quick Lookup
ADR-MENU      Menu bar
ADR-AI        Practice and AI
ADR-CAP       Import and capture
ADR-SYS       System integrations
ADR-SEC       Security and privacy
ADR-TEST      Testing and quality
ADR-DELIVERY  Repository, CI, distribution, and release
```

Identifiers are never reused.

---

## 3. Decision states

Allowed states:

```text
Proposed
Accepted
Rejected
Deferred
Superseded
Deprecated
```

### 3.1 Proposed

The decision is documented but not yet approved.

Implementation may explore the proposal but should not create an irreversible dependency unless the proposal is an explicit prototype assumption.

### 3.2 Accepted

The decision is approved and should guide implementation.

### 3.3 Rejected

The alternative was evaluated and intentionally not selected.

### 3.4 Deferred

The decision is valid but intentionally postponed until a named checkpoint or dependency is resolved.

### 3.5 Superseded

A later ADR replaces this decision.

Both records remain for history.

### 3.6 Deprecated

The decision remains part of historical implementation but should not be used for new work.

---

## 4. Decision priority

Priorities:

```text
P0 — Blocks target creation, security, or critical data integrity
P1 — Blocks a committed feature phase
P2 — Important but can use a temporary reversible assumption
P3 — May be resolved during implementation or validation
```

---

## 5. ADR format

Every substantial decision should use:

```markdown
## ADR-{CATEGORY}-{NUMBER} — Title

- Status:
- Priority:
- Date proposed:
- Date decided:
- Owner:
- Reviewers:
- Decision checkpoint:
- Related documents:
- Related implementation:
- Supersedes:
- Superseded by:

### Context

What problem requires a decision?

### Decision

What has been selected?

### Rationale

Why is this option preferred?

### Alternatives considered

Which alternatives were evaluated?

### Consequences

Positive and negative consequences.

### Validation

How will the decision be tested or revisited?

### Follow-up

Required implementation, documentation, or migration work.
```

---

## 6. Decision-change policy

An accepted decision may change when:

- New backend capability becomes available.
- Prototype evidence disproves an assumption.
- Security review identifies unacceptable risk.
- Accessibility testing identifies a blocker.
- Performance data invalidates the design.
- Distribution requirements change.
- A platform API changes.

Changing an accepted decision requires:

1. A new ADR or explicit amendment.
2. Updated consequences.
3. Migration impact.
4. Updated implementation links.
5. Updated affected specifications.

Do not silently edit the historical rationale to make it appear that the new decision was always intended.

---

## 7. Decision summary

### Accepted

- ADR-APP-001 — Create the first macOS target inside the existing Apple project.
- ADR-ARCH-001 — Share domain and infrastructure, not root platform UI.
- ADR-ARCH-002 — Feature views access external systems only through application use cases and repositories.
- ADR-ARCH-003 — Use typed application routes and scene coordination.
- ADR-UX-001 — Use a native sidebar, toolbar, table, inspector, and macOS commands.
- ADR-UX-002 — Table is the default Vocabulary presentation.
- ADR-REVIEW-001 — Persist a review event before advancing to the next card.
- ADR-REVIEW-002 — Keep Practice separate from FSRS Review.
- ADR-QUICK-001 — Implement Quick Lookup as a single-instance floating panel.
- ADR-DATA-001 — Make the local store the primary read source after bootstrap.
- ADR-DATA-002 — Partition every private record and operation by account.
- ADR-SEC-001 — Store secrets only through Keychain-backed credential services.
- ADR-SEC-002 — Use allowlist-based logging and diagnostics.
- ADR-TEST-001 — Keep time, UUIDs, randomness, locale, and connectivity injectable.
- ADR-DELIVERY-001 — Keep iOS buildability as a phase and release gate.

### Proposed

- ADR-APP-002 — Target macOS 14 or later.
- ADR-APP-003 — Use App Sandbox with minimal entitlements.
- ADR-DATA-003 — Select direct SQLite through a maintained Swift library.
- ADR-DATA-004 — Use separate local database partitions per account.
- ADR-REVIEW-003 — Enable offline review only with verified backend idempotency.
- ADR-QUICK-002 — Use Option + Space as the default global shortcut.
- ADR-MENU-001 — Keep the menu bar companion optional and hidden from first launch until enabled.
- ADR-SYS-001 — Make Spotlight indexing user-controlled.
- ADR-AI-001 — Keep AI conversation history local-only initially.
- ADR-CAP-001 — Ship CSV and Voca JSON as the initial structured import formats.
- ADR-DELIVERY-002 — Delay repository relocation from `ios/` to `apple/`.
- ADR-DELIVERY-003 — Use XcodeGen as the generated-project source of truth.

### Deferred

- ADR-SYS-002 — Interactive FSRS review in widgets.
- ADR-AI-002 — Microphone-based conversation practice.
- ADR-DATA-005 — Encrypt selected local content at field level.
- ADR-APP-004 — Hide the Dock icon in menu-bar-focused mode.
- ADR-CAP-002 — Anki package import.
- ADR-ARCH-004 — Move shared code into a local Swift package.

---

## ADR-APP-001 — Create the first macOS target inside the existing Apple project

- **Status:** Accepted
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Decision checkpoint:** Roadmap Phase 1
- **Related documents:** [`macos-architecture.md`](macos-architecture.md), [`macos-roadmap.md`](macos-roadmap.md)
- **Supersedes:** None
- **Superseded by:** None

### Context

The repository already contains an iOS application and project-generation configuration.

Creating a separate repository or relocating the entire Apple codebase before a macOS prototype would introduce:

- Large file movement.
- Build-script changes.
- CI changes.
- Merge conflicts.
- Unproven module boundaries.

### Decision

Add the first macOS application, unit-test, and UI-test targets to the existing Apple project.

Initial macOS source location:

```text
ios/VocaMac/
```

### Rationale

This approach:

- Preserves existing build tooling.
- Keeps shared-code extraction incremental.
- Allows iOS and macOS compilation to reveal actual platform boundaries.
- Avoids combining repository reorganization with product prototyping.

### Alternatives considered

#### Separate macOS repository

Rejected because it would make shared models, networking, authentication, and services harder to evolve consistently.

#### Immediate `apple/` repository reorganization

Deferred because shared ownership boundaries have not yet been proven by a compiling macOS target.

### Consequences

Positive:

- Fastest path to a compiling prototype.
- Existing iOS project remains visible during refactoring.
- Shared source membership can be introduced incrementally.

Negative:

- Temporary path naming is iOS-oriented.
- Some scripts may need target-specific conditions.
- A later move may still be required.

### Validation

- Generate both targets.
- Build iOS.
- Build macOS.
- Verify no target includes unintended platform files.

### Follow-up

- Update `ios/project.yml`.
- Add macOS source and test directories.
- Add dual-platform CI.
- Revisit repository layout after the first complete Vocabulary vertical slice.

---

## ADR-APP-002 — Target macOS 14 or later

- **Status:** Proposed
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Owner:** Product and Apple-platform engineering
- **Decision checkpoint:** Roadmap Checkpoint A
- **Related documents:** All macOS specifications

### Context

The deployment target affects:

- SwiftUI APIs.
- Observation.
- Table behavior.
- menu bar scenes.
- App Intents.
- Widget capabilities.
- Testing matrix.
- Supported hardware.

### Decision

Set the initial deployment target to:

```text
macOS 14 or later
```

### Rationale

The proposal balances:

- Modern SwiftUI and Observation support.
- Reduced compatibility branching.
- Reasonable Mac coverage.
- Simpler system-integration implementation.

### Alternatives considered

#### macOS 13

Provides broader compatibility but may require additional API fallback and testing.

#### Latest macOS only

Simplifies implementation further but unnecessarily narrows the audience before usage data exists.

### Consequences

Positive:

- Smaller compatibility matrix.
- Cleaner use of modern concurrency and SwiftUI.

Negative:

- Excludes older supported Macs.
- Must be verified against target-user hardware.

### Validation

- Audit every required API.
- Review anticipated user-device distribution.
- Build and run on the oldest supported system.

### Follow-up

- Record final value in project configuration.
- Add oldest-supported-system CI or manual test coverage.

---

## ADR-APP-003 — Use App Sandbox with minimal entitlements

- **Status:** Proposed
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Owner:** Security and Apple-platform engineering
- **Decision checkpoint:** Roadmap Checkpoint A
- **Related documents:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Voca requires:

- Network access.
- User-selected file access.
- Keychain.
- App Group for widgets.
- Notifications.
- Optional microphone access.

It does not require broad file-system, screen-recording, accessibility-control, or input-monitoring access for the planned first release.

### Decision

Ship the release application with App Sandbox enabled and only feature-justified entitlements.

### Rationale

Sandboxing:

- Reduces accidental access.
- Improves user trust.
- Aligns with native macOS distribution.
- Clarifies extension and file-access boundaries.

### Alternatives considered

#### Unsandboxed distribution

Rejected unless a future proven capability cannot operate safely within sandbox restrictions.

### Consequences

Positive:

- Stronger default isolation.
- Better control over imported-file access.

Negative:

- Global shortcut and Services choices require careful API selection.
- Security-scoped file handling adds implementation complexity.

### Validation

- Maintain an entitlement inventory.
- Test every integration in a release-signed sandboxed build.
- Fail the release gate on unexplained entitlements.

---

## ADR-ARCH-001 — Share domain and infrastructure, not root platform UI

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-architecture.md`](macos-architecture.md)

### Context

iOS and macOS share:

- Vocabulary concepts.
- Authentication.
- Networking.
- Review events.
- AI services.
- Persistence.

They differ significantly in:

- Root navigation.
- Toolbar.
- Tables.
- Inspectors.
- Menus.
- Windows.
- Hover.
- Multi-selection.

### Decision

Share:

- Domain models.
- Application use cases.
- Repository protocols.
- Networking.
- Authentication.
- Persistence.
- Synchronization.
- Audio abstractions.
- Semantic design intent.

Keep platform-specific:

- Root application scene.
- Navigation.
- Vocabulary workspace presentation.
- Review presentation.
- Settings UI.
- Window and menu coordination.

### Rationale

This avoids:

- A mobile UI enlarged for desktop.
- Extensive platform conditionals.
- Hidden coupling between lifecycle models.

### Alternatives considered

#### Share all SwiftUI feature views

Rejected because platform behavior and information density differ materially.

#### Duplicate all code

Rejected because domain correctness, authentication, and synchronization must remain consistent.

### Consequences

Positive:

- Native platform experiences.
- Shared business correctness.
- Clear dependency direction.

Negative:

- Some visually similar components will have separate implementations.
- Platform-specific UI testing remains necessary.

### Validation

- Shared modules compile for both platforms.
- macOS feature views do not depend on iOS navigation types.
- Shared modules do not import UIKit or AppKit without a platform abstraction.

---

## ADR-ARCH-002 — Feature views use application use cases and repositories

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-architecture.md`](macos-architecture.md), [`macos-testing.md`](macos-testing.md)

### Context

Direct API, database, Keychain, speech, and synchronization calls from SwiftUI views would:

- Duplicate orchestration.
- Make cancellation difficult.
- Complicate testing.
- Bypass account and security policy.

### Decision

Feature views and feature-state objects invoke:

- Application use cases.
- Repository protocols.
- Approved platform-service protocols.

They do not construct:

- API clients.
- Database connections.
- Keychain stores.
- Synchronization coordinators.
- Provider clients.

### Rationale

This creates:

- Testable boundaries.
- Consistent error mapping.
- Shared behavior across app, menu bar, intents, and widgets.

### Consequences

Positive:

- Lower coupling.
- Better failure injection.
- Reusable domain actions.

Negative:

- Additional protocol and orchestration types.
- Small features may require more initial structure.

### Validation

- Architecture review.
- Test substitute coverage.
- Static import and dependency checks where practical.

---

## ADR-ARCH-003 — Use typed routes and scene coordination

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-information-architecture.md`](macos-information-architecture.md), [`macos-system-integrations.md`](macos-system-integrations.md)

### Context

Voca must route from:

- Sidebar.
- Main-window actions.
- Quick Lookup.
- Menu bar.
- Notifications.
- Widgets.
- Spotlight.
- App Intents.
- Services.
- Deep links.

String routes and feature-local navigation cannot reliably coordinate multiple windows and account gates.

### Decision

Use:

```swift
enum AppRoute
```

for canonical destinations and a main-actor scene coordinator for window or scene presentation.

### Rationale

Typed routes provide:

- Compile-time route structure.
- Central validation.
- Authentication gating.
- Stable system-integration behavior.
- Safer migration.

### Consequences

Positive:

- One navigation contract.
- Easier route testing.
- Clear multi-window ownership.

Negative:

- Route evolution requires migration and compatibility care.
- Feature teams must not bypass the coordinator for cross-scene navigation.

### Validation

- Contract tests for every canonical route.
- Malformed and cross-account deep-link tests.
- Multi-window UI tests.

---

## ADR-ARCH-004 — Move shared code into a local Swift package

- **Status:** Deferred
- **Priority:** P2
- **Date proposed:** 2026-10-24
- **Decision checkpoint:** After Vocabulary prototype
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-architecture.md`](macos-architecture.md), [`macos-roadmap.md`](macos-roadmap.md)

### Context

A local Swift package could enforce modular boundaries, but extracting before both platform targets compile may encode incorrect ownership.

### Decision

Keep shared files in target memberships initially. Revisit package extraction after:

- iOS and macOS compile shared networking and authentication.
- Vocabulary repository boundaries are proven.
- Shared tests exist.

### Consequences

Positive:

- Avoids premature package structure.

Negative:

- Target membership is a weaker boundary temporarily.

### Validation

At the decision checkpoint, evaluate:

- Dependency graph.
- Build time.
- Test ownership.
- Cross-platform imports.

---

## ADR-DESIGN-001 — Use semantic tokens and system surfaces

- **Status:** Accepted
- **Priority:** P1
- **Date decided:** 2026-10-24
- **Owner:** Product design and Apple-platform engineering
- **Related documents:** [`macos-design-system.md`](macos-design-system.md)

### Context

The interface must support:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Multiple languages.
- Native selection.
- macOS system materials.

### Decision

Feature code consumes semantic tokens.

Use macOS system semantic colors for:

- Text.
- Window surfaces.
- Sidebar.
- Selection.
- Separators.
- Disabled states.

Use Voca green for:

- Primary actions.
- Learning emphasis.
- Selected brand moments.

### Consequences

Positive:

- Native adaptation.
- Better accessibility.
- Easier visual maintenance.

Negative:

- Brand appearance is less rigid than a fixed raw palette.

### Validation

- Preview matrix.
- Light and Dark Mode.
- Increased Contrast.
- Selection in active and inactive windows.

---

## ADR-UX-001 — Use native macOS navigation and controls

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Product design and Apple-platform engineering
- **Related documents:** [`macos-information-architecture.md`](macos-information-architecture.md), [`macos-design-system.md`](macos-design-system.md)

### Context

Voca must support desktop behaviors such as:

- Multi-column navigation.
- Toolbar commands.
- Menus.
- Context menus.
- Keyboard shortcuts.
- Inspectors.
- Tables.
- Multi-selection.

### Decision

Use standard macOS patterns and controls wherever they satisfy product needs.

Custom controls require a documented benefit and accessibility behavior.

### Consequences

Positive:

- Familiar interaction.
- Better keyboard and accessibility behavior.
- Lower maintenance.

Negative:

- Some brand styling remains restrained.
- Cross-platform UI components cannot always be shared.

---

## ADR-UX-002 — Table is the default Vocabulary presentation

- **Status:** Accepted
- **Priority:** P1
- **Date decided:** 2026-10-24
- **Owner:** Product design
- **Related documents:** [`macos-vocabulary.md`](macos-vocabulary.md)

### Context

Desktop users need to:

- Scan large libraries.
- Compare metadata.
- Sort.
- Resize columns.
- Multi-select.
- Perform batch actions.

### Decision

Use a native table as the default Vocabulary view.

List and Grid remain optional presentation modes.

### Consequences

Positive:

- Efficient information density.
- Native sorting and selection.
- Strong desktop differentiation.

Negative:

- Requires careful column customization and responsive handling.

### Validation

- Test with 1,000, 10,000, and 50,000 synthetic cards.
- Validate English and Chinese row density.

---

## ADR-DATA-001 — Use the local store as the primary read source after bootstrap

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-data-and-sync.md`](macos-data-and-sync.md)

### Context

Reading directly from remote endpoints would make:

- Startup network-dependent.
- Search slower.
- Quick Lookup unreliable.
- Menu bar and widgets difficult.
- Offline usage impossible.

### Decision

After initial account bootstrap:

```text
Feature reads
→ local repository
→ background synchronization updates local store
→ observation updates feature
```

### Consequences

Positive:

- Fast startup.
- Offline reads.
- Shared source for main app and ambient features.

Negative:

- Requires schema, migration, synchronization, and repair.

### Validation

- Offline relaunch.
- Large-library benchmarks.
- Incremental-sync tests.
- Store corruption and migration tests.

---

## ADR-DATA-002 — Partition every private record and operation by account

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Security and Apple-platform engineering
- **Related documents:** [`macos-data-and-sync.md`](macos-data-and-sync.md), [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Private data includes:

- Vocabulary.
- Notes.
- Review events.
- Study state.
- AI conversations.
- Imported content.
- Pending mutations.

### Decision

Every private record, queue entry, cache, route, snapshot, and derived projection must have an explicit account owner.

Repositories operate through an account-scoped application environment.

### Consequences

Positive:

- Strong isolation.
- Safer account switching.

Negative:

- More explicit ownership fields and lifecycle cleanup.

### Validation

- Cross-account repository tests.
- Account-switch UI tests.
- Widget and Spotlight cleanup tests.
- Pending-mutation token tests.

---

## ADR-DATA-003 — Use direct SQLite through a maintained Swift library

- **Status:** Proposed
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Decision checkpoint:** Roadmap Checkpoint A
- **Related documents:** [`macos-data-and-sync.md`](macos-data-and-sync.md)

### Context

The local store needs:

- Explicit migrations.
- Transactions.
- Batch upsert.
- Full-text search.
- Compound indexes.
- Mutation queue.
- Tombstones.
- Deterministic testing.
- Repair tooling.

### Decision

Select a maintained direct SQLite abstraction unless a SwiftData prototype demonstrates equivalent control and acceptable performance.

### Rationale

The synchronization and search requirements favor explicit database behavior.

### Alternatives considered

#### SwiftData

Advantages:

- Native framework.
- Less CRUD boilerplate.

Risks:

- Less explicit FTS behavior.
- Migration and batch-sync uncertainty.
- Query and repair control may be insufficient.

#### Core Data

Mature, but introduces its own complexity and may not simplify the sync queue or FTS needs.

### Consequences

Positive:

- Predictable SQL and migrations.
- Strong FTS and transaction control.

Negative:

- Additional dependency.
- More persistence implementation code.

### Validation

Prototype:

- 50,000-card FTS.
- 10,000-change batch apply.
- Migration interruption.
- Concurrent reads and serialized writes.

---

## ADR-DATA-004 — Use separate local database partitions per account

- **Status:** Proposed
- **Priority:** P1
- **Date proposed:** 2026-10-24
- **Owner:** Security and Apple-platform engineering
- **Decision checkpoint:** Before persistence implementation
- **Related documents:** [`macos-data-and-sync.md`](macos-data-and-sync.md)

### Context

Account partitioning can use:

- One database with `accountID` on every table.
- One database file per account.
- Both for defense in depth.

### Decision

Use one database directory per normalized server and account identity, while retaining explicit account ownership where practical.

### Rationale

Separate stores simplify:

- Sign-out retention.
- Local-data removal.
- Account switching.
- Repair.
- Accidental cross-account query prevention.

### Consequences

Positive:

- Strong physical partition.
- Easier deletion and rebuild.

Negative:

- Shared public dictionary caching needs separate design.
- Multiple stores complicate multi-account features later.

### Validation

- Account-switch benchmark.
- Shared-resource strategy.
- deletion tests.
- Store migration tests.

---

## ADR-DATA-005 — Encrypt selected local content at field level

- **Status:** Deferred
- **Priority:** P2
- **Date proposed:** 2026-10-24
- **Owner:** Security engineering
- **Decision checkpoint:** Before private beta
- **Related documents:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Potential encryption candidates:

- Personal notes.
- AI conversations.
- Retained imported excerpts.

Field-level encryption affects:

- Search.
- Key lifecycle.
- Migrations.
- Recovery.
- Extensions.

### Decision

Do not implement field-level encryption until the threat benefit, key ownership, and recovery model are defined.

Use:

- App Sandbox.
- Correct file permissions.
- Keychain for secrets.
- Minimized retention.

as the initial baseline.

### Validation

Complete a separate security design before changing this decision.

---

## ADR-AUTH-001 — Serialize token refresh through one account-scoped coordinator

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-architecture.md`](macos-architecture.md), [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Concurrent requests may discover an expired access token simultaneously.

Independent refresh attempts can:

- Race token rotation.
- invalidate valid credentials.
- duplicate sign-out.

### Decision

Use one account-scoped refresh coordinator.

Concurrent callers await the same refresh operation.

### Consequences

Positive:

- Consistent token lifecycle.
- Fewer duplicate requests.

Negative:

- All authenticated clients must use the shared pipeline.

### Validation

- Concurrent refresh tests.
- Rotation failure.
- Account switch during refresh.
- One retry maximum.

---

## ADR-REVIEW-001 — Persist review event before advancing

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform engineering
- **Related documents:** [`macos-review.md`](macos-review.md), [`macos-data-and-sync.md`](macos-data-and-sync.md)

### Context

Advancing before persistence could lose an acknowledged grade if:

- The process terminates.
- Storage fails.
- The network disappears.

### Decision

Grade flow:

```text
Create stable event
→ persist event and session progress transactionally
→ update predicted state
→ advance UI
→ synchronize
```

### Consequences

Positive:

- Accepted user intent remains durable.
- Session recovery can detect completed grades.

Negative:

- Local persistence latency is on the interaction path.
- Database failure must block advancement.

### Validation

- Process termination checkpoints.
- Disk failure.
- Rapid duplicate key input.
- Session resume.

---

## ADR-REVIEW-002 — Keep Practice separate from FSRS Review

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Product
- **Related documents:** [`macos-review.md`](macos-review.md), [`macos-practice-and-ai.md`](macos-practice-and-ai.md)

### Context

Practice may include:

- Multiple choice.
- Reading.
- Listening.
- Writing.
- Conversation.

AI evaluation may be probabilistic and does not always represent memory recall under FSRS conditions.

### Decision

Practice results do not alter FSRS scheduling unless the user explicitly enters a Review flow and selects a grade.

### Consequences

Positive:

- Honest, predictable scheduling.
- AI evaluation cannot silently change due dates.

Negative:

- Practice and review summaries require separate metrics.

### Validation

- Repository tests verify no review event is created by practice completion.

---

## ADR-REVIEW-003 — Enable offline review only with verified backend idempotency

- **Status:** Proposed
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Owner:** Backend and Apple-platform engineering
- **Decision checkpoint:** Roadmap Checkpoint D
- **Related documents:** [`macos-review.md`](macos-review.md), [`macos-data-and-sync.md`](macos-data-and-sync.md)

### Context

Offline review can produce ambiguous retries if the server accepts a grade but the client does not receive the response.

### Decision

Enable offline FSRS review only if the backend guarantees:

```text
Same operation ID
→ same accepted review event
→ no duplicate schedule update
```

### Alternatives considered

#### Client-only duplicate suppression

Rejected because it cannot prove whether the server accepted an ambiguous request.

#### Online-only review

Accepted as a temporary fallback if idempotency is unavailable.

### Validation

- Integration test timeout after server acceptance.
- Retry with same operation ID.
- Verify one FSRS state transition.

---

## ADR-QUICK-001 — Implement Quick Lookup as a single-instance floating panel

- **Status:** Accepted
- **Priority:** P1
- **Date decided:** 2026-10-24
- **Owner:** Product and Apple-platform engineering
- **Related documents:** [`macos-quick-lookup.md`](macos-quick-lookup.md)

### Context

Quick Lookup must:

- Open over another app.
- Accept typing immediately.
- Avoid activating every Voca window.
- Restore prior focus.
- Work across displays and Spaces.

### Decision

Use one dedicated floating panel managed by a platform coordinator.

Repeated invocation reuses the same panel.

### Consequences

Positive:

- Predictable lifecycle.
- Avoids stacked windows.
- Supports fast global invocation.

Negative:

- Requires AppKit bridging and macOS-specific testing.

### Validation

- Multiple displays.
- Full-screen app.
- Spaces.
- Main app closed.
- repeated invocation.
- VoiceOver focus.

---

## ADR-QUICK-002 — Use Option + Space as the default shortcut

- **Status:** Proposed
- **Priority:** P2
- **Date proposed:** 2026-10-24
- **Owner:** Product
- **Decision checkpoint:** Quick Lookup prototype review
- **Related documents:** [`macos-quick-lookup.md`](macos-quick-lookup.md)

### Context

The shortcut should:

- Be easy to remember.
- Be fast to press.
- Avoid common macOS conflicts.
- Work across keyboard layouts.

### Decision

Proposed default:

```text
Option + Space
```

Users can change or disable it.

### Alternatives considered

- Control + Space, often used by input-source switching.
- Command + Space, reserved for Spotlight.
- Multi-modifier combinations, less discoverable.

### Validation

- Conflict testing.
- International input methods.
- Accessibility shortcuts.
- User prototype feedback.

---

## ADR-MENU-001 — Keep the menu bar companion optional

- **Status:** Proposed
- **Priority:** P1
- **Date proposed:** 2026-10-24
- **Owner:** Product
- **Decision checkpoint:** Roadmap Phase 8
- **Related documents:** [`macos-menu-bar.md`](macos-menu-bar.md)

### Context

A persistent menu bar item:

- Provides ambient value.
- Occupies limited user space.
- Can increase background activity.

### Decision

The menu bar companion is optional.

Recommended onboarding behavior:

- Explain the feature.
- Enable only after explicit user selection.

### Consequences

Positive:

- Respects user menu-bar preferences.
- Avoids unannounced persistence.

Negative:

- Lower initial discovery.

### Validation

- Onboarding tests.
- Settings lifecycle.
- Relaunch behavior.
- Energy profile.

---

## ADR-SYS-001 — Make Spotlight indexing user-controlled

- **Status:** Proposed
- **Priority:** P1
- **Date proposed:** 2026-10-24
- **Owner:** Product and security
- **Decision checkpoint:** Before Spotlight implementation
- **Related documents:** [`macos-system-integrations.md`](macos-system-integrations.md), [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Spotlight provides useful retrieval but projects private learning content outside Voca's own windows.

### Decision

Provide a setting:

```text
Show saved vocabulary in Spotlight
```

Index only:

- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meaning.
- Deep-link identity.

Exclude:

- Notes.
- Review history.
- AI conversations.
- Imported text.

### Validation

- Enable and disable.
- Sign out.
- Account switch.
- stale-result authorization.

---

## ADR-SYS-002 — Interactive FSRS review in widgets

- **Status:** Deferred
- **Priority:** P3
- **Date proposed:** 2026-10-24
- **Owner:** Product and Apple-platform engineering
- **Decision checkpoint:** Post-release
- **Related documents:** [`macos-system-integrations.md`](macos-system-integrations.md)

### Context

Interactive widget grading requires:

- Durable local events.
- Intent execution reliability.
- Idempotency.
- Session semantics.
- Snapshot refresh.

### Decision

Defer graded widget review.

Initial widgets may:

- Display due count.
- Display daily goal.
- Display word of the day.
- Open full Review.

### Validation

Revisit after offline review and App Intent mutation reliability are proven.

---

## ADR-AI-001 — Keep AI history local-only initially

- **Status:** Proposed
- **Priority:** P1
- **Date proposed:** 2026-10-24
- **Owner:** Product, backend, and security
- **Decision checkpoint:** Before Assistant persistence
- **Related documents:** [`macos-practice-and-ai.md`](macos-practice-and-ai.md)

### Context

Synchronizing AI conversations requires:

- Backend schema.
- Retention policy.
- deletion behavior.
- Cross-device conflict behavior.
- Privacy review.

### Decision

Persist AI conversations locally for the initial release.

Provide:

- Delete conversation.
- Clear history.
- Local retention settings.

Do not synchronize until a dedicated contract is approved.

### Consequences

Positive:

- Smaller backend and privacy scope.
- Clear local deletion.

Negative:

- Conversations do not follow the user across devices.

### Validation

- Relaunch.
- deletion.
- account switch.
- local-data removal.

---

## ADR-AI-002 — Microphone-based conversation practice

- **Status:** Deferred
- **Priority:** P3
- **Date proposed:** 2026-10-24
- **Owner:** Product
- **Decision checkpoint:** Post-release
- **Related documents:** [`macos-practice-and-ai.md`](macos-practice-and-ai.md)

### Context

Speech input introduces:

- Microphone permission.
- Recording indicators.
- Transcription provider policy.
- Audio retention.
- Additional accessibility requirements.

### Decision

Deliver text-based Conversation practice before microphone input.

### Validation

Revisit after:

- Core Conversation adoption.
- Provider review.
- Privacy design.
- speech-quality evaluation.

---

## ADR-CAP-001 — Ship CSV and Voca JSON as initial structured formats

- **Status:** Proposed
- **Priority:** P1
- **Date proposed:** 2026-10-24
- **Owner:** Product and Apple-platform engineering
- **Decision checkpoint:** Import implementation
- **Related documents:** [`macos-import-and-capture.md`](macos-import-and-capture.md)

### Context

Structured import must support common data exchange without creating unbounded adapter scope.

### Decision

Initial structured formats:

```text
CSV
Voca JSON
```

### Rationale

CSV supports broad interoperability. Voca JSON supports loss-minimized versioned export and reimport.

### Consequences

Positive:

- Manageable parser and validation surface.
- Clear column mapping.

Negative:

- Third-party proprietary formats require conversion.

### Validation

- Formatting matrix.
- large files.
- encoding.
- schema migration.
- formula-injection mitigation.

---

## ADR-CAP-002 — Support Anki package import

- **Status:** Deferred
- **Priority:** P3
- **Date proposed:** 2026-10-24
- **Owner:** Product
- **Decision checkpoint:** Post-release import review
- **Related documents:** [`macos-import-and-capture.md`](macos-import-and-capture.md)

### Context

Anki packages may include:

- Custom note types.
- Scheduling state.
- Media.
- HTML.
- Deck relationships.

### Decision

Defer direct package import.

Users may initially convert data to CSV.

### Rationale

The format's semantic and security scope is much larger than ordinary structured vocabulary import.

---

## ADR-SEC-001 — Store secrets only through Keychain-backed services

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Security and Apple-platform engineering
- **Related documents:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

### Context

Secrets include:

- Refresh tokens.
- Persisted access tokens.
- Provider API keys.
- TTS provider keys.

### Decision

Store secrets only through an approved Keychain-backed credential service.

Never store secrets in:

- UserDefaults.
- Database.
- App Group.
- Logs.
- Diagnostics.
- Exports.

### Validation

- Storage inspection.
- marker scans.
- sign-out deletion.
- migration tests.
- wrong-account and wrong-server tests.

---

## ADR-SEC-002 — Use allowlist-based logging and diagnostics

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Security and quality engineering
- **Related documents:** [`macos-security-and-privacy.md`](macos-security-and-privacy.md), [`macos-testing.md`](macos-testing.md)

### Context

Redacting arbitrary serialized objects is error-prone because private content may appear in unexpected fields.

### Decision

Logs and diagnostics include only approved metadata fields.

Prohibited:

- Credentials.
- Vocabulary content.
- Notes.
- Search queries.
- Clipboard content.
- AI prompts and responses.
- Imported text.

### Consequences

Positive:

- Lower accidental-exposure risk.

Negative:

- Debugging requires stronger structured error categories and request IDs.

### Validation

- Synthetic private marker tests.
- Diagnostics archive scanning.
- Production-log review.

---

## ADR-TEST-001 — Inject time, identity, randomness, locale, and connectivity

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Apple-platform and quality engineering
- **Related documents:** [`macos-testing.md`](macos-testing.md)

### Context

The following behaviors depend on external state:

- Due dates.
- Daily goals.
- Streaks.
- Retry.
- session expiry.
- Generated IDs.
- recommendation selection.
- language formatting.
- offline state.

### Decision

Use injected abstractions for:

- Clock.
- UUID generation.
- Random source.
- Locale.
- Calendar.
- Time zone.
- Connectivity.

### Consequences

Positive:

- Deterministic tests.
- Reproducible failures.
- No timing sleeps in core tests.

Negative:

- Additional dependency plumbing.

### Validation

- Day-boundary tests.
- Retry tests.
- seeded recommendation tests.
- locale matrix.

---

## ADR-DELIVERY-001 — Keep iOS buildability as an implementation gate

- **Status:** Accepted
- **Priority:** P0
- **Date decided:** 2026-10-24
- **Owner:** Engineering
- **Related documents:** [`macos-roadmap.md`](macos-roadmap.md), [`macos-testing.md`](macos-testing.md)

### Context

macOS development requires extracting shared code from an active iOS application.

### Decision

Every phase and pull request affecting shared code must keep the iOS target buildable.

Important shared changes should run relevant iOS tests.

### Consequences

Positive:

- Prevents macOS work from destabilizing the existing product.
- Reveals invalid shared abstractions quickly.

Negative:

- CI duration increases.
- Refactors may need smaller transitional steps.

### Validation

- Dual-platform CI.
- phase exit checklist.

---

## ADR-DELIVERY-002 — Delay repository relocation from `ios/` to `apple/`

- **Status:** Proposed
- **Priority:** P2
- **Date proposed:** 2026-10-24
- **Owner:** Engineering
- **Decision checkpoint:** After Vocabulary vertical slice
- **Related documents:** [`macos-roadmap.md`](macos-roadmap.md)

### Context

The path `ios/` will become inaccurate after adding macOS, but moving it immediately combines:

- File relocation.
- Target creation.
- Script updates.
- Documentation updates.
- Shared-code refactoring.

### Decision

Keep the existing directory during early prototyping.

Move to:

```text
apple/
```

only after:

- macOS target is stable.
- shared-module ownership is known.
- CI supports the move.

### Consequences

Positive:

- Lower early churn.

Negative:

- Temporary naming inconsistency.

---

## ADR-DELIVERY-003 — Keep XcodeGen as project source of truth

- **Status:** Proposed
- **Priority:** P0
- **Date proposed:** 2026-10-24
- **Owner:** Engineering and release engineering
- **Decision checkpoint:** Roadmap Phase 1
- **Related documents:** [`macos-architecture.md`](macos-architecture.md), [`macos-roadmap.md`](macos-roadmap.md)

### Context

The existing Apple project uses a project-generation specification.

Editing the generated project directly would create drift.

### Decision

Define the macOS target, tests, settings, entitlements, schemes, and shared source membership in XcodeGen configuration.

Treat generated project files as derived output.

### Consequences

Positive:

- Reproducible project structure.
- Reviewable target configuration.

Negative:

- New contributors require the generator.
- Some Xcode changes need translation into project specification.

### Validation

- Clean regeneration.
- Reproducible diff.
- CI generation.
- iOS and macOS build.

---

## 8. Rejected alternatives

This section summarizes alternatives rejected across accepted ADRs.

### 8.1 Separate macOS repository

Rejected because shared domain, authentication, networking, persistence, and synchronization would drift or require a premature distributable package strategy.

### 8.2 One shared root SwiftUI application

Rejected because iOS and macOS use materially different:

- Navigation.
- Windowing.
- Commands.
- Table behavior.
- Inspector behavior.

### 8.3 Direct API calls from SwiftUI views

Rejected because it bypasses:

- Testable orchestration.
- Account scoping.
- Cancellation.
- Error mapping.
- Offline behavior.

### 8.4 Offline review without server idempotency

Rejected because ambiguous network failures can submit one intended grade more than once.

### 8.5 Widgets accessing the full account database

Rejected because a compact snapshot provides a smaller security, migration, and initialization surface.

### 8.6 Personal notes in AI context by default

Rejected because notes are user-authored private content and are unnecessary for most language-generation tasks.

### 8.7 Automatic card creation on document drop

Rejected because extraction, duplicate classification, and generated content require review before persistence.

### 8.8 Continuous clipboard monitoring

Rejected because it creates unnecessary privacy and energy cost.

### 8.9 Logging raw request and response bodies

Rejected because bodies may contain credentials, vocabulary content, notes, prompts, and documents.

---

## 9. Deferred-decision review schedule

Deferred decisions should be revisited at these checkpoints:

### After application shell

- Swift-package extraction.
- Dock-icon policy.

### After Vocabulary prototype

- Repository relocation.
- Persistence technology final confirmation.
- Detail-window policy.

### After Review prototype

- Offline review.
- Grade undo.
- Review-session expiry.

### After Quick Lookup prototype

- Default shortcut.
- Clipboard-suggestion default.
- Outside-click dismissal.

### Before private beta

- Field-level encryption.
- Analytics and crash reporting.
- Spotlight default.
- Signed-out local-data retention.

### Post-release

- Interactive review widgets.
- Microphone conversation.
- Anki import.
- Synchronized AI history.

---

## 10. Decision review checklist

Before accepting an ADR:

- [ ] Problem is specific.
- [ ] Owner is named.
- [ ] Alternatives are real.
- [ ] Security impact is addressed.
- [ ] Privacy impact is addressed.
- [ ] Accessibility impact is addressed.
- [ ] Performance impact is addressed.
- [ ] Migration impact is addressed.
- [ ] iOS impact is addressed.
- [ ] Backend dependency is addressed.
- [ ] Validation method is defined.
- [ ] Follow-up work is identified.

---

## 11. Implementation traceability

When implementation begins, each accepted ADR should link to:

- Issue or work item.
- Pull request.
- Test suite.
- Migration where applicable.
- Release milestone.

Suggested block:

```text
Implementation status:
Issue:
Pull request:
Tests:
Released in:
```

The decision owner is responsible for keeping implementation traceability current.

---

## 12. Superseding a decision

To supersede an ADR:

1. Create a new ADR.
2. Set the old ADR to `Superseded`.
3. Add `Superseded by`.
4. Add `Supersedes` to the new ADR.
5. Explain migration.
6. Update affected documents.
7. Add implementation follow-up.

Do not delete the old decision.

---

## 13. Immediate decision backlog

Resolve before target bootstrap:

1. ADR-APP-002 — Minimum macOS version.
2. ADR-APP-003 — App Sandbox.
3. ADR-DELIVERY-003 — XcodeGen source of truth.
4. Distribution channel.
5. Bundle identifiers.
6. Signing team and entitlements.

Resolve before local persistence:

1. ADR-DATA-003 — Database technology.
2. ADR-DATA-004 — Account store partition.
3. Sync-cursor contract.
4. Soft-delete capability.

Resolve before offline review:

1. ADR-REVIEW-003 — Backend idempotency.
2. Review-event ordering.
3. Authoritative reconciliation response.

Resolve before Quick Lookup:

1. ADR-QUICK-002 — Default shortcut.
2. Global-hotkey implementation.
3. Clipboard-suggestion default.
4. Window-dismissal behavior.

Resolve before private beta:

1. Spotlight default.
2. Menu bar onboarding default.
3. Analytics.
4. Crash reporting.
5. Signed-out retained-data policy.
6. AI-history retention.

---

## 14. Definition of done

The decision register is operational when:

- P0 implementation decisions have owners.
- Every accepted cross-cutting decision has an ADR.
- Proposed P0 decisions have review dates.
- Deferred decisions have named checkpoints.
- Rejected alternatives remain documented.
- Accepted decisions link to implementation work when it begins.
- Superseded decisions remain traceable.
- Feature specifications and roadmap use consistent decision outcomes.

---

## 15. Next document

The next document should be:

```text
docs/macos-documentation-index.md
```

It should define:

- Complete macOS documentation map.
- Recommended reading order.
- Document owners.
- Document statuses.
- Requirement coverage.
- Cross-document dependency map.
- Open-decision summary.
- Backend-blocker summary.
- Implementation readiness.
- Documentation maintenance rules.
