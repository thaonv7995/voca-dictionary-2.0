# Voca for macOS — Data, Offline, and Synchronization

> Local persistence, account isolation, synchronization protocol, offline capability, mutation queue, conflicts, recovery, observability, and testing specification for Voca on macOS.

## Document status

- **Status:** Draft
- **Document type:** Architecture and Feature Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related vocabulary specification:** [`macos-vocabulary.md`](macos-vocabulary.md)
- **Related review specification:** [`macos-review.md`](macos-review.md)
- **Related Today specification:** [`macos-today.md`](macos-today.md)
- **Primary requirement groups:** `SYNC-*`, `SEC-*`, `PERF-*`, `REL-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca stores user data locally, remains useful without a network connection, and synchronizes safely with the backend.

It covers:

- Local database requirements.
- Account partitioning.
- Record identity and versioning.
- Repository behavior.
- Pull synchronization.
- Push synchronization.
- Pending mutation queue.
- Review-event idempotency.
- Conflict detection and resolution.
- Deletion and tombstones.
- Offline support by feature.
- Synchronization triggers.
- Background and foreground behavior.
- Activity and user-visible status.
- Data migration.
- Corruption recovery.
- Security.
- Performance.
- Testing and rollout.

The primary invariant is:

> A user action acknowledged by Voca must not be silently lost, duplicated, or applied to another account.

---

## 2. Goals

### DATA-GOAL-001 — Fast local reads

Previously synchronized vocabulary should load from local storage without waiting for the backend.

### DATA-GOAL-002 — Safe offline work

Supported edits and reviews should remain durable when the Mac is offline.

### DATA-GOAL-003 — Exactly-once user intent

Retrying a request must not create duplicate cards, duplicate review events, or repeated destructive operations.

### DATA-GOAL-004 — Explicit authority

Every field and record type must have a documented conflict and authority policy.

### DATA-GOAL-005 — Account isolation

Data belonging to one account must never appear in another account's UI, Spotlight index, widgets, or synchronization queue.

### DATA-GOAL-006 — Quiet success, visible failure

Routine synchronization remains unobtrusive. Failures requiring user action are visible and recoverable.

### DATA-GOAL-007 — Incremental adoption

The local-first architecture should be introduced without blocking the initial native macOS prototype.

---

## 3. Non-goals

The first synchronization release does not need:

- Peer-to-peer synchronization.
- CloudKit as a second source of truth.
- Real-time collaborative editing.
- Arbitrary user-defined conflict scripts.
- Automatic merging of long-form text with no possibility of review.
- Permanent storage of imported source documents.
- Full offline AI generation.
- Multi-account data visible in one window.

---

## 4. Sources of truth

Voca has several state authorities.

### 4.1 Backend-authoritative data

The backend is authoritative for:

- Account identity.
- Permissions and roles.
- Canonical shared dictionary content.
- Accepted review events.
- Reconciled FSRS scheduling state.
- Server-side AI and TTS settings where applicable.
- Remote deletion state.
- Cross-device synchronized user settings.

### 4.2 Locally authoritative transient state

The Mac is authoritative for:

- Window state.
- Sidebar and inspector visibility.
- Table-column widths.
- Device-local shortcuts.
- Device-local cache policy.
- Unsynchronized local drafts.
- Pending mutation metadata.
- Temporary import jobs.

### 4.3 Locally predicted state

The Mac may calculate temporary predicted values for:

- Review progress.
- Daily-goal progress.
- Next review while offline.
- Pending favorite, tag, and note changes.

Predicted state must be reconciled with the backend.

### 4.4 Derived state

Derived state includes:

- Today snapshot.
- Difficult-word collection.
- Weekly summary.
- Smart List membership.
- Spotlight documents.
- Widget snapshots.

Derived state must be rebuildable from canonical local records.

---

## 5. Architecture overview

```text
SwiftUI Feature
      │
      ▼
Application Use Case
      │
      ▼
Repository
      │
      ├──────────────► Local Database
      │                     │
      │                     └──► Local Query Observation
      │
      ├──────────────► Mutation Queue
      │
      └──────────────► Remote API
                            │
                            ▼
                     Sync Coordinator
                            │
                            ▼
                      Local Database
```

### 5.1 Read path

Preferred:

```text
Feature requests data
→ Repository queries local database
→ Feature renders local result
→ Sync runs when necessary
→ Remote changes are applied transactionally
→ Local observation updates feature
```

### 5.2 Write path

Preferred:

```text
User performs action
→ Validate command
→ Persist local mutation and queue entry in one transaction
→ Update UI from local state
→ Sync coordinator submits mutation
→ Apply authoritative response
→ Mark queue entry completed
```

### 5.3 Review path

```text
User grades card
→ Create stable ReviewEvent operation ID
→ Persist event and session progress transactionally
→ Advance UI
→ Submit event with idempotency key
→ Apply authoritative FSRS state
```

---

## 6. Persistence technology decision

The final implementation should evaluate:

- SwiftData.
- Direct SQLite through a maintained Swift library.

### 6.1 Required capabilities

The selected technology must support:

- Explicit migrations.
- Transactions.
- Batch upsert.
- Indexed compound queries.
- Full-text search or integration with an FTS index.
- Account partitioning.
- Tombstones.
- Mutation-queue persistence.
- Testing with temporary or in-memory stores.
- Predictable extension access.
- Safe concurrency.

### 6.2 Decision criteria

Score each option against:

```text
Migration control
Query capability
FTS support
Batch performance
Transaction semantics
Concurrency model
Testability
Extension sharing
Debugging tools
Long-term maintenance
```

### 6.3 Recommendation

Do not select persistence solely because it generates less prototype code.

The review mutation queue, conflict metadata, full-text vocabulary search, and incremental synchronization should have greater weight than simple CRUD convenience.

### 6.4 Abstraction requirement

Feature code must depend on repositories, not the selected database framework.

Changing the database implementation should not require rewriting SwiftUI views.

---

## 7. Local database organization

### 7.1 Store layout

Recommended:

```text
Application Support/
└── Voca/
    ├── accounts/
    │   └── {accountStorageID}/
    │       ├── voca.sqlite
    │       ├── voca.sqlite-wal
    │       ├── audio/
    │       ├── hanzi/
    │       ├── imports/
    │       └── diagnostics/
    └── shared/
        └── non-private resources
