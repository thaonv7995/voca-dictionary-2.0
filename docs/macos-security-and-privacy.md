# Voca for macOS — Security and Privacy

> Security boundaries, threat model, credential handling, local-data protection, privacy controls, retention, diagnostics, security testing, and release gates for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Security and Privacy Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Related Quick Lookup specification:** [`macos-quick-lookup.md`](macos-quick-lookup.md)
- **Related integrations specification:** [`macos-system-integrations.md`](macos-system-integrations.md)
- **Related AI specification:** [`macos-practice-and-ai.md`](macos-practice-and-ai.md)
- **Related import specification:** [`macos-import-and-capture.md`](macos-import-and-capture.md)
- **Primary requirement groups:** `SEC-*`, `AUTH-*`, `SYNC-*`, `REL-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca for macOS protects:

- Authentication credentials.
- Provider API keys.
- Vocabulary and learning data.
- Personal notes.
- Review history.
- AI conversations.
- Imported documents.
- Clipboard content.
- Microphone and speech data.
- Local caches.
- Widgets, Spotlight, notifications, and other system projections.
- Logs, diagnostics, and analytics.

It also defines:

- Security boundaries.
- Threat assumptions.
- Sensitive-data classification.
- Consent requirements.
- Retention and deletion rules.
- Sign-out behavior.
- Incident response.
- Security testing.
- Release security gates.

The primary security goals are:

> Voca must not expose one account's data to another account, transmit private content without explicit user intent, or lose acknowledged local work during security cleanup and recovery.

---

## 2. Security principles

### SEC-PRN-001 — Minimize collected and retained data

Store only the information required to provide the product behavior.

### SEC-PRN-002 — Secrets belong in Keychain

Passwords, refresh tokens, and provider credentials must not be stored in ordinary preferences, databases, logs, or shared snapshots.

### SEC-PRN-003 — Private content is not ambient by default

Personal vocabulary content must not appear in:

- Widgets.
- Spotlight.
- Notifications.
- Menu bar.

unless the relevant integration and privacy preference permit it.

### SEC-PRN-004 — Transmission is explicit

Clipboard content, imported documents, personal notes, writing drafts, and conversation audio must not be transmitted merely because Voca has access to them.

### SEC-PRN-005 — Accounts are isolated

Every account-scoped record, cache, mutation, system index, and snapshot must have a clear account owner.

### SEC-PRN-006 — Logs use an allowlist

Voca logs only explicitly approved metadata. It does not serialize arbitrary objects and attempt to redact them afterward.

### SEC-PRN-007 — Extensions receive the minimum capability

Widgets and other extensions must not receive the full application database or broad credentials when a small snapshot or route is sufficient.

### SEC-PRN-008 — Security failures remain recoverable

Credential expiry, database repair, sign-out, and account switching must preserve pending user work according to documented policy.

### SEC-PRN-009 — Permissions are requested in context

Voca requests microphone, notification, file, and other permissions only when the user invokes a feature requiring them.

### SEC-PRN-010 — User-facing claims remain accurate

Do not claim:

- End-to-end encryption.
- Secure deletion.
- Local-only processing.
- Anonymous analytics.

unless the implementation and service architecture guarantee the claim.

---

## 3. Scope

### 3.1 Included

- Authentication.
- Keychain.
- Token refresh.
- Account isolation.
- Local database.
- File-system storage.
- App sandbox.
- App Group data.
- Clipboard.
- Global Quick Lookup.
- Menu bar.
- Spotlight.
- Widgets.
- Notifications.
- Imported files.
- OCR.
- AI requests.
- Microphone and speech.
- Logging.
- Diagnostics.
- Analytics.
- Data retention.
- Sign out.
- Local-data deletion.
- Security recovery.
- Security testing.

### 3.2 Related but specified elsewhere

- Detailed synchronization behavior.
- Feature-specific UX.
- Release packaging.
- Backend infrastructure security.
- Server-side authorization implementation.

### 3.3 Out of scope

This document does not claim to define:

- The backend's complete production security program.
- Organizational incident-response policy outside the product.
- Provider-specific legal terms.
- Enterprise device-management policy.
- Formal regulatory compliance certification.

Those areas require separate review where applicable.

---

## 4. Security objectives

### SEC-OBJ-001 — Credential confidentiality

An attacker reading ordinary app files, preferences, logs, exports, or diagnostics should not obtain authentication or provider credentials.

### SEC-OBJ-002 — Account confidentiality

A signed-out or different signed-in account must not see another account's private data through any application or system surface.

### SEC-OBJ-003 — Data integrity

Malformed input, stale synchronization, duplicate retries, or extension actions must not silently corrupt user data.

### SEC-OBJ-004 — Explicit AI disclosure

Users must know when their content will be sent to an AI provider.

### SEC-OBJ-005 — Safe local recovery

Database migration, corruption recovery, and authentication expiry should preserve pending mutations and user-authored content.

### SEC-OBJ-006 — Minimal system projection

Spotlight, widgets, notifications, and menu bar surfaces contain only approved data.

### SEC-OBJ-007 — Safe import processing

Untrusted documents and structured files must be parsed with size, schema, and resource limits.

### SEC-OBJ-008 — Diagnostic safety

Support data must be useful without containing secrets or unnecessary private content.

---

## 5. Threat model

### 5.1 Protected assets

High-sensitivity assets:

- Passwords.
- Refresh tokens.
- Access tokens.
- AI provider API keys.
- Authentication cookies where applicable.
- Security-scoped persistent bookmarks where applicable.

Private user assets:

- Saved vocabulary.
- Personal notes.
- Tags and topics.
- Review history.
- Daily learning activity.
- AI prompts and responses.
- Conversation transcripts.
- Imported document content.
- Clipboard-derived text.
- Voice recordings and transcripts.

Operational assets:

- Pending mutations.
- Local review events.
- Sync cursors.
- Database migrations.
- Diagnostic identifiers.

### 5.2 Threat actors

Consider:

- Another local macOS account user with file access caused by incorrect permissions.
- Another Voca account using the same app installation.
- Malicious imported files.
- Untrusted text embedded in imported documents.
- A compromised or malicious external provider.
- A network attacker where transport security is misconfigured.
- A malicious deep link.
- An extension with excessive data access.
- Accidental exposure during screen sharing.
- Accidental inclusion of private content in logs or analytics.
- User error during sign out or data deletion.

### 5.3 Trust assumptions

Voca assumes:

- macOS security boundaries and Keychain function as designed.
- The signed application has not been modified.
- The authenticated backend enforces server-side authorization.
- Users control their macOS account.

Voca must not assume:

- Imported files are safe.
- Clipboard content is harmless.
- AI-generated links are trustworthy.
- A successful local network check means the backend is authentic or available.
- Visible word text uniquely identifies an entity.
- Every installed extension should access all account data.

### 5.4 Primary threat scenarios

1. Credentials accidentally written to logs.
2. Account A data displayed after Account B signs in.
3. Signed-out widgets retaining Account A vocabulary.
4. Spotlight retaining deleted or signed-out private content.
5. Clipboard content uploaded without explicit action.
6. Personal notes included in AI requests by default.
7. Imported text manipulating the AI task through prompt injection.
8. Malicious deep links targeting another account's entity.
9. CSV export triggering spreadsheet formulas.
10. Duplicate review submission changing FSRS state twice.
11. Database migration dropping pending offline work.
12. Diagnostics export including private request bodies.
13. Notification previews exposing vocabulary on a shared screen.
14. Temporary OCR files remaining indefinitely.
15. A widget or intent reading broad Keychain credentials unnecessarily.

---

## 6. Data classification

### 6.1 Class A — Secrets

Examples:

- Password.
- Refresh token.
- Access token.
- Provider API key.
- Private authentication material.

Rules:

- Keychain only.
- Never logged.
- Never included in diagnostics.
- Never included in App Group snapshots.
- Never included in exports.
- Removed according to credential lifecycle.

### 6.2 Class B — Highly private content

Examples:

- Personal notes.
- AI prompts and responses.
- Imported document text.
- Clipboard text.
- Voice recordings.
- Conversation transcripts.

Rules:

- Minimize retention.
- Never include in analytics.
- Never place in Spotlight by default.
- Never show in widgets.
- Transmit only after explicit action.
- Apply account isolation.

### 6.3 Class C — Private learning data

Examples:

- Saved vocabulary.
- Tags.
- Review history.
- Due dates.
- Daily goal.
- Streak.
- Practice results.

Rules:

- Account-scoped.
- May appear in system projections only through user-controlled policy.
- Excluded from ordinary diagnostics content.

### 6.4 Class D — Operational metadata

Examples:

- Request ID.
- Operation ID.
- Error category.
- Duration.
- Queue count.
- Sync timestamp.

Rules:

- May be logged when nonidentifying.
- Must not encode secret or content data.
- Retain only as long as needed.

### 6.5 Class E — Public or shared content

Examples:

- Public dictionary definition.
- Generic Hanzi stroke data.
- Static application resources.

Rules:

- May be cached across accounts only if licensing and product rules permit.
- Must remain distinct from user-authored data.

---

## 7. Trust boundaries

```text
┌─────────────────────────────────────────────────────────────┐
│ User and macOS                                             │
│ ├── Keyboard and pointer                                   │
│ ├── Clipboard                                              │
│ ├── Files                                                  │
│ ├── Microphone                                             │
│ └── System search and notifications                        │
├─────────────────────────────────────────────────────────────┤
│ Voca main process                                          │
│ ├── UI                                                     │
│ ├── Domain services                                        │
│ ├── Local database                                         │
│ ├── Keychain adapter                                       │
│ └── Synchronization                                        │
├─────────────────────────────────────────────────────────────┤
│ Voca extensions and App Group                              │
│ ├── Widgets                                                │
│ ├── App Intents                                            │
│ └── Versioned snapshots                                    │
├─────────────────────────────────────────────────────────────┤
│ Network services                                           │
│ ├── Voca backend                                           │
│ ├── AI provider                                            │
│ └── TTS provider                                           │
└─────────────────────────────────────────────────────────────┘
```

Every transition between boundaries requires:

- Authentication or permission where applicable.
- Input validation.
- Data minimization.
- Explicit ownership.
- Error handling.
- Logging restrictions.

---

## 8. Application sandbox and entitlements

### 8.1 Sandbox

The release application should use the macOS App Sandbox unless a documented product requirement makes it impossible.

### 8.2 Entitlement minimization

Enable only required entitlements.

Potential entitlements:

- Outgoing network connections.
- User-selected file read access.
- App Group.
- Keychain access group.
- Notifications.
- Microphone, only if speech input ships.

### 8.3 Forbidden broad access

Do not request:

- Full disk access.
- Accessibility control.
- Screen recording.
- Input monitoring.

unless a separately reviewed feature has no safer implementation.

### 8.4 Global shortcut

Choose a shortcut implementation that avoids broad keyboard-monitoring permissions where possible.

### 8.5 Selected-text capture

Prefer:

- macOS Services.
- App Intents.
- Explicit paste.

over broad Accessibility API access.

### 8.6 Entitlement inventory

Maintain a documented list containing:

- Entitlement.
- Owning feature.
- Reason.
- Data accessed.
- Removal condition.

---

## 9. Authentication

### 9.1 Credential flow

```text
User enters credentials
→ credentials sent over approved transport
→ backend returns session tokens
→ tokens stored through credential service
→ password discarded from memory as soon as practical
```

### 9.2 Password handling

- Use secure text input.
- Do not persist.
- Do not log.
- Do not include in crash context.
- Clear form state after successful authentication.

### 9.3 Access token

Use only for authenticated requests.

Storage policy should prefer:

- Memory where practical.
- Keychain only if required for session restoration.

### 9.4 Refresh token

- Store in Keychain.
- Rotate atomically.
- Remove on sign out.
- Never place in database or App Group.

### 9.5 Token refresh

Refresh is serialized:

1. One refresh operation begins.
2. Concurrent callers await it.
3. New credentials are stored atomically.
4. Old credentials are invalidated.
5. Eligible requests retry once.

### 9.6 Reauthentication

Required when:

- Refresh fails.
- Account security policy demands it.
- Sensitive operation requires recent authentication.

Pending local work remains preserved.

### 9.7 Server configuration

If custom backend URLs are supported:

- Validate scheme and host.
- Production should require HTTPS.
- Development exceptions must be build- or environment-controlled.
- Credentials must be partitioned by normalized server identity.

### 9.8 Account authorization

The client must never rely on local UI state as authorization.

The backend must verify:

- Account ownership.
- Entity access.
- Mutation permission.
- Administrative actions.

---

## 10. Keychain

### 10.1 Stored values

Potential Keychain items:

- Refresh token.
- Persisted access token if required.
- AI provider API keys.
- TTS provider key.
- Account-bound encryption key where approved.

### 10.2 Key naming

Keychain identity should include:

- Bundle environment.
- Normalized server identity.
- Account ID.
- Credential purpose.

### 10.3 Access control

Use the least permissive accessibility class compatible with product behavior.

### 10.4 Access groups

Do not share credentials with extensions by default.

Create a Keychain access group only when:

- A specific integration requires it.
- The integration's threat and lifecycle model is documented.
- The shared item is narrowly scoped.

### 10.5 Provider keys

Provider keys:

- Are never returned to ordinary UI after storage.
- May be replaced.
- May be deleted.
- May be tested through an explicit action.

### 10.6 Error handling

Keychain errors must:

- Avoid printing item data.
- Distinguish unavailable, missing, and access-denied states.
- Provide safe recovery.

### 10.7 Migration

Keychain migration must not:

- Duplicate account credentials across environments.
- Associate a token with the wrong server.
- expose a secret through intermediate preferences.

---

## 11. Local database protection

### 11.1 Storage location

Use an application-controlled sandbox location under Application Support.

### 11.2 File permissions

Database and related files must be readable and writable only under the user's application context.

### 11.3 Account partitioning

Every account-scoped table or store includes a stable account owner.

Preferred defense in depth:

- Separate account database directories.
- Account predicates in repositories.
- Account-bound service graph.

### 11.4 Secrets

Do not store:

- Passwords.
- Raw tokens.
- Provider keys.

### 11.5 Personal-note encryption

Field-level encryption should be evaluated for:

- Personal notes.
- Conversation transcripts.
- Imported text retained for recovery.

The decision must consider:

- Key lifecycle.
- Searchability.
- Migration.
- Extension access.
- Backup behavior.
- Recovery after credential loss.

Do not add ineffective encryption that stores the key beside the ciphertext without a defined threat benefit.

### 11.6 Database backups

Temporary migration backups:

- Are account-scoped.
- Follow limited retention.
- Receive the same protection as the primary database.
- Are deleted after validated migration.

### 11.7 WAL and auxiliary files

Security and deletion routines must account for:

- Write-ahead log.
- Shared-memory file.
- Temporary database files.

### 11.8 Integrity

Run integrity checks:

- After suspicious open failure.
- During explicit repair.
- In release testing.

Do not run expensive checks on every launch without evidence they are needed.

---

## 12. Account isolation

### 12.1 Application environment

Each signed-in account receives an account-scoped dependency graph.

### 12.2 Account switch sequence

```text
Pause account-scoped tasks
→ cancel streams and imports
→ close private routes
→ clear system projections
→ tear down repositories
→ switch storage partition
→ build new account environment
→ load new account state
```

### 12.3 Selection and restoration

Window restoration must not restore:

- Account A's word route.
- Account A's assistant conversation.
- Account A's Smart List.

after Account B signs in.

### 12.4 Pending operations

Mutation queue entries remain bound to their originating account.

They must never submit using another account's token.

### 12.5 Audio and shared resources

User-specific generated audio remains account-scoped unless it is demonstrably public shared content.

### 12.6 Tests

Every account-scoped repository requires cross-account isolation tests.

---

## 13. Network security

### 13.1 Transport

Production communication should use HTTPS.

### 13.2 Certificate validation

Use platform-standard certificate validation unless a separately reviewed enterprise or development requirement exists.

### 13.3 Insecure development servers

HTTP exceptions:

- Development builds only.
- Explicitly configured.
- Clearly indicated.
- Excluded from production entitlement and configuration.

### 13.4 Request headers

Authorization headers:

- Added centrally.
- Redacted from logs.
- Removed from redirect flows where origin changes.

### 13.5 Redirects

Authenticated requests must not forward sensitive headers to an unrelated origin.

### 13.6 Response limits

Set bounded limits for:

- Ordinary JSON responses.
- Event streams.
- Audio.
- Document downloads.

### 13.7 Timeouts

Use appropriate:

- Connection timeout.
- Request timeout.
- Stream inactivity timeout.

Preserve user drafts on failure.

### 13.8 Retry

Retry only safe operations or requests protected by idempotency.

### 13.9 Server error content

Do not display raw response bodies directly to users.

Do not log full bodies by default.

---

## 14. Input validation

### 14.1 Validation layers

Validate at:

- UI boundary.
- Application-use-case boundary.
- Persistence boundary.
- Network request boundary.
- Backend.

### 14.2 Text limits

Define maximum sizes for:

- Word.
- Meaning.
- Example.
- Personal note.
- AI prompt.
- Conversation message.
- Imported document.
- Deep-link query.

### 14.3 Identifier validation

Validate:

- Format.
- Length.
- Expected identifier type.
- Account ownership.

### 14.4 Enum values

Unknown enum values should:

- Decode safely where possible.
- Avoid crashing.
- Remain unusable for invalid mutations.

### 14.5 Rich text and Markdown

Generated or imported Markdown must:

- Use a safe subset.
- Escape unsafe HTML.
- Validate links.
- Avoid executing embedded scripts.

### 14.6 Structured generation

AI-generated structured data requires schema validation before interaction or persistence.

---

## 15. Deep-link security

### 15.1 Allowed routes

Only documented canonical routes are accepted.

### 15.2 Protected entities

Opening an entity requires:

- Valid signed-in account.
- Entity ownership or access.
- Existing local or remote record.

### 15.3 Query parameters

Must not contain:

- Tokens.
- API keys.
- Passwords.
- Large private documents.

### 15.4 Length limits

Reject excessive:

- URL length.
- Query text.
- Identifier length.

### 15.5 Pending authentication route

Persist only a typed safe route.

Do not persist raw sensitive URL input across authentication.

### 15.6 Error behavior

Malformed or unauthorized links:

- Do not crash.
- Do not reveal whether another account owns the entity.
- Open a safe destination with a generic unavailable message.

---

## 16. Clipboard

### 16.1 Default behavior

Continuous clipboard monitoring is disabled by default.

### 16.2 Quick Lookup suggestion

Clipboard may be read only when:

- User opens Quick Lookup.
- The suggestion preference is enabled.

### 16.3 Local processing

Clipboard candidate validation occurs locally.

### 16.4 Network transmission

Clipboard text is sent only after:

- User accepts Search.
- User explicitly performs an AI action.

### 16.5 Persistence

Do not persist raw clipboard history.

To suppress repeated suggestions, use:

- Short-lived nonreversible fingerprint.

### 16.6 Sensitive-content heuristics

Suppress automatic suggestion for content resembling:

- Access tokens.
- Private keys.
- Password-like random values.
- Payment-card numbers.
- Large multiline secrets.

These heuristics do not guarantee sensitivity detection.

### 16.7 Logs and analytics

Clipboard content is never logged or included in analytics.

### 16.8 User control

Provide:

- Enable.
- Disable.
- Pause.
- Explanation.

---

## 17. Imported files

### 17.1 Local-first processing

Perform locally:

- File inspection.
- PDF extraction.
- OCR.
- CSV parsing.
- JSON validation.
- Candidate generation.

### 17.2 File access

Use:

- Native open panel.
- User-selected file entitlement.
- Security-scoped access where needed.

### 17.3 Original file

Voca does not modify the original source.

### 17.4 Temporary copies

Temporary copies:

- Are account-scoped.
- Have documented retention.
- Are removed after completion, cancellation, or expiry.

### 17.5 Malicious files

Enforce:

- Size limits.
- Page limits.
- Row limits.
- Nested-structure limits.
- Time and memory bounds.

### 17.6 PDF

Do not execute:

- Embedded scripts.
- Actions.
- Attachments.

### 17.7 AI transmission

Dropping a file does not upload it.

Before AI processing, show:

- Provider.
- Amount of content.
- Whether full text or candidate excerpts are sent.

### 17.8 File paths

Avoid displaying or logging full local paths unless explicitly required for user troubleshooting.

---

## 18. CSV and export security

### 18.1 Spreadsheet formula injection

Exported CSV fields that begin with formula-like prefixes require a defined mitigation:

```text
=
+
-
@
```

Possible policy:

- Quote all fields.
- Prefix risky fields for spreadsheet safety.
- Offer a raw-data option with warning.

The chosen behavior must preserve legitimate language content and be tested in common spreadsheet applications.

### 18.2 Export scope

The export preview identifies:

- Collection.
- Item count.
- Included fields.
- Notes included or excluded.
- Review data included or excluded.

### 18.3 Sensitive defaults

Excluded by default:

- Personal notes.
- Review history.
- AI conversations.
- Imported document text.

Never included:

- Credentials.
- Provider keys.
- Internal mutation payloads.

### 18.4 Export destination

Use native save panel.

Voca writes only to the selected location.

### 18.5 Temporary export file

Use protected temporary staging and atomic final replacement where feasible.

---

## 19. AI provider transmission

### 19.1 Explicit action

AI requests begin only through actions such as:

- Send.
- Generate.
- Explain.
- Compare.
- Regenerate.

### 19.2 Default exclusions

Exclude by default:

- Personal notes.
- Full imported documents.
- Clipboard history.
- Review history.
- Unrelated vocabulary.
- Older conversation history beyond context need.

### 19.3 Context preview

Required for:

- Long imported text.
- Personal notes.
- Large Smart Lists.
- New provider destination.
- Sensitive-looking content where detected.

### 19.4 Provider identity

The user should be able to understand:

- Whether Voca's service or a configured provider processes the request.
- Which provider is selected.
- Which model is selected where useful.

### 19.5 Prompt injection

Imported or external content is treated as data.

The context builder must:

- Delimit external content.
- Keep product task instructions separate.
- Ignore instructions embedded in source text.
- Validate structured results.

### 19.6 Response handling

AI output:

- Is untrusted generated content.
- Uses safe rendering.
- Does not execute links or scripts.
- Requires validation before becoming interactive exercises.

### 19.7 Cancellation

Cancellation stops local processing and remote requests where supported.

It may not reverse provider usage already incurred.

### 19.8 Retention

Conversation retention policy must be visible and configurable.

Initial recommendation:

- Local persistence.
- User-controlled deletion.
- No cross-device synchronization until separately approved.

---

## 20. Provider API keys

### 20.1 Storage

Keychain only.

### 20.2 Input

- Secure field.
- Optional temporary reveal.
- Explicit Save.

### 20.3 Display after save

Show:

- Configured.
- Last validation status.
- Provider.

Do not show the complete key.

### 20.4 Test Connection

Validation:

- Uses a minimal request.
- Distinguishes invalid credentials from network failure.
- Avoids sending user content.

### 20.5 Deletion

Delete Provider Key:

- Removes Keychain item.
- Cancels provider-specific pending work where needed.
- Does not delete previously generated content automatically.

### 20.6 Diagnostics

Provider errors are summarized.

Raw provider responses are not included by default.

---

## 21. Microphone and speech

### 21.1 Permission

Request microphone permission only when the user starts a voice-input feature.

### 21.2 Recording indicator

While recording:

- Show visible state.
- Show Stop.
- Respect system permission status.

### 21.3 Capture boundaries

Do not record:

- In background without explicit active feature.
- Merely because Conversation is open.
- After the user stops.

### 21.4 Transcription

If remote transcription is used:

- Explain transmission.
- Identify provider.
- Retain audio only as required.

### 21.5 Local speech recognition

If local recognition is available:

- Accurately label local behavior.
- Do not claim it is local if the framework uses remote processing under current system conditions.

### 21.6 Audio retention

Default:

- Do not retain raw microphone audio after transcription and request completion.

If retention is added:

- Require explicit setting.
- Define purpose and deletion controls.

### 21.7 TTS

Text sent to remote TTS follows the same explicit-provider rules.

Avoid transmitting personal notes for pronunciation unless explicitly requested.

---

## 22. Spotlight

### 22.1 User control

Setting:

```text
Show saved vocabulary in Spotlight
```

### 22.2 Indexed data

Allowed:

- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meaning.
- Language.
- Deep-link identifier.

### 22.3 Excluded data

- Personal notes.
- Review history.
- AI conversations.
- Imported text.
- Provider settings.

### 22.4 Sign out

Remove account-specific Spotlight entries promptly.

### 22.5 Disable

Disabling integration:

- Removes existing entries.
- Stops future indexing.

### 22.6 Deep-link resolution

Even if a stale result remains briefly:

- Revalidate account.
- Revalidate entity.
- Do not show unauthorized content.

---

## 23. Widgets and App Group

### 23.1 Snapshot-only principle

Widgets consume a compact, versioned snapshot.

### 23.2 Allowed snapshot data

- Due count.
- Daily-goal progress.
- Streak.
- Word of the day when enabled.
- Updated time.
- Privacy mode.

### 23.3 Prohibited snapshot data

- Credentials.
- Personal notes.
- AI conversations.
- Full vocabulary database.
- Imported files.
- Mutation payloads.

### 23.4 Atomic replacement

Snapshots are written atomically.

### 23.5 Sign out

- Replace snapshot with signed-out state.
- Reload widgets.
- Clear pending routes.

### 23.6 Account switch

Never merge snapshots.

The active account's snapshot wholly replaces the prior one.

### 23.7 Stale snapshot

Widgets display safe stale state or Open Voca.

They must not decode partial private data.

---

## 24. Menu bar

### 24.1 Private content

User setting controls:

```text
Show vocabulary content in the menu bar
```

### 24.2 Due count

Numeric due count is optional.

### 24.3 Signed-out state

Immediately remove:

- Word of the day.
- Due count.
- Goal.
- Account synchronization state.

### 24.4 Screen sharing

Potential privacy mode may hide vocabulary content.

The first release should provide a manual privacy preference even if automatic screen-sharing detection is not implemented.

### 24.5 Logging

Do not log displayed vocabulary content.

---

## 25. Notifications

### 25.1 Permission

Request in context when the user enables reminders.

### 25.2 Content modes

```text
Private summary
Detailed content
```

### 25.3 Private summary

Examples:

```text
Voca has cards ready for review.
```

```text
A Voca operation needs your attention.
```

### 25.4 Detailed content

May include:

- Due count.
- Daily-goal progress.
- Safe import job name.

Must not include:

- Personal notes.
- Imported excerpts.
- AI prompts.
- Provider error bodies.

### 25.5 Sign out

Remove pending private notifications and scheduled account reminders.

### 25.6 Notification actions

Routes revalidate:

- Authentication.
- Account.
- Entity.

---

## 26. App Intents and Services

### 26.1 Minimal input

Intents and Services receive only explicit user input.

### 26.2 Entity resolution

Vocabulary entities are account-bound.

### 26.3 Credentials

Extensions do not receive broad Keychain access by default.

### 26.4 Selected text

Selected text:

- Is validated.
- Is not logged.
- Is not uploaded automatically.
- Is discarded after cancellation.

### 26.5 AI Service

Explain with Voca opens a context preview before provider transmission.

### 26.6 Mutation

Add Word uses:

- Stable operation ID.
- Duplicate detection.
- Shared repository.

### 26.7 Signed out

Return authentication-required state without exposing retained account content.

---

## 27. Logging

### 27.1 Logging strategy

Use structured logging with categories:

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
security
```

