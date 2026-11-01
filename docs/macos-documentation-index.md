# Voca for macOS — Documentation Index

> Canonical map, reading order, ownership model, status register, requirement coverage, dependency graph, open decisions, backend blockers, and implementation-readiness summary for the Voca macOS documentation set.

## Document status

- **Status:** Active Draft
- **Document type:** Documentation Index and Governance Register
- **Target platform:** macOS 14 or later
- **Primary overview:** [`macos-overview.md`](macos-overview.md)
- **Decision register:** [`macos-decisions.md`](macos-decisions.md)
- **Delivery roadmap:** [`macos-roadmap.md`](macos-roadmap.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document is the canonical entry point for the Voca macOS documentation set.

It defines:

- The complete documentation map.
- Recommended reading order.
- Intended audience for each document.
- Document owners.
- Document status.
- Cross-document dependencies.
- Requirement coverage.
- Accepted and open decisions.
- Backend blockers.
- Implementation-readiness status.
- Documentation maintenance rules.
- Review and approval expectations.

Use this document to answer:

1. Which specification should I read?
2. Which document owns a product or architecture decision?
3. Which documents must change when a feature changes?
4. Which unresolved decisions block implementation?
5. Which backend capabilities are required?
6. Is a feature ready to enter engineering?

---

## 2. Documentation principles

### DOC-PRN-001 — One canonical owner per concern

Every cross-cutting concern should have one primary document.

Other documents may summarize it, but they should link to the canonical owner instead of defining contradictory behavior.

### DOC-PRN-002 — Product behavior precedes implementation detail

A feature specification should define:

- User intent.
- States.
- Actions.
- Errors.
- Offline behavior.
- Accessibility.
- Acceptance criteria.

Architecture documents then define how the behavior is supported.

### DOC-PRN-003 — Decisions remain traceable

Cross-cutting choices belong in:

[`macos-decisions.md`](macos-decisions.md)

Feature documents may propose decisions, but an accepted decision should be reflected in the decision register.

### DOC-PRN-004 — Requirements remain traceable

Each requirement family must map to:

- Product behavior.
- Architecture.
- Testing.
- Release criteria.

### DOC-PRN-005 — Documentation changes with implementation

A pull request that changes documented behavior should update the owning specification or decision record in the same change.

### DOC-PRN-006 — Historical rationale is preserved

Superseded decisions are not deleted.

They remain available with links to their replacements.

### DOC-PRN-007 — Unknowns are explicit

Open questions, assumptions, missing backend contracts, and deferred scope should be recorded rather than hidden in implementation.

---

## 3. Quick navigation

### Start here

- macos-documentation-index.md
- [Product Overview](macos-overview.md)
- [Product Requirements](macos-product-requirements.md)
- [Delivery Roadmap](macos-roadmap.md)
- [Decision Register](macos-decisions.md)

### Product and UX

- [Information Architecture](macos-information-architecture.md)
- [Design System](macos-design-system.md)
- [Today Dashboard](macos-today.md)
- [Vocabulary Workspace](macos-vocabulary.md)
- [Review Experience](macos-review.md)
- [Quick Lookup](macos-quick-lookup.md)
- [Menu Bar Companion](macos-menu-bar.md)
- [Practice and AI](macos-practice-and-ai.md)
- [Import and Capture](macos-import-and-capture.md)

### Architecture and platform

- [Application Architecture](macos-architecture.md)
- [Data, Offline, and Synchronization](macos-data-and-sync.md)
- [System Integrations](macos-system-integrations.md)
- [Security and Privacy](macos-security-and-privacy.md)

### Delivery and quality

- [Testing and Quality Strategy](macos-testing.md)
- [Delivery Roadmap](macos-roadmap.md)
- [Decision Register](macos-decisions.md)

---

## 4. Recommended reading order

## 4.1 Executive and product review

Recommended order:

1. [`macos-overview.md`](macos-overview.md)
2. [`macos-product-requirements.md`](macos-product-requirements.md)
3. [`macos-roadmap.md`](macos-roadmap.md)
4. [`macos-decisions.md`](macos-decisions.md)

This sequence explains:

- Why the macOS application should exist.
- What it must do.
- How delivery is phased.
- Which decisions are accepted or unresolved.

## 4.2 Product design review

Recommended order:

1. [`macos-overview.md`](macos-overview.md)
2. [`macos-information-architecture.md`](macos-information-architecture.md)
3. [`macos-design-system.md`](macos-design-system.md)
4. [`macos-today.md`](macos-today.md)
5. [`macos-vocabulary.md`](macos-vocabulary.md)
6. [`macos-review.md`](macos-review.md)
7. [`macos-quick-lookup.md`](macos-quick-lookup.md)
8. [`macos-menu-bar.md`](macos-menu-bar.md)
9. [`macos-practice-and-ai.md`](macos-practice-and-ai.md)
10. [`macos-import-and-capture.md`](macos-import-and-capture.md)

## 4.3 Apple-platform engineering review

Recommended order:

1. [`macos-architecture.md`](macos-architecture.md)
2. [`macos-decisions.md`](macos-decisions.md)
3. [`macos-data-and-sync.md`](macos-data-and-sync.md)
4. [`macos-security-and-privacy.md`](macos-security-and-privacy.md)
5. [`macos-testing.md`](macos-testing.md)
6. Feature specification for the current implementation phase.
7. [`macos-roadmap.md`](macos-roadmap.md)

## 4.4 Backend engineering review

Recommended order:

1. [`macos-product-requirements.md`](macos-product-requirements.md)
2. [`macos-data-and-sync.md`](macos-data-and-sync.md)
3. [`macos-review.md`](macos-review.md)
4. [`macos-practice-and-ai.md`](macos-practice-and-ai.md)
5. [`macos-import-and-capture.md`](macos-import-and-capture.md)
6. [`macos-system-integrations.md`](macos-system-integrations.md)
7. Backend blockers in this index.
8. [`macos-decisions.md`](macos-decisions.md)

## 4.5 Quality and security review

Recommended order:

1. [`macos-security-and-privacy.md`](macos-security-and-privacy.md)
2. [`macos-testing.md`](macos-testing.md)
3. [`macos-data-and-sync.md`](macos-data-and-sync.md)
4. [`macos-review.md`](macos-review.md)
5. [`macos-quick-lookup.md`](macos-quick-lookup.md)
6. [`macos-system-integrations.md`](macos-system-integrations.md)
7. [`macos-import-and-capture.md`](macos-import-and-capture.md)
8. [`macos-roadmap.md`](macos-roadmap.md)

---

## 5. Document register

## 5.1 Product overview

### `macos-overview.md`

- **Title:** Voca for macOS Overview
- **Owner:** Product
- **Reviewers:** Design, Apple-platform engineering, backend
- **Status:** Draft
- **Audience:** All stakeholders
- **Canonical responsibility:**
  - Product vision.
  - User value.
  - Platform differentiation.
  - High-level capability map.
  - Product principles.
- **Depends on:** Existing product context.
- **Referenced by:** All macOS documents.

## 5.2 Product requirements

### `macos-product-requirements.md`

- **Title:** Voca for macOS Product Requirements
- **Owner:** Product
- **Reviewers:** Design, engineering, quality, security
- **Status:** Draft
- **Audience:** Product, design, engineering, QA
- **Canonical responsibility:**
  - Requirement identifiers.
  - Functional requirements.
  - Nonfunctional requirements.
  - Priority.
  - Scope expectations.
- **Depends on:** Product overview.
- **Referenced by:** Feature, architecture, testing, and roadmap documents.

## 5.3 Information architecture

### `macos-information-architecture.md`

- **Title:** Voca for macOS Information Architecture
- **Owner:** Product design
- **Reviewers:** Product, Apple-platform engineering, accessibility
- **Status:** Draft
- **Audience:** Product, design, client engineering
- **Canonical responsibility:**
  - Application destinations.
  - Sidebar hierarchy.
  - Route organization.
  - Window hierarchy.
  - Content ownership.
  - Navigation relationships.
- **Depends on:** Overview and requirements.
- **Referenced by:** Design system and all primary feature documents.

## 5.4 Application architecture

### `macos-architecture.md`

- **Title:** Voca for macOS Architecture
- **Owner:** Apple-platform engineering
- **Reviewers:** Backend, security, quality, product
- **Status:** Draft
- **Audience:** Engineering and architecture reviewers
- **Canonical responsibility:**
  - Module boundaries.
  - Dependency direction.
  - Application environment.
  - Platform boundaries.
  - Scene coordination.
  - Shared-code strategy.
  - Use-case and repository architecture.
- **Depends on:** Requirements and information architecture.
- **Referenced by:** All implementation-oriented documents.

## 5.5 Design system

### `macos-design-system.md`

- **Title:** Voca for macOS Design System
- **Owner:** Product design
- **Reviewers:** Accessibility, Apple-platform engineering
- **Status:** Draft
- **Audience:** Product design and client engineering
- **Canonical responsibility:**
  - Semantic tokens.
  - Typography.
  - Color.
  - Spacing.
  - Tables.
  - Inspectors.
  - Review components.
  - Loading, empty, error, and offline states.
  - Accessibility presentation.
- **Depends on:** Information architecture and product principles.
- **Referenced by:** Every UI feature specification.

## 5.6 Vocabulary

### `macos-vocabulary.md`

- **Title:** Voca for macOS Vocabulary Workspace
- **Owner:** Product and Apple-platform engineering
- **Reviewers:** Design, backend, QA, accessibility
- **Status:** Draft
- **Audience:** Product, design, engineering, QA
- **Canonical responsibility:**
  - Vocabulary collections.
  - Table, list, and grid.
  - Search.
  - Filters.
  - Sorting.
  - Selection.
  - Detail.
  - Inspector.
  - Add and edit.
  - Duplicates.
  - Tags and notes.
  - Trash.
- **Depends on:** Architecture, design system, data model.
- **Referenced by:** Today, Quick Lookup, Practice, Import, and system integrations.

## 5.7 Review

### `macos-review.md`

- **Title:** Voca for macOS Review Experience
- **Owner:** Product and Apple-platform engineering
- **Reviewers:** Backend, design, QA, accessibility
- **Status:** Draft
- **Audience:** Product, engineering, backend, QA
- **Canonical responsibility:**
  - Due eligibility.
  - Review sessions.
  - Reveal.
  - Grades.
  - FSRS event semantics.
  - Pause and resume.
  - Offline review.
  - Idempotency.
  - Summary.
- **Depends on:** Vocabulary identity, data synchronization, backend review contract.
- **Referenced by:** Today, menu bar, widgets, testing, roadmap.

## 5.8 Today

### `macos-today.md`

- **Title:** Voca for macOS Today Dashboard
- **Owner:** Product
- **Reviewers:** Design, Apple-platform engineering, backend, QA
- **Status:** Draft
- **Audience:** Product, design, engineering
- **Canonical responsibility:**
  - Primary daily action.
  - Due summary.
  - Daily goal.
  - Streak.
  - Continue session.
  - Difficult words.
  - Suggested practice.
  - Weekly summary.
- **Depends on:** Vocabulary, Review, Practice, local data.
- **Referenced by:** Menu bar, widgets, notifications.

## 5.9 Data and synchronization

### `macos-data-and-sync.md`

- **Title:** Voca for macOS Data, Offline, and Synchronization
- **Owner:** Apple-platform and backend engineering
- **Reviewers:** Security, QA, product
- **Status:** Draft
- **Audience:** Client engineering, backend, QA, security
- **Canonical responsibility:**
  - Local data architecture.
  - Account partitioning.
  - Sync cursor.
  - Mutation queue.
  - Idempotency.
  - Conflicts.
  - Tombstones.
  - Recovery.
  - Offline capability.
- **Depends on:** Backend contracts and architecture.
- **Referenced by:** Every data-backed feature.

## 5.10 Quick Lookup

### `macos-quick-lookup.md`

- **Title:** Voca for macOS Quick Lookup
- **Owner:** Product and Apple-platform engineering
- **Reviewers:** Design, security, accessibility, QA
- **Status:** Draft
- **Audience:** Product, design, engineering, QA
- **Canonical responsibility:**
  - Global invocation.
  - Floating panel.
  - Search pipeline.
  - Clipboard suggestions.
  - Result ranking.
  - Save behavior.
  - Focus and display behavior.
  - Privacy and performance.
- **Depends on:** Vocabulary, local data, speech, scene coordination.
- **Referenced by:** Menu bar, Services, roadmap.

## 5.11 Menu bar

### `macos-menu-bar.md`

- **Title:** Voca for macOS Menu Bar Companion
- **Owner:** Product and Apple-platform engineering
- **Reviewers:** Design, security, QA, accessibility
- **Status:** Draft
- **Audience:** Product, engineering, QA
- **Canonical responsibility:**
  - Menu bar lifecycle.
  - Due count.
  - Mini Review.
  - Quick actions.
  - Launch at login.
  - Background refresh.
  - Energy.
- **Depends on:** Today snapshot, Review, Quick Lookup, synchronization.
- **Referenced by:** System integrations, security, testing, roadmap.

## 5.12 System integrations

### `macos-system-integrations.md`

- **Title:** Voca for macOS System Integrations
- **Owner:** Apple-platform engineering
- **Reviewers:** Product, security, design, QA
- **Status:** Draft
- **Audience:** Client engineering, product, QA, security
- **Canonical responsibility:**
  - App Intents.
  - App Entities.
  - Shortcuts.
  - Spotlight.
  - Services.
  - Widgets.
  - Notifications.
  - Deep links.
  - Extension boundaries.
- **Depends on:** Typed routes, local data, account isolation, App Group strategy.
- **Referenced by:** Security, testing, roadmap.

## 5.13 Practice and AI

### `macos-practice-and-ai.md`

- **Title:** Voca for macOS Practice and AI
- **Owner:** Product and AI/backend engineering
- **Reviewers:** Apple-platform engineering, design, security, QA
- **Status:** Draft
- **Audience:** Product, AI/backend, client engineering, QA
- **Canonical responsibility:**
  - Practice types.
  - Assistant workspace.
  - Conversation practice.
  - Context selection.
  - Streaming.
  - Cancellation.
  - Provider settings.
  - Generated-content validation.
  - AI privacy.
- **Depends on:** Vocabulary, data, security, provider contracts.
- **Referenced by:** Today, Import, system integrations, testing.

## 5.14 Import and capture

### `macos-import-and-capture.md`

- **Title:** Voca for macOS Import and Capture
- **Owner:** Product and Apple-platform engineering
- **Reviewers:** Security, backend, design, QA
- **Status:** Draft
- **Audience:** Product, engineering, QA, security
- **Canonical responsibility:**
  - Drag and drop.
  - Text capture.
  - OCR.
  - PDF.
  - CSV.
  - JSON.
  - Candidate review.
  - Duplicate classification.
  - Import commit.
  - Export.
- **Depends on:** Vocabulary, data, file-security policy, AI enrichment.
- **Referenced by:** Security, testing, roadmap.

## 5.15 Security and privacy

### `macos-security-and-privacy.md`

- **Title:** Voca for macOS Security and Privacy
- **Owner:** Security and Apple-platform engineering
- **Reviewers:** Product, backend, QA, release engineering
- **Status:** Draft
- **Audience:** Engineering, security, product, QA
- **Canonical responsibility:**
  - Threat model.
  - Data classification.
  - Keychain.
  - Account isolation.
  - Local-data protection.
  - AI transmission.
  - Clipboard and microphone privacy.
  - Logging.
  - Diagnostics.
  - Retention.
  - Sign-out cleanup.
  - Release security gates.
- **Depends on:** Architecture and data design.
- **Referenced by:** Every feature handling private data.

## 5.16 Testing

### `macos-testing.md`

- **Title:** Voca for macOS Testing and Quality Strategy
- **Owner:** Quality and Apple-platform engineering
- **Reviewers:** Product, backend, security, accessibility
- **Status:** Draft
- **Audience:** Engineering, QA, release owners
- **Canonical responsibility:**
  - Test architecture.
  - Fixtures.
  - Failure injection.
  - CI.
  - UI automation.
  - Accessibility tests.
  - Performance.
  - Energy.
  - Security tests.
  - Release quality gates.
- **Depends on:** All feature and architecture specifications.
- **Referenced by:** Roadmap and release checklist.

## 5.17 Roadmap

### `macos-roadmap.md`

- **Title:** Voca for macOS Delivery Roadmap
- **Owner:** Product and engineering leadership
- **Reviewers:** Design, backend, QA, security, release engineering
- **Status:** Draft
- **Audience:** All delivery stakeholders
- **Canonical responsibility:**
  - Delivery phases.
  - Critical path.
  - MVP.
  - Differentiation scope.
  - Dependencies.
  - Risks.
  - Decision checkpoints.
  - Phase exit criteria.
- **Depends on:** Full documentation set.
- **Referenced by:** Planning and implementation tracking.

## 5.18 Decision register

### `macos-decisions.md`

- **Title:** Voca for macOS Decision Register
- **Owner:** Architecture owner
- **Reviewers:** Decision-specific stakeholders
- **Status:** Active Draft
- **Audience:** Product, design, engineering, QA, security
- **Canonical responsibility:**
  - Accepted decisions.
  - Proposed decisions.
  - Rejected alternatives.
  - Deferred decisions.
  - Superseded decisions.
  - Decision ownership.
- **Depends on:** Supporting evidence from relevant specifications.
- **Referenced by:** Every implementation phase.

---

## 6. Cross-document dependency map

```text
Overview
└── Product Requirements
    ├── Information Architecture
    │   └── Design System
    │       ├── Today
    │       ├── Vocabulary
    │       ├── Review
    │       ├── Quick Lookup
    │       ├── Menu Bar
    │       ├── Practice and AI
    │       └── Import and Capture
    │
    ├── Application Architecture
    │   ├── Data and Synchronization
    │   ├── System Integrations
    │   ├── Security and Privacy
    │   └── Testing
    │
    └── Roadmap
        └── Decision Register
```

### 6.1 Core application dependency

```text
Authentication
→ account environment
→ networking
→ repositories
→ Vocabulary
→ Review
→ Today
```

### 6.2 Local-first dependency

```text
Persistence decision
→ local vocabulary
→ local search
→ synchronization
→ Quick Lookup
→ menu bar
→ Spotlight
→ widgets
```

### 6.3 Review dependency

```text
Stable user-card identity
→ due-card query
→ review session
→ durable review event
→ idempotent backend acceptance
→ offline review
→ Mini Review
→ interactive review integrations
```

### 6.4 AI dependency

```text
Vocabulary source
→ visible context selection
→ provider configuration
→ request lifecycle
→ streaming
→ structured validation
→ practice or Assistant UI
```

### 6.5 Import dependency

```text
Source access
→ local extraction
→ candidate generation
→ duplicate classification
→ candidate review
→ idempotent commit
→ synchronization
```

---

## 7. Requirement coverage

## 7.1 Application shell: `APP-*`

Primary documents:

- [`macos-information-architecture.md`](macos-information-architecture.md)
- [`macos-architecture.md`](macos-architecture.md)
- [`macos-design-system.md`](macos-design-system.md)

Validated by:

- [`macos-testing.md`](macos-testing.md)

Delivered through:

- Roadmap Phases 1 and 2.

## 7.2 Authentication: `AUTH-*`

Primary documents:

- [`macos-architecture.md`](macos-architecture.md)
- [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

Supporting documents:

- [`macos-data-and-sync.md`](macos-data-and-sync.md)
- [`macos-system-integrations.md`](macos-system-integrations.md)

Validated by:

- Authentication, Keychain, account-isolation, and sign-out suites in [`macos-testing.md`](macos-testing.md).

## 7.3 Today: `TODAY-*`

Primary document:

- [`macos-today.md`](macos-today.md)

Dependencies:

- Vocabulary.
- Review.
- Data and synchronization.
- Practice.

Validated by:

- Today state, goal, streak, and recommendation tests.

## 7.4 Vocabulary: `VOC-*`

Primary document:

- [`macos-vocabulary.md`](macos-vocabulary.md)

Supporting documents:

- Design system.
- Data and synchronization.
- Import and capture.

Validated by:

- Domain, repository, performance, UI, and accessibility tests.

## 7.5 Language support: `LANG-*`

Primary documents:

- [`macos-vocabulary.md`](macos-vocabulary.md)
- [`macos-review.md`](macos-review.md)
- [`macos-design-system.md`](macos-design-system.md)
- [`macos-practice-and-ai.md`](macos-practice-and-ai.md)

Validated by:

- English, Chinese, pinyin, Hanzi, pronunciation, and localization matrices.

## 7.6 Review: `REV-*`

Primary document:

- [`macos-review.md`](macos-review.md)

Critical supporting document:

- [`macos-data-and-sync.md`](macos-data-and-sync.md)

Validated by:

- Review state tests.
- Exactly-once integration tests.
- Offline and recovery tests.

## 7.7 Quick Lookup: `QUICK-*`

Primary document:

- [`macos-quick-lookup.md`](macos-quick-lookup.md)

Dependencies:

- Vocabulary.
- Local search.
- Scene coordination.
- Speech.
- Security.

Validated by:

- Window, focus, display, concurrency, privacy, performance, and accessibility tests.

## 7.8 Menu bar: `MENU-*`

Primary document:

- [`macos-menu-bar.md`](macos-menu-bar.md)

Dependencies:

- Today snapshot.
- Review.
- Quick Lookup.
- Synchronization.

Validated by:

- Lifecycle, Mini Review, launch-at-login, privacy, and energy tests.

## 7.9 AI and practice: `AI-*`

Primary document:

- [`macos-practice-and-ai.md`](macos-practice-and-ai.md)

Supporting documents:

- Security and privacy.
- Vocabulary.
- Today.

Validated by:

- Streaming, context, structured-output, privacy, accessibility, and cancellation tests.

## 7.10 Capture and import: `CAP-*`

Primary document:

- [`macos-import-and-capture.md`](macos-import-and-capture.md)

Supporting documents:

- Security and privacy.
- Data and synchronization.
- Practice and AI.

Validated by:

- Parser, OCR, PDF, duplicate, batch, fuzz, privacy, and export tests.

## 7.11 System integrations: `SYS-*`

Primary document:

- [`macos-system-integrations.md`](macos-system-integrations.md)

Supporting documents:

- Quick Lookup.
- Menu bar.
- Security and privacy.

Validated by:

- App Intent, Spotlight, widget, notification, Services, and cleanup tests.

## 7.12 Synchronization: `SYNC-*`

Primary document:

- [`macos-data-and-sync.md`](macos-data-and-sync.md)

Supporting documents:

- Review.
- Security and privacy.

Validated by:

- Queue, cursor, conflict, retry, migration, restart, and account-isolation tests.

## 7.13 Security: `SEC-*`

Primary document:

- [`macos-security-and-privacy.md`](macos-security-and-privacy.md)

Validated by:

- Security-marker scans.
- Keychain tests.
- malicious-input tests.
- sign-out and deletion tests.
- release security gates.

## 7.14 Accessibility: `A11Y-*`

Primary documents:

- [`macos-design-system.md`](macos-design-system.md)
- [`macos-testing.md`](macos-testing.md)

Every feature document also owns feature-specific accessibility behavior.

## 7.15 Performance and reliability: `PERF-*`, `REL-*`

Primary documents:

- [`macos-testing.md`](macos-testing.md)
- [`macos-data-and-sync.md`](macos-data-and-sync.md)
- [`macos-architecture.md`](macos-architecture.md)

Feature documents own their individual latency, loading, cancellation, and recovery expectations.

---

## 8. Accepted decision summary

The decision register currently records these principal accepted directions:

1. Add the first macOS target inside the existing Apple project.
2. Share domain and infrastructure rather than root platform UI.
3. Route feature behavior through application use cases and repositories.
4. Use typed routes and scene coordination.
5. Use semantic tokens and system surfaces.
6. Use native macOS navigation, tables, toolbars, inspectors, menus, and commands.
7. Make Table the default Vocabulary presentation.
8. Use the local store as the primary read source after bootstrap.
9. Partition all private records and operations by account.
10. Serialize token refresh.
11. Persist review events before advancing.
12. Keep Practice separate from FSRS Review.
13. Implement Quick Lookup as a single-instance floating panel.
14. Store secrets only through Keychain-backed services.
15. Use allowlist-based logs and diagnostics.
16. Inject time, identity, randomness, locale, and connectivity in tests.
17. Preserve iOS buildability throughout macOS delivery.

The authoritative details remain in:

[`macos-decisions.md`](macos-decisions.md)

---

## 9. Open decision summary

## 9.1 P0 decisions

Resolve before or during target bootstrap:

- Minimum macOS target.
- App Sandbox and entitlement policy.
- XcodeGen ownership.
- Distribution channel.
- macOS bundle identifiers.
- Signing team and release identity.

Resolve before persistence:

- Database technology.
- Account database partition strategy.
- Sync protocol capability.

Resolve before offline Review:

- Backend review-event idempotency.
- Review-event ordering.
- Reconciliation response.

## 9.2 P1 decisions

- Spotlight default.
- Menu bar onboarding default.
- AI-history persistence behavior.
- Initial structured import formats.
- soft deletion and Trash.
- due-count and daily-goal server contracts.

## 9.3 P2 and P3 decisions

- Default Quick Lookup shortcut.
- Repository relocation.
- local Swift-package extraction.
- Dock-icon behavior.
- interactive widgets.
- microphone conversation practice.
- Anki import.
- field-level encryption.

---

## 10. Backend blocker summary

## 10.1 Release-critical

### Stable entity identity

Needed for:

- Selection.
- Deep links.
- Spotlight.
- Widgets.
- synchronization.
- duplicate detection.

Required for:

- Vocabulary and Review correctness.

### Review-event idempotency

Needed for:

- Safe retry.
- Offline Review.
- Mini Review.
- future interactive widgets.

Required contract:

```text
Same operation ID
→ one accepted event
→ same authoritative result on retry
```

### Entity revisions or equivalent versioning

Needed for:

- Conflict detection.
- Safe notes.
- Smart Lists.
- destructive operations.

## 10.2 Strongly recommended for public release

### Incremental synchronization

Needed for:

- Efficient local-first data.
- multiple devices.
- menu bar.
- widgets.
- Spotlight.

### Tombstones and soft deletion

Needed for:

- Trash.
- restore.
- cross-device deletion.
- reliable incremental sync.

### Due-summary contract

Needed for:

- Today.
- menu bar.
- widgets.
- notifications.

## 10.3 Required for later phases

### Batch card creation

Needed for:

- large imports.
- efficient offline queue reconciliation.

### AI streaming contract

Needed for:

- Assistant.
- Conversation.
- progressive generation.

### Structured practice generation

Needed for:

- validated drills.
- reading questions.
- deterministic UI.

### Cancellation

Needed for:

- AI streams.
- long server generation.
- provider cost control.

### Capability endpoint

Needed to identify:

- Protocol version.
- idempotency support.
- batch limits.
- soft-delete support.
- minimum supported client.

---

## 11. Implementation-readiness matrix

## 11.1 Ready for prototype

### Application shell

Ready assumptions:

- Existing project generator can add a macOS target.
- iOS build remains baseline.

Documents sufficient:

- Overview.
- Requirements.
- Information architecture.
- Architecture.
- Design system.
- Roadmap.
- Decisions.

### Remote-backed Vocabulary

Ready assumptions:

- Existing vocabulary endpoints are usable.
- Stable enough identifiers exist for prototype selection.

Documents sufficient:

- Vocabulary.
- Architecture.
- Design system.
- Testing.

### Online Review

Ready assumptions:

- Existing due and review endpoints work.
- Offline behavior is not claimed yet.

Documents sufficient:

- Review.
- Architecture.
- Testing.

## 11.2 Ready after decisions

### Local persistence

Blocked by:

- Database technology decision.
- Account partition decision.
- schema ownership.

### Quick Lookup

Blocked by:

- Shortcut implementation selection.
- window prototype.
- local-search availability for best experience.

### Menu bar

Blocked by:

- Lifecycle decision validation.
- Today snapshot.
- energy baseline.

## 11.3 Ready after backend contracts

### Offline Review

Blocked by:

- Idempotent review submission.
- authoritative reconciliation.

### Incremental sync

Blocked by:

- change cursor.
- revisions.
- tombstones.

### Trash and restore

Blocked by:

- backend soft-delete and restore contract.

### Large batch import

Blocked or constrained by:

- batch API and per-item results.

## 11.4 Deferred implementation

- Interactive FSRS widgets.
- Microphone conversation practice.
- Anki package import.
- Synchronized AI history.
- customizable database columns.
- multiple simultaneous accounts.
- browser-extension capture.

---

## 12. Feature readiness checklist

A feature is ready for implementation when:

- [ ] Product intent is documented.
- [ ] Scope and non-goals are documented.
- [ ] Main states are documented.
- [ ] Error behavior is documented.
- [ ] Offline behavior is documented.
- [ ] Data ownership is documented.
- [ ] Authentication behavior is documented.
- [ ] Privacy impact is documented.
- [ ] Accessibility behavior is documented.
- [ ] Performance expectations are documented.
- [ ] Dependencies are available or assigned.
- [ ] Backend contracts are available or mocked.
- [ ] Open P0 decisions are resolved.
- [ ] Acceptance scenarios exist.
- [ ] Test strategy exists.
- [ ] Release phase is assigned.

---

## 13. Documentation ownership

Recommended ownership:

```text
Product
├── Overview
├── Product Requirements
├── Today
└── Roadmap

Product Design
├── Information Architecture
└── Design System

Apple-platform Engineering
├── Architecture
├── Vocabulary
├── Quick Lookup
├── Menu Bar
└── System Integrations

Apple-platform + Backend Engineering
├── Review
└── Data and Synchronization

AI / Backend + Product
└── Practice and AI

Apple-platform + Product
└── Import and Capture

Security
└── Security and Privacy

Quality Engineering
└── Testing and Quality Strategy

Architecture Owner
└── Decision Register
```

### 13.1 Owner responsibilities

The owner:

- Keeps the canonical document current.
- Coordinates reviewers.
- Resolves contradictions.
- Updates implementation links.
- Updates document status.
- Ensures accepted decisions are reflected.

### 13.2 Reviewer responsibilities

Reviewers:

- Validate their domain.
- Identify missing dependencies.
- Highlight conflicting requirements.
- Approve or request changes.

---

## 14. Document statuses

Allowed document statuses:

```text
Draft
In Review
Approved
Implementation Active
Implemented
Deprecated
Superseded
```

### 14.1 Draft

Content is being developed.

### 14.2 In Review

The document has a defined review group and no major structural work is expected.

### 14.3 Approved

The responsible stakeholders agree it is sufficient to guide implementation.

### 14.4 Implementation Active

Engineering work is using the specification.

Changes require implementation-impact review.

### 14.5 Implemented

The documented scope exists in a released or release-ready build.

Known differences must be recorded.

### 14.6 Deprecated

The document is retained for history but should not guide new work.

### 14.7 Superseded

A replacement document is named.

---

## 15. Approval expectations

## 15.1 Product documents

Required approval:

- Product owner.
- Design owner.
- Engineering owner.

## 15.2 Architecture documents

Required approval:

- Apple-platform owner.
- Backend owner where relevant.
- Security owner for private data.
- Quality owner for testability.

## 15.3 Security documents

Required approval:

- Security owner.
- Apple-platform owner.
- Backend owner.
- Product owner for user-facing policy.

## 15.4 Release documents

Required approval:

- Product.
- Engineering.
- Quality.
- Security.
- Release owner.

---

## 16. Cross-document consistency rules

### 16.1 Requirement identifiers

Do not create a new requirement identifier in a feature document without updating:

- Product requirements.
- Requirement coverage in this index.
- Testing traceability.

### 16.2 Terminology

Use the same terms everywhere:

```text
Today
Vocabulary
Review
Practice
Assistant
Conversation
Insights
Smart List
Quick Lookup
Due cards
Daily goal
```

### 16.3 Account terminology

Distinguish:

- Sign out.
- Remove local data.
- Delete remote account.

### 16.4 Data terminology

Distinguish:

- Dictionary entry.
- User card.
- Vocabulary item.
- Review event.
- Practice answer.
- Pending mutation.

### 16.5 AI terminology

Distinguish:

- Canonical content.
- User-authored content.
- AI-generated content.

### 16.6 Status terminology

Use consistent synchronization states:

```text
Synced
Syncing
Offline
Waiting to sync
Action required
```

---

## 17. Contradiction resolution

When documents disagree:

1. Check the Decision Register.
2. Prefer the document with canonical ownership of the concern.
3. Review the more recently accepted decision.
4. Update every conflicting document.
5. Do not implement an undocumented compromise.

Examples:

- Review event semantics are owned by Review plus Data and Sync.
- Visual review controls are owned by Design System plus Review.
- AI transmission policy is owned by Security and Privacy.
- Feature delivery timing is owned by Roadmap.
- Route syntax is owned by Information Architecture and System Integrations.

---

## 18. Documentation update triggers

Update documentation when:

- A requirement changes.
- A backend contract changes.
- A decision is accepted.
- A feature enters implementation.
- A prototype disproves an assumption.
- A security control changes.
- A permission or entitlement changes.
- A route changes.
- A persistent schema changes.
- A release defers committed scope.
- User testing changes expected behavior.

---

## 19. Pull-request expectations

A pull request should update documentation when it changes:

- User-visible behavior.
- Error or offline behavior.
- Database schema.
- Synchronization semantics.
- Authentication.
- Deep-link route.
- Shortcut.
- System integration.
- Privacy or retention.
- Accepted architecture.
- Release scope.

Suggested pull-request checklist:

```text
[ ] Product behavior matches specification
[ ] Relevant ADR is linked
[ ] Tests cover acceptance criteria
[ ] Security and privacy impact reviewed
[ ] Documentation updated
[ ] iOS impact reviewed
```

---

## 20. Document-link validation

Documentation CI should eventually verify:

- Relative links resolve.
- Referenced files exist.
- Duplicate requirement IDs are detected.
- ADR IDs are unique.
- Every document contains status and last-updated metadata.
- Deprecated documents identify replacements.

Potential later tooling:

```text
scripts/validate-macos-docs.sh
```

The validator should not require network access.

---

## 21. Documentation release checklist

Before private beta:

- [ ] Core documents are at least In Review.
- [ ] P0 decisions are Accepted.
- [ ] Known offline limitations are explicit.
- [ ] Backend blockers are assigned.
- [ ] Security behavior matches implementation.
- [ ] Keyboard shortcuts are current.
- [ ] Support diagnostics are documented.

Before public release:

- [ ] Shipped feature documents are Approved or Implemented.
- [ ] Requirement traceability is current.
- [ ] Release gates match CI and manual validation.
- [ ] Deferred features are clearly excluded.
- [ ] Known limitations are published.
- [ ] Deep links and system integrations are documented.
- [ ] Sign-out and data-deletion behavior are accurate.
- [ ] User help links to current behavior.

---

## 22. Current documentation health

### Strengths

The current documentation set covers:

- Product vision.
- Requirements.
- Information architecture.
- Native macOS design system.
- Vocabulary.
- Review.
- Today.
- Data and synchronization.
- Quick Lookup.
- Menu bar.
- System integrations.
- Practice and AI.
- Import and capture.
- Security and privacy.
- Testing.
- Roadmap.
- Decision governance.

### Work remaining

Before implementation begins:

- Resolve P0 decisions.
- Audit existing iOS code against architecture assumptions.
- Audit backend contracts.
- Assign owners.
- Move core documents to In Review.
- Create implementation work items.

Before release:

- Add implementation links.
- Record accepted deviations.
- Update statuses.
- Validate documentation links.
- Produce user-facing help and release notes.

---

## 23. Immediate next actions

Recommended sequence:

1. Review [`macos-decisions.md`](macos-decisions.md).
2. Resolve the P0 decision backlog.
3. Audit the existing iOS project and backend contracts.
4. Update document statuses and owners.
5. Create implementation issues for Roadmap Phase 0 and Phase 1.
6. Add the macOS target.
7. Add dual-platform CI.
8. Begin the authentication and Vocabulary prototype.

---

## 24. Implementation issue template

Suggested issue content:

```markdown
# Objective

What user or architecture outcome should this work deliver?

## Scope

- Included:
- Excluded:

## Specification

- Primary document:
- Requirements:
- ADRs:

## Dependencies

- Client:
- Backend:
- Design:
- Security:

## Acceptance criteria

- [ ]

## Tests

- Unit:
- Integration:
- UI:
- Accessibility:
- Performance:
- Security:

## Documentation updates

- [ ]
```

---

## 25. Architecture review template

Suggested review content:

```markdown
# Change summary

## Documents affected

## Decisions affected

## Data ownership

## Account isolation

## Offline behavior

## Failure and recovery

## Security and privacy

## Accessibility

## Performance

## Migration

## Test strategy
```

---

## 26. Final documentation map

```text
docs/
├── macos-documentation-index.md
├── macos-overview.md
├── macos-product-requirements.md
├── macos-information-architecture.md
├── macos-architecture.md
├── macos-design-system.md
├── macos-vocabulary.md
├── macos-review.md
├── macos-today.md
├── macos-data-and-sync.md
├── macos-quick-lookup.md
├── macos-menu-bar.md
├── macos-system-integrations.md
├── macos-practice-and-ai.md
├── macos-import-and-capture.md
├── macos-security-and-privacy.md
├── macos-testing.md
├── macos-roadmap.md
└── macos-decisions.md
```

---

## 27. Definition of done

The documentation set is implementation-ready when:

- Every document has an owner.
- Core product and architecture documents are reviewed.
- P0 decisions are accepted.
- Backend blockers are assigned.
- Requirement coverage is complete.
- Cross-document terminology is consistent.
- Feature acceptance scenarios are testable.
- Security and privacy behavior is explicit.
- Roadmap phases link to implementation work.
- Documentation status reflects reality.
- Link validation passes.

---

## 28. Next step

After this index is created, the next action should be to inspect the repository and documentation set for consistency:

```text
1. List all macOS documents.
2. Verify expected files exist.
3. Validate relative Markdown links.
4. Identify missing referenced documents.
5. Compare requirement identifiers across documents.
6. Report contradictions or duplicate decisions.
7. Produce the first implementation-ready action list.
```