```

The exact paths must use supported macOS APIs rather than hard-coded user directories.

### 7.2 Account storage identifier

Use a stable, non-email account identifier.

Do not use:

- Email address.
- Display name.
- Access token.
- Server password.

If multiple servers are supported, the partition identity should include:

```text
normalized server identity + account ID
```

### 7.3 Shared resources

Only non-private resources may be shared across account partitions:

- Hanzi stroke data.
- Generic static assets.
- Public dictionary cache where ownership permits.

User cards, notes, review events, and settings remain account-scoped.

---

## 8. Proposed record model

## 8.1 Account record

```text
accountID
serverID
displayName
createdAt
lastAuthenticatedAt
lastSuccessfulSyncAt
localSchemaVersion
```

Credentials are not stored in this record.

## 8.2 Dictionary entry record

```text
dictionaryEntryID
language
canonicalText
normalizedText
pronunciation
pinyin
contentRevision
createdAt
updatedAt
deletedAt
```

Related child records:

- Meanings.
- Examples.
- Collocations.
- Related words.

## 8.3 User card record

```text
userCardID
accountID
dictionaryEntryID
language
level
favorite
topicID
personalNote
createdAt
updatedAt
deletedAt
remoteRevision
localRevision
syncState
```

## 8.4 Tag record

```text
tagID
accountID
name
normalizedName
createdAt
updatedAt
deletedAt
remoteRevision
syncState
```

## 8.5 User-card tag record

```text
accountID
userCardID
tagID
createdAt
deletedAt
remoteRevision
syncState
```

## 8.6 Study-state record

```text
accountID
userCardID
dueAt
stability
difficulty
reviewCount
lapseCount
lastReviewedAt
stateRevision
updatedAt
```

## 8.7 Review-event record

```text
operationID
accountID
sessionID
userCardID
grade
mode
reviewedAt
submissionState
attemptCount
lastAttemptAt
acceptedAt
serverRevision
lastError
```

## 8.8 Review-session record

```text
sessionID
accountID
source
mode
languageScope
orderedCardIDs
currentIndex
completedCardIDs
createdAt
lastActivityAt
status
```

## 8.9 Smart List record

```text
smartListID
accountID
name
queryDefinition
sortDefinition
layoutPreference
createdAt
updatedAt
deletedAt
remoteRevision
syncState
```

## 8.10 Pending mutation record

```text
operationID
accountID
entityType
entityID
operationType
payloadVersion
payload
createdAt
attemptCount
nextAttemptAt
dependencyOperationID
idempotencyKey
state
lastErrorCategory
lastErrorMessage
```

## 8.11 Sync cursor record

```text
accountID
resourceType
cursor
serverRevision
lastPulledAt
lastCompletedPageAt
```

## 8.12 Import job record

```text
importJobID
accountID
sourceType
sourceDisplayName
phase
progress
temporaryResourceLocation
createdAt
updatedAt
lastError
```

Raw source content should not remain after the job's documented retention period.

---

## 9. Record identity

### 9.1 Stable remote identity

Every synchronizable entity should have a stable backend identifier.

Names, slugs, and visible word text must not be treated as permanent entity identity.

### 9.2 Temporary local identity

Offline-created entities receive:

```text
localID
clientOperationID
remoteID = nil
```

After successful creation:

- Map remote ID to the existing local record.
- Do not replace the entire record in a way that breaks selection.

### 9.3 Duplicate prevention

Creation uses a stable idempotency key:

```text
same account + same operation ID
→ one accepted user intent
```

### 9.4 Identity mapping

Maintain a durable mapping when local and remote identifiers differ.

This mapping must survive application restart.

---

## 10. Versioning

### 10.1 Local revision

Increment for each local mutation affecting a synchronizable record.

### 10.2 Remote revision

The backend should expose one of:

- Entity version.
- Updated timestamp with strict semantics.
- Global resource revision.
- Change cursor.

### 10.3 Expected version

Update requests should include an expected version when supported.

Example:

```text
Update note where expectedRevision = 17
```

If the server has revision 18:

- Return conflict.
- Do not overwrite silently.

### 10.4 Payload versions

Queued mutation payloads include a schema version so migrations can transform or reject older queued work safely.

---

## 11. Synchronization coordinator

The synchronization coordinator is account-scoped and actor-isolated.

### 11.1 Responsibilities

- Prevent overlapping incompatible sync jobs.
- Observe connectivity.
- Push pending mutations.
- Pull remote changes.
- Apply transactions.
- Update cursors.
- Publish status.
- Trigger derived-index updates.
- Apply retry policy.
- Stop safely on sign out.

### 11.2 Non-responsibilities

It does not:

- Render UI.
- Build feature-specific copy.
- Own authentication screens.
- Decide user conflict choices.
- Store credentials.

### 11.3 State model

```text
Idle
Scheduled
Preparing
Pushing
Pulling
Applying
Updating Derived Data
Completed
Offline
Paused
Action Required
Failed Recoverably
```

### 11.4 Status summary

The UI consumes a simplified status:

```text
Synced
Syncing
Offline
Pending changes
Action required
```

---

## 12. Synchronization triggers

### 12.1 Required triggers

- Successful sign in.
- Application activation.
- Network reconnection.
- Local mutation.
- Manual refresh.
- Widget or external integration requiring fresh data.
- Before selected destructive actions where stale state is unsafe.

### 12.2 Optional triggers

- Periodic refresh while the app remains active.
- Background refresh when supported and energy-efficient.
- Before a large review session.

### 12.3 Debouncing

Multiple local mutations in quick succession should schedule one nearby sync rather than start one request per keystroke.

Example:

- Note editing may save locally often.
- Remote note synchronization may debounce.

### 12.4 Avoided behavior

Do not:

- Poll continuously while idle.
- Start a full pull after every favorite toggle.
- Synchronize every table scroll.
- Wake the application solely to update nonessential analytics.

---

## 13. Synchronization cycle

Recommended high-level cycle:

```text
1. Validate account session
2. Acquire account sync lock
3. Inspect pending mutations
4. Push eligible mutations
5. Pull remote changes
6. Apply remote changes transactionally
7. Reconcile local predictions
8. Update cursors
9. Rebuild affected derived data
10. Publish final status
11. Release lock
```

### 13.1 Push before pull

Benefits:

- Pending user intent reaches the server promptly.
- Pull response may include authoritative result.

Risk:

- A stale local mutation may conflict with unseen remote state.

### 13.2 Pull before push

Benefits:

- Local client sees recent remote versions before mutation.

Risk:

- User's pending intent is delayed.

### 13.3 Recommended hybrid

1. Pull lightweight version metadata when required.
2. Push mutations whose expected versions are valid or whose operations are commutative.
3. Pull complete incremental changes.
4. Resolve conflicts.

The exact protocol depends on backend capability and must be validated before implementation.

---

## 14. Pull synchronization

### 14.1 Incremental endpoint

Preferred contract:

```text
GET /sync/changes?cursor={cursor}&limit={limit}
```

Response:

```text
changes
nextCursor
hasMore
serverRevision
serverTime
```

### 14.2 Change envelope

Each change includes:

```text
resourceType
resourceID
operation
revision
updatedAt
payload
```

Operations:

```text
upsert
delete
```

### 14.3 Page application

Each page should be applied in one transaction:

```text
Apply records
→ Update relationships
→ Store tombstones
→ Update cursor
→ Commit
```

If application fails:

- Roll back the page.
- Retain previous cursor.
- Retry safely.

### 14.4 Cursor durability

Never advance the cursor before the corresponding changes are committed.

### 14.5 Full resynchronization

Required when:

- Cursor expires.
- Local database is rebuilt.
- Sync schema becomes incompatible.
- User requests repair.

Full sync must preserve pending local mutations.

### 14.6 Server deletions

Apply server tombstones without immediately erasing recovery metadata needed by pending operations.

---

## 15. Push synchronization

### 15.1 Eligible mutation

A mutation can be submitted when:

- Account is authenticated.
- Connectivity exists.
- Dependencies are completed.
- Retry time has arrived.
- It is not blocked by a conflict.

### 15.2 Submission

Requests should include:

- Stable operation ID.
- Idempotency key.
- Entity identity.
- Expected version where supported.
- Payload schema version.

### 15.3 Success

On success:

1. Validate operation ID.
2. Apply authoritative entity response.
3. Update remote revision.
4. Mark mutation completed.
5. Remove it after retention or diagnostic policy.

### 15.4 Retryable failure

Examples:

- Connection lost.
- Timeout.
- Temporary server error.
- Rate limit with retry guidance.

Action:

- Preserve mutation.
- Increment attempt count.
- Calculate next attempt.
- Keep local intent visible.

### 15.5 Permanent failure

Examples:

- Invalid payload.
- Permission revoked.
- Entity permanently unavailable.
- Unsupported schema.

Action:

- Mark action required.
- Do not silently discard.
- Present a user-safe resolution.

### 15.6 Authentication failure

Attempt token refresh once through the serialized authentication pipeline.

If refresh fails:

- Pause account sync.
- Preserve queue.
- Require reauthentication.

---

## 16. Mutation queue

### 16.1 Mutation types

Initial queue candidates:

```text
Create user card
Update favorite
Update level
Update tags
Update topic
Update note
Move to Trash
Restore
Submit review event
Update settings
Create or update Smart List
```

Potential online-only initial actions:

```text
Permanent deletion
Large AI generation
Provider credential validation
Account deletion
```

### 16.2 Mutation states

```text
Pending
In Flight
Retry Scheduled
Blocked by Dependency
Conflict
Action Required
Completed
Cancelled
```

### 16.3 Coalescing

Safe coalescing examples:

- Several pending favorite updates collapse to the final desired state.
- Repeated local note autosaves collapse before first remote submission.
- Tag set operations may collapse into a final relationship set if no intermediate state matters.

Never coalesce:

- Review events.
- Account activity events with distinct semantic meaning.
- Destructive operations with dependent restore actions unless modeled explicitly.

### 16.4 Dependencies

Example:

```text
Create local user card
→ Add tags to created card
→ Add personal note
```

Dependent mutations wait until the remote card identity exists.

### 16.5 Queue retention

Completed operations may be retained briefly for:

- Idempotency reconciliation.
- User-visible recent Activity.
- Diagnostics.

They should be pruned under a documented policy.

---

## 17. Review-event idempotency

Review events require stronger guarantees than ordinary metadata edits.

### 17.1 Required invariant

```text
One explicit grade action
→ one operation ID
→ at most one accepted server review event
```

### 17.2 Local transaction

Grade transaction includes:

```text
Insert review event
Update review session progress
Update predicted study state
Update Today goal progress
```

Either all commit or none commit.

### 17.3 Retry

Always retry with the same:

- Operation ID.
- Review timestamp.
- Grade.
- User-card identity.

### 17.4 Server duplicate response

The server should return the original accepted authoritative result.

It must not:

- Apply FSRS twice.
- Increment review count twice.
- Shift due date twice.

### 17.5 Ordering

Pending events for one user card must be submitted in review-time and sequence order.

### 17.6 Blocking dependency

If the backend does not support idempotent review events:

- Offline review remains disabled.
- The client may still cache read-only due content.
- The roadmap records backend work as a release blocker.

---

## 18. Conflict model

### 18.1 Conflict categories

```text
No Conflict
Commutative
Last Writer Acceptable
Mergeable
User Decision Required
Server Rejected
Deleted Remotely
Permission Changed
```

### 18.2 Field-level authority

#### Canonical dictionary content

Policy:

- Server wins.

#### Favorite

Policy:

- Latest accepted user intent wins.

#### Tags

Policy:

- Merge independent additions.
- Respect explicit removals using versioned relationship operations.

#### Topic

Policy:

- Expected-version update.
- Latest valid user decision may win after conflict review.

#### Personal note

Policy:

- Never silently overwrite divergent versions.
- Preserve both.
- Require merge or selection.

#### Study state

Policy:

- Reconcile from accepted review events.
- Server produces authoritative result.

#### Smart List definition

Policy:

- Expected-version update.
- Preserve conflicting local copy.

### 18.3 Conflict record

Store:

```text
conflictID
accountID
entityType
entityID
fieldScope
localValue
remoteValue
baseVersion
localVersion
remoteVersion
createdAt
resolutionState
```

Sensitive text values must be protected and excluded from diagnostics.

### 18.4 Conflict UI

Conflicts requiring action appear in Activity.

For a personal note:

```text
Your version
Server version
Keep Mine
Keep Server Version
Merge
```

### 18.5 Conflict avoidance

Prefer operations expressing intent:

```text
Add tag X
Remove tag Y
Set favorite true
```

over replacing an entire stale entity payload.

---

## 19. Deletion and tombstones

### 19.1 Move to Trash

Preferred model:

- Set `deletedAt`.
- Hide from active queries.
- Preserve metadata.
- Queue soft-delete mutation.

### 19.2 Restore

Restore:

- Clears local deletion state.
- Uses expected version.
- Re-enters active collections.

### 19.3 Tombstone

A tombstone includes:

```text
entityID
accountID
deletedAt
revision
deletionOperationID
```

### 19.4 Tombstone retention

Retain until:

- All clients can reasonably receive the deletion.
- Backend retention policy permits removal.
- No pending local mutation references the entity.

### 19.5 Permanent deletion

Permanent deletion should initially require online confirmation.

The server response must be authoritative before the local content is irrecoverably removed.

### 19.6 Delete versus pending local update

If deletion follows pending edits:

- Coalesce edits away if they no longer matter.
- Preserve user-authored note locally until deletion is accepted or cancelled.

### 19.7 Remote delete conflict

If the server deletes an item with a local unsubmitted note:

- Preserve the note in conflict recovery.
- Do not resurrect automatically.

---

## 20. Offline capability matrix

## 20.1 Authentication

Available offline:

- Continue an existing valid session according to token and product policy.

Unavailable offline:

- First sign in.
- Registration.
- Credential recovery.

## 20.2 Today

Available when cached:

- Due estimate.
- Daily goal.
- Recent words.
- Difficult words.
- Weekly summary.
- Active session.

## 20.3 Vocabulary

Available:

- Browse synchronized cards.
- Search local index.
- View details.
- Favorite.
- Tags.
- Notes.
- Supported metadata edits.

Conditional:

- Add word if dictionary content or pending creation flow can be represented locally.

## 20.4 Review

Available only when:

- Required card and study data are cached.
- Backend idempotency is supported.
- Local study-state freshness policy permits it.

## 20.5 Practice

Available:

- Cached exercises.
- Deterministic local exercises where implemented.

Unavailable:

- New server AI generation.

## 20.6 Assistant and conversation

Available:

- Read cached conversation history, if stored.

Unavailable:

- New remote generation.

## 20.7 Pronunciation

Available:

- Cached audio.
- Approved system speech fallback.

Unavailable:

- Remote-only TTS without connectivity.

## 20.8 Import

Available:

- Local CSV and JSON parsing.
- Local Vision OCR.
- Candidate preview.

Conditional:

- AI enrichment waits for connectivity.

## 20.9 Spotlight and widgets

Available:

- Last synchronized local snapshot.

They must indicate neither stale nor current data inaccurately.

---

## 21. Connectivity

### 21.1 Connectivity state

Use connectivity only as a hint.

An apparently reachable network does not guarantee:

- Backend availability.
- Authentication validity.
- Successful request.

### 21.2 Operation behavior

Requests should still handle real failures rather than relying only on connectivity status.

### 21.3 Reconnection

On likely reconnection:

- Debounce briefly.
- Resume eligible queue work.
- Avoid launching duplicate sync jobs.

### 21.4 Constrained networks

Large operations should consider:

- User-triggered import.
- Audio download policy.
- Document upload.
- AI generation.

Provide settings where network cost matters.

---

## 22. User-visible synchronization state

### 22.1 Synced

Default success state.

Usually no strong persistent indicator.

Optional detail:

```text
Last synced 2 minutes ago
```

### 22.2 Syncing

Show a subtle indicator.

Do not block local reads.

### 22.3 Offline

Example:

```text
Offline
Changes will be saved on this Mac.
```

### 22.4 Pending

Example:

```text
4 changes waiting to sync
```

### 22.5 Action required

Example:

```text
2 changes need attention
[Open Activity]
```

### 22.6 Scope

Use:

- Global toolbar or status area for account summary.
- Row-level status only for failed or pending entity-specific actions.
- Activity for details.

Avoid a sync icon on every normal item.

---

## 23. Activity view

### 23.1 Purpose

Activity explains meaningful ongoing or failed operations.

It is not a raw debug log.

### 23.2 Sections

```text
Needs Attention
In Progress
Waiting to Sync
Recently Completed
```

### 23.3 Item content

- Human-readable action.
- Affected entity type.
- Safe display name where allowed.
- Status.
- Time.
- Next retry.
- Retry or Resolve action.

### 23.4 Example items

```text
Review saved on this Mac
Waiting for a connection