### 27.2 Allowlisted fields

Examples:

- Operation category.
- Request ID.
- Operation ID.
- Duration.
- HTTP status.
- Error category.
- Retry count.
- Entity type.
- Count.
- Build version.

### 27.3 Prohibited fields

- Password.
- Access token.
- Refresh token.
- Authorization header.
- Provider API key.
- Clipboard text.
- Personal note.
- AI prompt or response.
- Imported document text.
- Conversation transcript.
- Typed practice answer.
- Raw microphone audio.

### 27.4 URLs

Sanitize:

- Query parameters.
- User identifiers.
- custom-server credentials.

### 27.5 Request and response bodies

Not logged by default.

Development logging must use synthetic fixtures rather than real user content.

### 27.6 Retention

Define bounded local retention by:

- File size.
- Age.
- Rotation count.

### 27.7 Production level

Production should avoid verbose debug logs.

---

## 28. Diagnostics export

### 28.1 User action

Diagnostics export begins only through an explicit action.

### 28.2 Allowlisted content

May include:

- App version.
- macOS version.
- Architecture.
- Configuration category.
- Feature flags.
- Sanitized log events.
- Database schema version.
- Queue count.
- Last-sync timestamps.
- Error categories.
- Migration results.

### 28.3 Excluded content

- Credentials.
- Provider keys.
- Word content.
- Meanings.
- Personal notes.
- AI prompts and responses.
- Imported text.
- Clipboard content.
- Full database.
- Raw mutation payloads.

### 28.4 User preview

Where practical, show:

- Included categories.
- File size.
- Destination.

### 28.5 Export format

Use a documented archive containing text-based sanitized files.

### 28.6 Support identifier

A one-time support identifier may correlate diagnostics with a support case.

It must not embed credentials or private content.

### 28.7 Verification

Automated tests should scan diagnostic fixtures for:

- Tokens.
- API-key patterns.
- Known private test strings.

---

## 29. Crash reporting

### 29.1 Data minimization

Crash reporting may include:

- Stack trace.
- App version.
- OS version.
- Device architecture.
- Safe breadcrumbs.

### 29.2 Breadcrumb restrictions

Breadcrumbs identify:

- Feature.
- Operation type.
- State category.

They do not identify:

- Word.
- Query.
- Note.
- Document.
- Prompt.

### 29.3 Attachments

Do not attach:

- Database.
- Screenshots.
- Logs with private content.
- Network bodies.

without explicit investigation and user consent.

### 29.4 User control

Crash-report behavior and consent must match the selected reporting system and distribution requirements.

---

## 30. Analytics

### 30.1 Purpose limitation

Analytics should answer product and quality questions without recording vocabulary content.

### 30.2 Allowed dimensions

- Feature category.
- Action category.
- Success or failure.
- Duration.
- Count bucket.
- Language category.
- App version.
- Platform version.