Personal note conflict
Choose which version to keep

Vocabulary import
312 of 500 rows processed
```

### 23.5 Privacy

Do not display:

- Full personal note in list view.
- Tokens.
- API keys.
- Full imported document content.
- Raw request bodies.

### 23.6 Completed-item retention

Keep only a limited recent history.

Allow clearing completed items without deleting domain data.

---

## 24. Background synchronization

### 24.1 App-active sync

Primary synchronization occurs while:

- Main app is active.
- Menu bar companion is active.
- A user action requires sync.

### 24.2 App-inactive behavior

Pending data remains durable.

The application should not assume unlimited background execution.

### 24.3 Menu bar mode

If the user enables menu bar operation:

- Perform lightweight periodic refresh.
- Avoid heavy document or AI work.
- Measure idle energy impact.

### 24.4 Launch at login

Launch at login may support:

- Due-count refresh.
- Global Quick Lookup.
- Menu bar.

It must remain optional.

### 24.5 Background task priorities

Highest:

- User-triggered mutation.
- Accepted review event.
- Authentication refresh.

Medium:

- Incremental vocabulary pull.
- Widget snapshot update.

Low:

- Spotlight rebuild.
- Cache cleanup.
- Nonessential analytics upload.

---

## 25. Widget and App Group data

### 25.1 Principle

Widgets should read a compact, versioned snapshot, not the full private database.

### 25.2 Snapshot fields

```text
schemaVersion
accountDisplayMode
dueCount
dailyGoalValue
dailyGoalTarget
streak
wordOfTheDay
updatedAt
privacyMode
```

### 25.3 Atomic update

Write snapshot atomically:

1. Write temporary file.
2. Validate encoding.
3. Replace existing snapshot.
4. Reload widgets.

### 25.4 Sign out

On sign out:

- Remove private snapshot.
- Reload widgets into signed-out state.
- Clear pending deep-link data.

### 25.5 Multiple accounts

The widget shows only the active account.

Switching accounts replaces the snapshot atomically.

---

## 26. Spotlight synchronization

### 26.1 Source

Spotlight indexes from committed local vocabulary records.

### 26.2 Trigger

Index after:

- Initial sync.
- Card creation.
- Relevant card update.
- Restore.
- Deletion.

### 26.3 Deferred indexing

Spotlight updates may be deferred until after the main database transaction completes.

### 26.4 Failure

Spotlight failure:

- Does not roll back vocabulary data.
- Is retried separately.
- Appears in Activity only after repeated actionable failure.

### 26.5 Sign out

Remove account-specific indexed items.

---

## 27. Cache architecture

### 27.1 Cache classes

#### Durable domain data

- Vocabulary.
- Study state.
- Review events.
- Tags.
- Notes.

Not treated as disposable cache.

#### Rebuildable cache

- Audio.
- Hanzi stroke data.
- Remote images.
- AI preview content.
- Search-derived indexes.

#### Temporary data

- Import source copies.
- OCR intermediate images.
- Partial downloads.
- Export staging.

### 27.2 Cache limits

Settings should expose:

- Audio-cache size.
- Clear audio cache.
- Clear temporary files.

Do not label durable offline vocabulary as disposable cache.

### 27.3 Eviction

Suggested priority:

1. Expired temporary files.
2. Failed partial downloads.
3. Least-recently-used audio.
4. Rebuildable Hanzi resources if downloadable again.

Never evict:

- Pending mutations.
- Unsynchronized notes.
- Review events.
- Account database merely to satisfy a cache limit.

---

## 28. Database migrations

### 28.1 Migration requirements

Every schema change must have:

- Version number.
- Migration implementation.
- Rollback or recovery plan.
- Fixture from the prior version.
- Automated test.

### 28.2 Migration phases

```text
Validate storage
Create backup or recovery point
Apply migration
Validate invariants
Commit schema version
Clean obsolete data later
```

### 28.3 Pending mutation migration

Queued payloads require explicit migration.

Never drop pending user work because its payload is old.

If transformation is impossible:

- Preserve raw payload securely.
- Mark action required.
- Offer export or recovery.

### 28.4 Large migration

For long-running changes:

- Display progress.
- Make cancellation policy explicit.
- Avoid running heavy work on the main thread.

### 28.5 Failed migration

Options:

- Retry.
- Restore backup.
- Rebuild synchronized data while preserving pending local work.
- Export diagnostics.

---

## 29. Corruption and repair

### 29.1 Detection

Detect:

- Database open failure.
- Integrity-check failure.
- Invalid foreign relationships.
- Cursor state with missing page data.
- Duplicate operation IDs.

### 29.2 Repair priority

1. Protect pending user intent.
2. Protect unsynchronized user-authored content.
3. Protect accepted review-event records.
4. Rebuild synchronized remote data.
5. Rebuild derived indexes and caches.

### 29.3 Repair flow

```text
Pause sync
→ Copy recoverable pending work
→ Rebuild or repair database
→ Pull remote state
→ Reapply recoverable pending work
→ Rebuild indexes
→ Resume sync
```

### 29.4 User-facing copy

Explain:

- What happened.
- What data is safe.
- What will be rebuilt.
- Whether user action is required.

Avoid generic messages such as:

```text
Database error 11
```

without an understandable explanation.

---

## 30. Sign out and local data

### 30.1 Sign-out choices

Product decision required:

```text
Sign out and keep downloaded data
Sign out and remove local data
```

If local data is retained:

- It must remain inaccessible without valid account authentication.
- Widgets and Spotlight still remove private projections.

### 30.2 Pending mutations

If pending changes exist, sign out should explain:

```text
4 changes have not synchronized.
```

Options:

- Sync Then Sign Out.
- Keep on This Mac and Sign Out.
- Discard Local Changes and Sign Out.
- Cancel.

Exact options depend on security policy.

### 30.3 Account removal

Removing local account data deletes:

- Database partition.
- Pending mutations.
- Local conversations.
- Cached audio.
- Temporary imports.
- Widget snapshot.
- Spotlight entries.
- Credentials.

It does not imply remote account deletion.

---

## 31. Security

### 31.1 Credentials

Store in Keychain:

- Refresh token.
- Provider API keys.
- Other secrets.

Do not store in the database:

- Password.
- Raw authentication header.
- Plain provider key.

### 31.2 Database protection

Use macOS-supported file protection and sandbox locations.

Evaluate encryption for:

- Personal notes.
- AI conversations.
- Imported document excerpts.

### 31.3 App Group

The App Group contains only data required by extensions.

Do not put:

- Full database.
- Credentials.
- Personal notes.
- AI conversations.

in the shared container without a separately approved architecture.

### 31.4 Logs

Logs may include:

- Operation ID.
- Entity type.
- Error category.
- Duration.
- Retry count.

Logs must exclude:

- Note text.
- Word meaning content where not necessary.
- Imported text.
- AI prompt.
- Tokens.
- API keys.

### 31.5 Diagnostics

Diagnostics export uses an explicit allowlist.

Mutation payloads should be summarized, not dumped.

---

## 32. Performance

### 32.1 Query targets

Validate with:

```text
1,000 cards
10,000 cards
50,000 cards stress dataset
```

### 32.2 Indexes

Likely indexes:

```text
accountID + deletedAt
accountID + language
accountID + updatedAt
accountID + dueAt
accountID + favorite
accountID + normalizedText
accountID + syncState
operationID unique
resourceType + cursor
```

Actual indexes must follow query profiling.

### 32.3 Batch apply

Remote sync pages should use transactional batch upserts.

Avoid one UI publication per changed row during a large pull.

### 32.4 Search

Use:

- Indexed normalized fields.
- Full-text search.
- Pagination.
- Cancellation.

### 32.5 Queue processing

Process with bounded concurrency.

Preserve ordering for:

- Events on one card.
- Dependent mutations.

Allow limited parallelism for independent entities.

### 32.6 Database maintenance

Schedule:

- WAL checkpoint.
- Vacuum or compaction when needed.
- Completed-mutation pruning.
- Temporary-file cleanup.

Do not perform heavy maintenance during an active review.

---

## 33. Retry and backoff

### 33.1 Retry categories

Retry:

- Connection failure.
- Timeout.
- Temporary server failure.
- Explicit rate-limit response.

Do not automatically retry:

- Validation failure.
- Permission failure.
- Unsupported schema.
- User cancellation.

### 33.2 Backoff

Use bounded exponential backoff with jitter.

Conceptual schedule:

```text
Immediate safe retry once
Then seconds
Then tens of seconds
Then minutes
Then action-required threshold
```

Exact values should be centralized and testable.

### 33.3 User-triggered retry

Manual Retry may bypass the scheduled delay, but must still:

- Prevent duplicate concurrent submission.
- Reuse the same operation ID.

### 33.4 Rate limiting

Respect server retry guidance.

Display a concise status only when the delay affects user expectations.

---

## 34. Time and clock handling

### 34.1 Stored time

Store absolute timestamps in UTC.

Format using the user's locale and current time zone.

### 34.2 Daily boundaries

Daily goal and streak require:

- Recorded event timestamp.
- Relevant local date.
- Deterministic server reconciliation.

### 34.3 Clock abstraction

Use an injectable clock for:

- Retry scheduling.
- Due-state tests.
- Daily-goal tests.
- Streak tests.
- Cache expiry.

### 34.4 Clock changes

System clock or time-zone changes must not:

- Duplicate review events.
- Move pending operation IDs.
- Corrupt retry scheduling.

---

## 35. API requirements

The preferred backend synchronization API should provide:

### 35.1 Incremental changes

```text
GET /api/sync/changes?cursor=...
```

### 35.2 Mutation batch

```text
POST /api/sync/mutations
```

with:

- Operation IDs.
- Expected revisions.
- Per-operation results.

### 35.3 Review event

```text
POST /api/review
Idempotency-Key: {operationID}
```

### 35.4 Bootstrap

```text
GET /api/sync/bootstrap
```

or paginated resource endpoints with revision support.

### 35.5 Server capabilities

The client should be able to determine:

- Sync protocol version.
- Idempotency support.
- Soft-delete support.
- Batch limits.
- Cursor expiry.
- Minimum supported client version.

### 35.6 Error contract

Per-operation errors should include:

```text
operationID
category
retryable
currentRevision
safe user message key
```

---

## 36. Repository behavior

### 36.1 Vocabulary repository

Reads from local storage.

Writes:

- Persist local entity change.
- Create queue operation.
- Return updated local entity.

### 36.2 Review repository

Creates durable review event and session update in one transaction.

### 36.3 Settings repository

Separates:

- Device-local settings.
- Account-synchronized settings.
- Keychain secrets.

### 36.4 Today repository

Composes derived data from local synchronized records.

It should not implement an independent cache that can permanently disagree with canonical records.

### 36.5 Assistant repository

Conversation persistence policy must be explicit:

- Local only.
- Server synchronized.
- Not retained.

Until decided, do not assume AI conversations synchronize like vocabulary.

---

## 37. Observability

### 37.1 Safe metrics

- Sync duration.
- Changes pulled.
- Mutations pushed.
- Retry count.
- Conflict count.
- Queue depth.
- Cursor reset count.
- Database query duration.
- Migration duration.

### 37.2 Health indicators

Internal:

```text
oldest pending mutation age
last successful sync
consecutive sync failures
review events awaiting acceptance
database integrity status
```

### 37.3 Alerts

Potential release diagnostics:

- Repeated migration failure.
- Review-event duplicate rejection.
- Queue operation permanently blocked.
- Cursor expiry loop.
- Database corruption.

### 37.4 Privacy

Metrics must not include:

- Vocabulary content.
- Notes.
- Search queries.
- Tags.
- Imported content.
- AI prompts.

---

## 38. Testing strategy

### 38.1 Database tests

- Schema creation.
- Every migration.
- Transactions.
- Account isolation.
- Full-text search.
- Batch upsert.
- Tombstones.
- Unique operation IDs.

### 38.2 Queue tests

- Enqueue.
- Dependency blocking.
- Safe coalescing.
- Retry scheduling.
- Permanent failure.
- Process restart.
- Queue pruning.

### 38.3 Pull tests

- First page.
- Multiple pages.
- Cursor persistence.
- Page rollback.
- Cursor expiry.
- Server delete.
- Duplicate remote change.

### 38.4 Push tests

- Success.
- Timeout before server receipt.
- Timeout after server acceptance.
- Duplicate retry.
- Expected-version conflict.
- Authentication refresh.
- Rate limiting.

### 38.5 Review tests

- Grade transaction.
- Exactly-once operation ID.
- Offline restart.
- Ordered submission.
- Conflict with another device.
- Authoritative state reconciliation.

### 38.6 Conflict tests

- Concurrent favorite changes.
- Tag add and remove.
- Divergent personal notes.
- Remote deletion with local edit.
- Smart List conflict.

### 38.7 Sign-out tests

- No pending mutations.
- Pending mutations retained.
- Local data removed.
- Widget cleared.
- Spotlight cleared.
- Account switch.

### 38.8 Failure injection

Simulate:

- Disk full.
- Database locked.
- Database corruption.
- Network loss.
- Server timeout.
- Process termination.
- Token expiry.
- Migration interruption.

### 38.9 Performance tests

- 10,000-card query.
- 50,000-card stress search.
- 10,000-change sync page sequence.
- 1,000 pending independent mutations.
- Long offline review event queue.

---

## 39. Rollout plan

### Phase 0 — Remote-backed prototype

- Repository protocols.
- Shared API client.
- No offline writes.
- Minimal read cache if needed.

### Phase 1 — Local vocabulary reads

- Local database.
- Account partitioning.
- Bootstrap pull.
- Local search.
- Read-through refresh.

### Phase 2 — Metadata mutations

- Favorite.
- Tags.
- Notes.
- Queue.
- Retry.
- Activity.

### Phase 3 — Incremental sync

- Change cursor.
- Tombstones.
- Expected revisions.
- Conflict records.

### Phase 4 — Offline review

Requires:

- Stable review operation IDs.
- Backend idempotency.
- Session persistence.
- Study-state reconciliation.

### Phase 5 — System projections

- Widgets.
- Spotlight.
- Menu bar.
- App Intents.

### Phase 6 — Repair and optimization

- Database repair.
- Search tuning.
- Queue pruning.
- Migration hardening.
- Performance profiling.

---

## 40. Requirement traceability

### `SYNC-001` — Offline vocabulary access

Covered by:

- Local database.
- Vocabulary repository.
- Account partitioning.
- Offline capability matrix.

### `SYNC-002` — Offline review

Covered by:

- Review-event idempotency.
- Session persistence.
- Offline review prerequisites.
- Ordered reconciliation.

### `SYNC-003` — Pending mutation queue

Covered by:

- Queue record.
- States.
- Dependencies.
- Retry and coalescing.

### `SYNC-004` — Sync status

Covered by:

- Coordinator states.
- UI summary.
- Activity.
- Last successful sync.

### `SYNC-005` — Conflict handling

Covered by:

- Conflict categories.
- Field-level policies.
- Conflict record.
- User resolution.

### `SEC-*`

Covered by:

- Keychain separation.
- Account isolation.
- App Group minimization.
- Logging and diagnostics allowlists.
- Local-data removal.

### `PERF-*`

Covered by:

- Indexing.
- Batch transactions.
- Pagination.
- Bounded concurrency.
- Database maintenance.

### `REL-*`

Covered by:

- Durable queue.
- Transactional writes.
- Idempotency.
- Migration and repair.
- Failure injection.

---

## 41. Acceptance scenarios

### Scenario A — Local vocabulary startup

1. Synchronize vocabulary.
2. Quit Voca.
3. Disconnect the network.
4. Relaunch.

Expected:

- Vocabulary loads locally.
- Search works.
- Word detail works.
- Offline status is visible.

### Scenario B — Offline note

1. Disconnect.
2. Edit a personal note.
3. Quit.
4. Relaunch.
5. Reconnect.

Expected:

- Note remains.
- Queue survives restart.
- One remote update is accepted.

### Scenario C — Duplicate favorite updates

1. Toggle favorite several times offline.
2. End in favorite state.
3. Reconnect.

Expected:

- Safe mutations coalesce.
- Final desired state reaches server.

### Scenario D — Review timeout after acceptance

1. Grade a card.
2. Server accepts event.
3. Response is lost.
4. Client retries.

Expected:

- Same operation ID is reused.
- Review applies once.
- Queue completes after reconciliation.

### Scenario E — Divergent note

1. Edit a note offline on Mac.
2. Edit the same note on another device.
3. Synchronize Mac.

Expected:

- Neither version is silently lost.
- Activity offers conflict resolution.

### Scenario F — Remote deletion

1. Edit a card locally offline.
2. Delete the card remotely.
3. Reconnect.

Expected:

- Card is not resurrected automatically.
- Local user-authored content remains recoverable.

### Scenario G — Cursor page failure

1. Pull a multipage change set.
2. Fail while applying page three.
3. Restart sync.

Expected:

- Pages one and two remain committed.
- Cursor remains at page-two completion.
- Page three safely retries.

### Scenario H — Sign out with pending work

1. Create pending note and review mutations.
2. Sign out.

Expected:

- User is warned.
- Selected sign-out policy is applied.
- No pending work moves to another account.
- Widget and Spotlight private data are removed.

### Scenario I — Database migration interruption

1. Begin migration.
2. Terminate application.
3. Relaunch.

Expected:

- Store remains recoverable.
- Pending mutations are preserved.
- Migration resumes or rollback occurs safely.

### Scenario J — Account switch

1. Sign in as account A and synchronize.
2. Sign out.
3. Sign in as account B.

Expected:

- No account-A card, note, widget, Spotlight item, or queued mutation appears for account B.

---

## 42. Decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Local database is the primary read source after initial synchronization.
2. Every synchronizable record is account-partitioned.
3. Feature views access data through repositories.
4. Local user actions and mutation-queue entries commit transactionally.
5. Review events use stable client operation IDs.
6. Offline review remains blocked until backend idempotency is verified.
7. Personal-note conflicts are never resolved silently.
8. System projections such as Spotlight and widgets are rebuildable derived data.
9. Widgets consume a compact versioned snapshot, not the full database.
10. Routine synchronization remains quiet.
11. Permanent deletion initially requires online server confirmation.
12. Pending user work has higher recovery priority than rebuildable remote data.

---

## 43. Open questions

1. Does the backend currently expose incremental sync cursors?
2. Do vocabulary records expose stable revisions?
3. Does review submission support idempotency keys?
4. Does the backend support soft deletion and restore?
5. Which local persistence technology best fits FTS and migration requirements?
6. Should one database file contain all account partitions or should each account have a separate database?
7. How long should tombstones be retained?
8. Which mutations can be safely coalesced?
9. Can Smart Lists synchronize across devices?
10. Is daily-goal and streak state server-derived or locally derived?
11. What study-state freshness limit permits offline review?
12. Should AI conversations synchronize?
13. Are user notes encrypted locally?
14. Can extensions access a read-only subset of the database, or should all use snapshots?
15. What maximum mutation batch size does the backend accept?
16. How is server time communicated to detect clock drift?
17. What should happen to pending mutations when permissions change?
18. Should signed-out retained data be encrypted with an account-bound key?
19. Which Activity history should survive application restart?
20. What automated repair operations may run without user approval?

---

## 44. Backend blockers

The following backend capabilities may block complete offline support:

- Stable entity revisions.
- Incremental change feed.
- Tombstones.
- Idempotent mutation operations.
- Idempotent review events.
- Ordered review reconciliation.
- Batch mutation responses.
- Conflict response contract.
- Soft deletion and restore.
- Capability/version endpoint.

If these do not exist, create explicit backend milestones rather than compensating with unreliable client assumptions.

---

## 45. Definition of done

Data and synchronization are ready for the first public release when:

- Previously synchronized vocabulary loads offline.
- Account data is strictly isolated.
- Local writes and queue entries are atomic.
- Pending operations survive restart.
- Incremental pull commits pages safely.
- Retry never changes operation identity.
- Review events are accepted exactly once.
- Conflicts follow documented field-level policies.
- User-authored content is never silently discarded.
- Deletion and restoration behavior matches backend contracts.
- Sync status is understandable.
- Activity exposes actionable failures.
- Widget and Spotlight data clear on sign out.
- Database migrations are automated and tested.
- Corruption-recovery procedures preserve pending work.
- Large-library and large-sync performance targets pass.
- Sensitive content is excluded from logs and diagnostics.

---

## 46. Next document

The next document should be:

```text
docs/macos-quick-lookup.md
```

It should define:

- Global keyboard shortcut.
- Floating-panel behavior.
- Active-display placement.
- Text entry and clipboard suggestion.
- Local and remote lookup pipeline.
- Result ranking.
- English and Chinese result layouts.
- Pronunciation.
- Add Word.
- Existing-word behavior.
- Ask Assistant.
- Open Detail.
- Offline behavior.
- Privacy.
- Multi-display and Spaces behavior.
- Window activation.
- Accessibility.
- Performance targets.
- Acceptance scenarios mapped to `QUICK-*`.