### 30.3 Prohibited dimensions

- Word text.
- Search query.
- Meaning.
- Example.
- Note.
- Tag name.
- AI prompt.
- AI response.
- Imported content.
- Clipboard content.
- Conversation transcript.

### 30.4 Identifiers

Avoid stable cross-context identifiers unless necessary.

Account identifiers should not be sent as raw analytics dimensions.

### 30.5 Opt-out

If product analytics are optional, provide a clear setting.

Essential operational telemetry should be documented separately from optional product analytics.

### 30.6 Event review

Every new event requires:

- Purpose.
- Owner.
- Fields.
- Retention.
- Privacy review.

---

## 31. Data retention

### 31.1 Retention categories

#### Credentials

Retain until:

- Sign out.
- Credential replacement.
- Account removal.

#### Local vocabulary

Retain while:

- Account remains available locally.
- User has not removed local data.

#### Pending mutations

Retain until:

- Accepted.
- User explicitly discards.
- Recovery export is completed under an unrecoverable state.

#### AI conversations

Initial recommendation:

- Retain locally until user deletion or configured cleanup.

#### Imported temporary files

Retain only through:

- Active job.
- Chosen recovery period.

#### Audio cache

Retain under:

- Cache-size policy.
- Last-used policy.

#### Logs

Retain under bounded rotation.

### 31.2 Retention disclosure

Settings should provide understandable storage categories:

- Vocabulary.
- Conversation history.
- Audio cache.
- Temporary imports.
- Diagnostics.

### 31.3 Cleanup

Cleanup must never delete:

- Pending mutations.
- Unsynchronized notes.
- Review events awaiting acceptance.

as if they were cache.

---

## 32. Sign out

### 32.1 Credential cleanup

Remove:

- Access token.
- Refresh token.
- Account session state.

Provider keys may be:

- Account-bound and removed.
- Device-bound and retained.

The product must define the policy clearly.

### 32.2 Private projection cleanup

Remove:

- Widget snapshot.
- Menu bar private state.
- Spotlight records.
- Scheduled private notifications.
- Pending private deep-link data.

### 32.3 Active work

Before sign out:

- Cancel AI streams.
- Stop recording.
- Stop TTS where appropriate.
- Pause imports.
- Pause synchronization.

### 32.4 Pending mutations

If pending changes exist, show:

```text
4 changes have not synchronized.
```

Potential options:

- Sync Then Sign Out.
- Keep Changes on This Mac.
- Discard Local Changes.
- Cancel.

The final choices depend on local-data encryption and authorization policy.

### 32.5 Retained local data

If retained:

- It remains inaccessible after sign out.
- It is excluded from system integrations.
- It cannot be returned by App Intents.

### 32.6 Window cleanup

Dismiss:

- Word windows.
- Assistant conversations.
- Review windows.
- Import windows.

before showing another account's data.

---

## 33. Remove local data

### 33.1 Scope

Remove local account data should delete:

- Account database.
- WAL and auxiliary files.
- Pending mutations.
- Review sessions.
- Local AI history.
- Temporary imports.
- Account audio cache.
- Widget snapshot.
- Spotlight records.
- Pending routes.
- Account credentials.

### 33.2 Remote account

The action must state:

```text
This removes Voca data from this Mac. It does not delete your Voca account or server data.
```

### 33.3 Confirmation

Show:

- Account.
- Pending unsynchronized count.
- Data categories.
- Irreversibility for local-only changes.

### 33.4 Pending work

Offer export or synchronization where possible.

### 33.5 Failure

If cleanup is partial:

- Continue blocking access to the account's data.
- Retry cleanup.
- Report safe categories remaining.

### 33.6 Verification

Automated tests should verify deletion across:

- Database.
- Keychain.
- App Group.
- Spotlight.
- Settings.
- Cache directories.

---

## 34. Remote account deletion

If remote account deletion is introduced:

- Keep it separate from local-data removal.
- Require recent authentication.
- Explain backend retention and irreversibility accurately.
- Avoid executing from a widget or lightweight intent.
- Cancel active sessions.
- Clear local data after server confirmation.

This feature requires dedicated backend and legal review.

---

## 35. Screen sharing and visual privacy

### 35.1 Risk

Quick Lookup, notifications, menu bar, widgets, and word windows may expose learning content during presentations or shared-screen sessions.

### 35.2 Manual privacy mode

Potential setting:

```text
Hide vocabulary content in ambient surfaces
```

Effects:

- Menu bar hides word of the day.
- Widgets use due-only summaries.
- Notifications use private copy.
- Quick Lookup still shows requested content because the user explicitly invoked it.

### 35.3 Automatic detection

Do not claim reliable screen-sharing detection until supported and tested.

### 35.4 Window restoration

After relaunch, do not automatically reopen sensitive Assistant or imported-document content unless restoration policy explicitly permits it.

---

## 36. Undo and clipboard output

### 36.1 Copy actions

Users may copy:

- Word.
- Meaning.
- Example.
- AI response.

### 36.2 Sensitive output

When copying personal notes or conversation content:

- Use explicit user action.
- Do not modify or clear clipboard unexpectedly.

### 36.3 Secret fields

Provider keys should not support ordinary copy after storage.

### 36.4 Undo

Undo history must not persist across account switch.

It must not allow restoration of Account A content while Account B is active.

---

## 37. Dependency and supply-chain security

### 37.1 Dependency minimization

Prefer:

- Apple frameworks.
- Small maintained packages.
- Explicitly versioned dependencies.

### 37.2 Review

Before adding a dependency, review:

- Maintainer activity.
- License.
- Transitive dependencies.
- Network behavior.
- File access.
- Security history.
- Platform support.

### 37.3 Version pinning

Use reproducible dependency resolution.

### 37.4 Automated scanning

CI should detect:

- Known vulnerable dependency versions.
- Unexpected lockfile changes.
- Committed secrets.

### 37.5 Build scripts

Review build plugins and scripts for:

- Network access.
- Environment-secret access.
- Arbitrary code execution.

### 37.6 Generated code

Generated code must:

- Be reproducible.
- Avoid embedded secrets.
- Be reviewed when generator versions change.

---

## 38. Secret management in development and CI

### 38.1 Repository

Never commit:

- Production tokens.
- Provider API keys.
- Signing passwords.
- Private certificates.
- Environment files containing secrets.

### 38.2 Examples

Commit only:

```text
Secrets.example.xcconfig
.env.example
```

with placeholder values.

### 38.3 CI

CI secrets:

- Come from protected secret storage.
- Are scoped to required jobs.
- Are not printed.
- Are not exposed to untrusted pull requests.

### 38.4 Local development

Use:

- Untracked local configuration.
- Keychain.
- Environment variables with safe shell practices.

### 38.5 Secret scanning

Run:

- Pre-commit or CI secret detection.
- Repository-history scan before release.

---

## 39. Security errors and user communication

### 39.1 Principles

Security-related errors should:

- Protect details useful to attackers.
- Explain what the user can do.
- Clarify whether local data remains safe.

### 39.2 Authentication expiry

Example:

```text
Sign in again to continue syncing.
Your saved changes remain on this Mac.
```

### 39.3 Unauthorized entity

Example:

```text
This item is unavailable.
```

Avoid confirming that another account owns it.

### 39.4 Keychain failure

Example:

```text
Voca couldn't access your saved credentials.
Restart Voca or sign in again.
```

### 39.5 Local-data failure

Example:

```text
Voca paused synchronization to protect your local changes.
[Repair] [Export Diagnostics]
```

### 39.6 Provider failure

Distinguish:

- Invalid provider key.
- Network failure.
- Rate limit.
- Unsupported model.

Do not display raw provider response bodies.

---

## 40. Incident and recovery behavior

### 40.1 Suspected credential compromise

Product capabilities should support:

- Sign out all sessions through backend where available.
- Replace local credentials.
- Delete provider keys.
- reauthenticate.

### 40.2 Local corruption

Priority:

1. Stop synchronization.
2. Preserve pending work.
3. Protect user-authored content.
4. Rebuild synchronized data.
5. Rebuild system projections.

### 40.3 Wrong-account exposure

If detected:

- Immediately clear affected UI and projections.
- Stop account work.
- Record a content-free security diagnostic.
- Require reauthentication or restart as appropriate.

### 40.4 Provider misconfiguration

- Disable affected AI actions.
- Preserve drafts.
- Avoid repeated automatic retries.

### 40.5 Failed sign-out cleanup

- Keep the user signed out.
- Hide private data.
- Retry cleanup.
- Do not restore private system projections.

### 40.6 Recovery export

If pending local work cannot synchronize:

- Offer a secure, explicit recovery export where feasible.
- Exclude credentials.
- Explain sensitivity.

---

## 41. Security testing

### 41.1 Authentication tests

- Valid sign in.
- Invalid credentials.
- Token expiry.
- Concurrent refresh failures.
- Refresh-token rotation.
- Sign out.
- Account switch.

### 41.2 Keychain tests

- Store.
- Read.
- Replace.
- Delete.
- Wrong-account key.
- Wrong-server key.
- Access failure.
- Migration.

### 41.3 Account-isolation tests

- Database queries.
- Pending mutations.
- Window restoration.
- Spotlight.
- Widgets.
- Menu bar.
- Notifications.
- App Entities.
- Audio cache.

### 41.4 Deep-link tests

- Malformed URL.
- Oversized query.
- Unauthorized ID.
- Cross-account ID.
- Deleted entity.
- Signed-out continuation.
- Unsupported route.

### 41.5 Import tests

- Malformed PDF.
- Oversized file.
- Deeply nested JSON.
- CSV formula payload.
- Prompt-injection text.
- File-access revocation.
- Temporary-file cleanup.

### 41.6 AI privacy tests

- Notes excluded by default.
- Document preview required.
- Clipboard excluded.
- Prompt absent from logs.
- Cancellation.
- Provider switch.
- Sign out during stream.

### 41.7 Logging tests

Inject known marker secrets and private strings into:

- Login.
- Notes.
- Clipboard.
- AI prompt.
- Imported text.

Verify markers are absent from:

- Logs.
- Analytics.
- Diagnostics.
- Crash breadcrumbs.

### 41.8 Local-data deletion tests

Verify removal from:

- Primary database.
- WAL.
- Temporary files.
- Caches.
- Keychain.
- App Group.
- Spotlight.
- Notifications.
- Preferences.

### 41.9 Permission tests

- Notification denied.
- Microphone denied.
- File access revoked.
- App Group unavailable.
- Keychain denied.

### 41.10 Fuzz and boundary tests

Fuzz:

- Route parser.
- JSON import.
- CSV import.
- AI structured output.
- Search input.
- Markdown renderer.

Boundary test:

- Field lengths.
- Candidate count.
- Page count.
- Widget snapshot size.
- Stream size.

---

## 42. Security tooling

Recommended automated checks:

- Static analysis.
- Swift compiler warnings as errors for selected targets.
- Dependency vulnerability scanning.
- Secret scanning.
- Entitlement inspection.
- Code-signing verification.
- Notarization verification.
- Binary privacy-string inspection.
- Log-content tests.
- Export-content tests.

Manual review should include:

- Keychain accessibility policy.
- App Group contents.
- Sign-out cleanup.
- Spotlight cleanup.
- Widget privacy.
- AI context preview.
- Imported-file behavior.

---

## 43. Privacy settings

Recommended Settings sections:

### General Privacy

```text
Show vocabulary content in menu bar
Show vocabulary content on widgets
Show detailed notification content
Index saved vocabulary in Spotlight
Suggest clipboard text in Quick Lookup
```

### AI Privacy

```text
AI features enabled
Default provider
Include personal notes by default
```

Recommendation:

- Personal notes default remains off and may not need a global enablement at all.

### Data

```text
Clear audio cache
Clear temporary files
Delete AI history
Rebuild Spotlight index
Export diagnostics
Remove local account data
```

### Analytics

```text
Share optional product analytics
```

Settings copy must explain effect, not merely name technology.

---

## 44. Requirement traceability

### `SEC-001` — Keychain

Covered by:

- Credential classification.
- Keychain storage.
- Access-group minimization.
- Credential deletion.

### `SEC-002` — Logging

Covered by:

- Structured logging.
- Allowlisted fields.
- Prohibited fields.
- Diagnostics and crash restrictions.

### `SEC-003` — Clipboard privacy

Covered by:

- Disabled-by-default monitoring.
- Explicit Quick Lookup read.
- Local validation.
- No automatic upload.

### `SEC-004` — AI transmission

Covered by:

- Explicit actions.
- Default exclusions.
- Context preview.
- Provider identity.
- Prompt-injection handling.

### `SEC-005` — Local-data removal

Covered by:

- Removal scope.
- Confirmation.
- Remote-account distinction.
- Verification.

### `AUTH-*`

Covered by:

- Credential handling.
- Session persistence.
- Token refresh.
- Reauthentication.
- Sign out.

### `SYNC-*`

Covered by:

- Account-isolated database.
- Pending-work protection.
- sign-out policy.
- System-projection cleanup.

---

## 45. Acceptance scenarios

### Scenario A — Credential storage

1. Sign in.
2. Inspect ordinary preferences, database, logs, and diagnostics.

Expected:

- Password and tokens are absent.
- Required persistent credentials exist only in Keychain.

### Scenario B — Provider key

1. Save an AI provider key.
2. Relaunch Settings.

Expected:

- Provider shows Configured.
- Full key is not displayed.
- Logs and diagnostics contain no key.

### Scenario C — Account switch

1. Use Account A.
2. Open word, Assistant, widget, and Spotlight content.
3. Switch to Account B.

Expected:

- Account A content disappears everywhere.
- No pending Account A mutation uses Account B credentials.

### Scenario D — Clipboard suggestion

1. Enable suggestion.
2. Copy a word.
3. Open Quick Lookup.

Expected:

- Text is processed locally.
- No request starts before Search.
- Raw text is not retained after dismissal.

### Scenario E — Personal note and AI

1. Add a private note.
2. Ask AI for examples.

Expected:

- Note is excluded.
- Context preview does not claim it is included.

### Scenario F — Imported document

1. Drop a PDF.
2. Extract text.
3. Close before AI action.

Expected:

- PDF is not uploaded.
- Temporary data follows retention policy.

### Scenario G — AI document preview

1. Choose AI enrichment for candidates.

Expected:

- Provider and data scope appear before sending.
- Whole document is excluded by default.

### Scenario H — Spotlight sign out

1. Index vocabulary.
2. Sign out.
3. Search Spotlight.

Expected:

- Private results are removed.
- Any stale route still revalidates and reveals no content.

### Scenario I — Widget sign out

1. Display Word of the Day widget.
2. Sign out.

Expected:

- Word content is replaced by signed-out state.

### Scenario J — Notification privacy

1. Select private-summary notification mode.
2. Trigger a review reminder.

Expected:

- No word or private learning detail appears.

### Scenario K — Diagnostics

1. Use marker values in note, prompt, clipboard, and provider key.
2. Export diagnostics.

Expected:

- Marker values are absent.
- Operational metadata remains useful.

### Scenario L — Local-data removal

1. Create local data, pending mutations, cache, Spotlight entries, and widget snapshot.
2. Remove local account data.

Expected:

- All selected local categories are removed.
- Remote account is not represented as deleted.

### Scenario M — Malicious deep link

1. Open an oversized cross-account word route.

Expected:

- Input is rejected safely.
- No account ownership information is disclosed.
- Raw URL is not logged with sensitive parameters.

### Scenario N — CSV formula export

1. Export a vocabulary field beginning with a formula prefix.
2. Open it in a spreadsheet application.

Expected:

- Selected mitigation prevents unintended formula execution.
- Visible content remains understandable.

### Scenario O — Sign out during AI stream

1. Start generation.
2. Sign out.

Expected:

- Stream is cancelled.
- Private conversation closes.
- No content appears in signed-out system surfaces.

---

## 46. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Passwords, refresh tokens, and provider keys are stored only in Keychain.
2. Account data is isolated through account-scoped stores and service environments.
3. Continuous clipboard monitoring is disabled by default.
4. Clipboard content is never uploaded before explicit user action.
5. Personal notes are excluded from AI context by default.
6. Long imported content requires a transmission preview before AI use.
7. Widgets consume a compact App Group snapshot rather than the full database.
8. Spotlight excludes personal notes, review history, and AI conversations.
9. Signed-out cleanup removes all private system projections.
10. Logs and diagnostics are allowlist-based.
11. Request and response bodies are not logged by default.
12. Production diagnostics never include vocabulary or AI content.
13. Pending mutations and unsynchronized notes are durable user data, not cache.
14. Remote account deletion remains separate from local-data removal.
15. Extensions do not receive broad Keychain access by default.
16. App Sandbox and minimal entitlements are release requirements.
17. Imported content is treated as untrusted data in AI prompts.
18. CSV export includes formula-injection mitigation.

---

## 47. Open questions

1. Which Keychain accessibility classes best support menu bar and launch-at-login behavior?
2. Are provider keys device-bound or account-bound?
3. Should retained signed-out databases use account-bound encryption?
4. Is field-level encryption required for personal notes?
5. Should AI conversations persist locally by default?
6. What is the default retention period for AI history?
7. What is the default retention period for temporary imports?
8. Should Spotlight indexing be enabled by default?
9. Should vocabulary content on widgets be enabled by default?
10. Should notifications default to private summary?
11. Which analytics are essential operational telemetry?
12. What optional analytics platform, if any, will be used?
13. Which crash-reporting platform, if any, will be used?
14. How does the backend revoke all active sessions?
15. Does the backend support recent-authentication checks for sensitive actions?
16. Which custom-server configurations are allowed in release builds?
17. What exact CSV formula mitigation should be implemented?
18. Does microphone input ship in the first release?
19. Does remote TTS receive complete examples or only requested text?
20. What local recovery export is available for unsynchronized work?

---

## 48. Release security gates

The macOS release must not ship until:

- [ ] Production uses approved secure transport configuration.
- [ ] Credentials are absent from preferences, database, logs, analytics, and diagnostics.
- [ ] Keychain lifecycle tests pass.
- [ ] Account-isolation tests pass.
- [ ] Sign-out cleanup passes for widgets, Spotlight, notifications, menu bar, and pending routes.
- [ ] Local-data removal tests pass.
- [ ] Deep-link validation and cross-account tests pass.
- [ ] App Sandbox and entitlements are reviewed.
- [ ] Extension dependencies and App Group contents are reviewed.
- [ ] AI context preview and default exclusions pass.
- [ ] Prompt and response content are absent from diagnostics.
- [ ] Clipboard privacy tests pass.
- [ ] Import size limits and malformed-file tests pass.
- [ ] CSV export injection mitigation is verified.
- [ ] Dependency and secret scans pass.
- [ ] Code signing and notarization pass.
- [ ] No production secret exists in repository history or build artifacts.
- [ ] Privacy settings accurately match implementation.
- [ ] User-facing security claims are reviewed for accuracy.

---

## 49. Definition of done

Security and privacy are complete for the first public release when:

- Sensitive-data classes and owners are documented.
- Secrets are stored only in approved secure storage.
- Account data is isolated in application and system surfaces.
- Local database, caches, and temporary files follow documented protection and retention.
- Clipboard access is user-controlled and locally validated.
- Imported files are processed locally by default.
- AI transmission is explicit and minimized.
- Microphone and speech behavior is permission-aware.
- Spotlight, widgets, notifications, menu bar, App Intents, and Services follow private defaults.
- Logs, analytics, diagnostics, and crash reports exclude private content.
- Sign out removes private projections and credentials.
- Local-data removal is comprehensive and testable.
- Pending user work is preserved during recoverable failures.
- Security tests and release gates pass.
- Product settings and documentation accurately describe behavior.

---

## 50. Next document

The next document should be:

```text
docs/macos-testing.md
```

It should define:

- Test architecture.
- Unit, repository, integration, UI, accessibility, performance, and security tests.
- Test targets.
- Fixtures.
- Local backend strategy.
- Network stubbing.
- Database isolation.
- Deterministic clocks.
- Offline and synchronization matrices.
- Review idempotency tests.
- Quick Lookup window tests.
- Menu bar lifecycle tests.
- System-integration tests.
- AI streaming and structured-output tests.
- Import fuzzing.
- CI stages.
- Release quality gates.
