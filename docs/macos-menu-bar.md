# Voca for macOS — Menu Bar Companion

> Product, UX, lifecycle, background behavior, privacy, accessibility, and acceptance specification for the Voca menu bar companion on macOS.

## Document status

- **Status:** Draft
- **Document type:** Feature Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Related review specification:** [`macos-review.md`](macos-review.md)
- **Related Quick Lookup specification:** [`macos-quick-lookup.md`](macos-quick-lookup.md)
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Primary requirement group:** `MENU-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the Voca menu bar companion for macOS.

It covers:

- Menu bar item behavior.
- Icon and due-count policy.
- Enabled and disabled states.
- Signed-in and signed-out states.
- Popover layout.
- Daily summary.
- Word of the day.
- Quick Lookup.
- Quick Add.
- Mini Review.
- Synchronization state.
- Reminder controls.
- Main-window lifecycle.
- Launch at login.
- Background refresh.
- Privacy.
- Accessibility.
- Energy and performance.
- Error recovery.
- Testing and acceptance criteria.

The menu bar companion makes Voca available throughout the workday without requiring the full workspace to remain visible.

---

## 2. Product intent

The menu bar companion should provide lightweight, frequently useful learning actions:

- See whether cards are due.
- Start a short review.
- Open Quick Lookup.
- Add a word.
- Hear a useful word.
- Open the main Voca workspace.

It should not become:

- A miniature copy of the entire application.
- A permanent source of urgency.
- A continuously updating dashboard.
- A large AI workspace.
- A replacement for Today, Vocabulary, or full Review.

The ideal interaction lasts a few seconds:

```text
Open menu bar
→ understand current state
→ perform one lightweight action
→ close and resume work
```

---

## 3. Product principles

### MENU-PRN-001 — The companion is optional

Users must be able to disable the menu bar item without disabling the main application.

### MENU-PRN-002 — Due count informs without pressuring

The menu bar may show due status, but users control whether a numeric badge is visible.

### MENU-PRN-003 — Lightweight tasks remain lightweight

Quick Lookup, Quick Add, and Mini Review should require few steps and little navigation.

### MENU-PRN-004 — Shared domain behavior

The menu bar must use the same repositories, review events, synchronization rules, and routes as the main application.

### MENU-PRN-005 — Background work is conservative

The companion should not continuously poll, scan the clipboard, refresh AI content, or consume meaningful energy while idle.

### MENU-PRN-006 — Closing the main window is not quitting

When the companion is enabled, closing the main workspace should leave menu bar functionality available.

### MENU-PRN-007 — Quitting is explicit

Choosing Quit Voca terminates:

- Menu bar item.
- Quick Lookup shortcut handling.
- Background synchronization.
- Audio.
- Application processes.

### MENU-PRN-008 — Private content is minimized

The menu bar should reveal only the information necessary for the selected feature.

---

## 4. Scope

### 4.1 Included

- Optional menu bar item.
- Due-card status.
- Configurable numeric count.
- Popover.
- Quick Lookup action.
- Quick Add action.
- Start Review.
- Mini Review.
- Word of the day.
- Daily-goal summary.
- Synchronization summary.
- Open Voca.
- Settings.
- Quit.
- Launch at login.
- Lightweight background refresh.

### 4.2 Related but specified elsewhere

- Full Quick Lookup panel.
- Full Review window.
- Today dashboard.
- Vocabulary Add Word form.
- Notification scheduling.
- App Intents.
- Widget behavior.
- Synchronization internals.

### 4.3 Excluded from the first version

- Full vocabulary management.
- Full Assistant conversations.
- PDF import.
- OCR.
- Rich learning analytics.
- Complete Settings.
- Editing word content.
- Long reading exercises.
- Writing-practice canvas.
- Passive clipboard monitoring.

---

## 5. Enablement

### 5.1 Preference

Settings:

```text
Show Voca in the menu bar
```

Recommended default:

- Enabled after the user explicitly chooses ambient features during onboarding or Settings.
- Avoid silently adding a persistent menu bar item without explanation.

### 5.2 Independent behavior

Disabling the menu bar item:

- Removes the item.
- Stops menu-bar-specific refresh work.
- Does not disable the main Voca application.
- Does not necessarily disable Quick Lookup if configured separately.

### 5.3 First enablement

After enabling:

- Show the item immediately.
- Display a concise explanation.
- Offer Launch at Login separately.

### 5.4 No available menu-bar space

Voca should:

- Remain functional through the main app and shortcuts.
- Avoid repeatedly warning the user.
- Document that macOS may hide items when space is constrained.

---

## 6. Menu bar item

### 6.1 Icon

Use a simple monochrome template icon.

Requirements:

- Recognizable at small size.
- Legible in Light and Dark menu bars.
- Appropriate for template rendering.
- No detailed app-logo artwork.
- No color dependency.

Candidate concepts:

- Simplified `V`.
- Book plus check.
- Speech bubble plus word mark.
- Minimal vocabulary-card silhouette.

The final icon should be tested at native menu-bar dimensions.

### 6.2 Due-count display

Display modes:

```text
Icon only
Icon and due count
Icon and status dot
```

Recommended default:

- Icon only.

Users may opt into numeric count.

### 6.3 Count formatting

Examples:

```text
8
24
99+
```

Avoid very long numeric labels.

### 6.4 Count semantics

The count represents:

```text
Cards currently due for the active account
```

It does not represent:

- Daily goal remaining.
- Total vocabulary.
- Pending sync operations.
- Unread notifications.

### 6.5 No cards due

Use:

- Icon without count.
- Optional subtle completed state inside the popover.

Do not show `0` permanently unless the user selects that preference.

### 6.6 Action-required state

A small warning indicator may appear when:

- Authentication is required.
- Synchronization has an actionable conflict.
- Local storage requires attention.

The icon must not become an ambiguous permanent red badge.

### 6.7 Syncing state

Routine synchronization should not animate the menu bar icon continuously.

Show synchronization status inside the popover.

---

## 7. Popover structure

Recommended width:

```text
340–380 points
```

Recommended maximum height:

```text
520–620 points
```

Structure:

```text
┌────────────────────────────────────────┐
│ Voca                           Synced   │
├────────────────────────────────────────┤
│ 24 cards due                           │
│ 12 of 20 daily reviews                 │
│ [Review 5 Cards]   [Open Full Review]  │
├────────────────────────────────────────┤
│ Word of the day                  🔊     │
│ concise                                │
│ brief but comprehensive                │
│ [Open Detail]                          │
├────────────────────────────────────────┤
│ [Quick Lookup]      [Quick Add]        │
├────────────────────────────────────────┤
│ Open Voca                   Settings   │
│ Quit Voca                              │
└────────────────────────────────────────┘
```

### 7.1 Region priority

1. Authentication or action-required state.
2. Active Mini Review.
3. Due summary.
4. Quick actions.
5. Word of the day.
6. Sync status.
7. Main app and Settings actions.

### 7.2 Scrolling

The standard popover should not require scrolling.

Mini Review may replace the summary content rather than expanding the popover indefinitely.

### 7.3 Dismissal

The popover closes when:

- User clicks outside.
- User presses Escape.
- Quick Lookup opens.
- Main Voca opens.
- Settings opens.
- Full Review opens.

It may remain open during Mini Review.

---

## 8. Signed-out state

When no account session exists:

```text
Voca

Sign in to save vocabulary, review cards,
and synchronize your learning.

[Sign In]

[Quick Lookup]

Open Voca
Quit Voca
```

### 8.1 Quick Lookup while signed out

If unauthenticated local lookup is supported:

- Keep Quick Lookup available.
- Disable saving.
- Offer Sign In to Save.

If lookup requires authentication:

- Open authentication flow.

### 8.2 Private data

Signed-out state must not show:

- Prior account due count.
- Word of the day derived from private vocabulary.
- Prior account daily goal.
- Prior account pending sync.

### 8.3 Reauthentication required

Show:

```text
Sign in again to continue syncing.
Your changes remain saved on this Mac.
```

Actions:

- Sign In.
- Open Voca.

---

## 9. Daily summary

### 9.1 Required content

- Due count.
- Daily-goal progress.
- Primary review action.

### 9.2 Due state

Example:

```text
24 cards due
18 English · 6 Chinese
```

### 9.3 Goal state

Example:

```text
12 of 20 reviews today
```

Use a compact progress indicator where helpful.

### 9.4 Completed state

Example:

```text
You're caught up
Daily goal complete
```

Optional:

- Next due time.

### 9.5 Active session

If a review is paused:

```text
Review in progress
12 of 24 completed

[Resume Review]
```

Resume outranks starting Mini Review.

### 9.6 Count refresh

The summary updates:

- After local review events.
- After synchronization.
- After account changes.
- After the local day changes.

---

## 10. Quick actions

### 10.1 Quick Lookup

Action:

```text
Quick Lookup
```

Behavior:

1. Close menu bar popover.
2. Open global Quick Lookup panel.
3. Focus query field.

### 10.2 Quick Add

Action:

```text
Quick Add
```

Behavior:

- Open a compact add form or Quick Lookup in add mode.
- Keep saving explicit.
- Detect duplicates.

Recommended first release:

- Reuse Quick Lookup.
- Query a word.
- Save the result.

This avoids creating a second incomplete lookup implementation.

### 10.3 Open Full Review

Behavior:

- Close popover.
- Open or activate Review window.
- Resume an existing session when appropriate.

### 10.4 Open Voca

Behavior:

- Close popover.
- Activate most recent main workspace.
- Create a main workspace window if none exists.
- Restore last safe route.

### 10.5 Settings

Behavior:

- Close popover.
- Open standard Settings scene.
- Select General or Integrations as defined.

---

## 11. Mini Review

### 11.1 Purpose

Mini Review enables a brief study interaction without opening the full workspace.

### 11.2 Scope

Supports:

- Up to five cards.
- Recognition mode.
- Reveal.
- Again, Hard, Good, and Easy.
- Pronunciation.
- Progress.
- Completion summary.

### 11.3 Excluded

- Editing.
- Long AI explanations.
- Session configuration.
- Type-in mode.
- Listening-only mode.
- Writing practice.
- Full review history.
- Batch actions.

### 11.4 Start action

```text
Review 5 Cards
```

If fewer than five cards are due:

- Review available cards.

If no cards are due:

- Hide or disable the action.
- Offer optional nongraded practice separately only if useful.

### 11.5 Active full review

If a full session exists:

- Show Resume Review.
- Do not start an independent Mini Review.

### 11.6 Queue behavior

Mini Review:

- Uses authoritative or valid cached due data.
- Creates a stable limited session.
- Does not duplicate cards from another active session.

### 11.7 Prompt state

```text
2 of 5

concise

[Reveal]
```

### 11.8 Answer state

```text
concise                                  🔊
/kənˈsaɪs/
brief but comprehensive

[1 Again] [2 Hard] [3 Good] [4 Easy]
```

### 11.9 Keyboard

When the popover is active:

```text
Space     Reveal
1         Again
2         Hard
3         Good
4         Easy
Escape    Close or pause
```

### 11.10 Grade durability

Mini Review follows the same rule as full Review:

```text
Persist review event locally
→ update progress
→ advance
→ synchronize
```

### 11.11 Completion

Show:

```text
5 cards reviewed
Your progress is saved.

[Review More] [Done]
```

If events are pending:

```text
Saved on this Mac · Waiting to sync
```

### 11.12 Transition to full review

Review More:

- Opens full Review.
- Excludes already completed Mini Review cards from immediate repetition.

---

## 12. Word of the day

### 12.1 Purpose

Provide one lightweight vocabulary touchpoint.

It should support recognition and curiosity, not replace scheduled review.

### 12.2 Source priority

Potential rule:

```text
1. Recently added word not yet reviewed
2. Difficult word suitable for reinforcement
3. Favorite word not shown recently
4. Curated generic word
```

The first implementation should use deterministic local selection.

### 12.3 Content

- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meaning.
- Audio.

### 12.4 Actions

- Play Pronunciation.
- Open Detail.
- Favorite where appropriate.

### 12.5 Privacy

Preference:

```text
Show vocabulary content in the menu bar
```

If disabled:

- Hide the section.

### 12.6 Rotation

Change:

- Once per local day.
- When the selected card becomes unavailable.
- When the user explicitly requests another word, if supported.

Do not rotate every time the popover opens.

### 12.7 Offline

Use local synchronized vocabulary.

No remote generation is required.

---

## 13. Synchronization status

### 13.1 Synced

Show subtly:

```text
Synced
```

or:

```text
Updated 2 min ago
```

### 13.2 Syncing

Show:

```text
Syncing…
```

Do not prevent Mini Review or local actions.

### 13.3 Offline

Show:

```text
Offline
Changes will sync later.
```

### 13.4 Pending

Show:

```text
4 changes waiting to sync
```

### 13.5 Action required

Show:

```text
2 changes need attention
[Open Activity]
```

### 13.6 Error detail

Raw errors do not belong in the popover.

Open Activity for:

- Conflicts.
- Permanent failures.
- Storage issues.

---

## 14. Reminder controls

### 14.1 Purpose

Offer lightweight control over review reminders.

### 14.2 Candidate actions

```text
Remind Me Later
Pause Reminders Today
Open Reminder Settings
```

### 14.3 Remind Me Later

Suggested presets:

```text
In 1 hour
This evening
Tomorrow
```

This changes notification scheduling, not card due dates.

### 14.4 Pause Reminders Today

Suppresses additional review reminders until the next local day.

It does not:

- Complete daily goal.
- Mark cards reviewed.
- Change FSRS state.

### 14.5 Placement

Reminder controls belong in:

- More menu.
- A reminder section when a notification context exists.

They should not occupy the top of the ordinary popover.

---

## 15. Main-window lifecycle

### 15.1 Closing the main window

If menu bar is enabled:

- Closing the main window leaves Voca running.
- Menu bar, Quick Lookup, sync, and configured reminders remain available.

### 15.2 Reopening

Open Voca:

- Restores the last safe main-window route.
- Creates a window if needed.

### 15.3 No main-window requirement

The menu bar companion must not require a hidden main window to remain alive.

### 15.4 Dock icon policy

Potential modes:

```text
Standard app with Dock icon
Menu-bar-focused mode with optional Dock behavior
```

Recommendation for first release:

- Keep standard Dock behavior.
- Do not dynamically hide the Dock icon until lifecycle and user expectations are validated.

### 15.5 Application termination

Quit Voca:

- Cancels UI tasks.
- Flushes durable local operations.
- Stops audio.
- Unregisters global shortcuts.
- Removes menu bar item.
- Does not discard queued mutations.

---

## 16. Launch at login

### 16.1 Preference

Settings:

```text
Launch Voca at login
```

Default:

- Off.

### 16.2 Enablement

Enabling:

- Uses the supported macOS login-item mechanism.
- Does not require the user to manage a separate helper manually.

### 16.3 Login launch behavior

Recommended:

- Start application in background.
- Show menu bar item.
- Register Quick Lookup shortcut.
- Do not open the main window automatically.

### 16.4 Disabled menu bar

If Launch at Login is enabled but the menu bar and Quick Lookup are both disabled:

- Explain why launch at login may not provide value.
- Offer to disable it.

### 16.5 Signed-out login launch

Show signed-out menu bar state.

Do not open the authentication window automatically unless the user invokes a feature requiring it.

---

## 17. Background refresh

### 17.1 Goals

Maintain reasonably current:

- Due count.
- Daily goal.
- Word of the day.
- Synchronization status.

### 17.2 Refresh triggers

- Application launch.
- Popover open.
- Network reconnection.
- Local mutation.
- Review completion.
- Main application synchronization.
- Local day change.
- A conservative periodic interval while running.

### 17.3 Popover-open refresh

On open:

1. Render cached snapshot immediately.
2. Start lightweight refresh when stale.
3. Update without rearranging the popover unexpectedly.

### 17.4 Periodic refresh

The interval should be conservative and adaptive.

Avoid:

- Constant due-count polling.
- Remote requests while signed out.
- AI requests.
- Audio prefetch.

### 17.5 Sleep and wake

After wake:

- Recheck local day.
- Recheck connectivity.
- Refresh stale summary.
- Avoid launching duplicate sync work.

### 17.6 Battery impact

When on battery or Low Power Mode:

- Reduce nonessential refresh.
- Continue durable mutation submission when appropriate.
- Preserve user-triggered responsiveness.

---

## 18. Snapshot architecture

The menu bar should consume a compact derived snapshot:

```swift
struct MenuBarSnapshot: Sendable {
    let accountState: MenuBarAccountState
    let dueSummary: DueSummary
    let dailyGoal: DailyGoalProgress
    let activeSession: MiniSessionSummary?
    let wordOfTheDay: VocabularySummary?
    let syncSummary: SynchronizationSummary
    let reminderState: ReminderState
    let generatedAt: Date
}
```

### 18.1 Source

Compose from:

- Local vocabulary repository.
- Review repository.
- Session repository.
- Settings repository.
- Sync coordinator.

### 18.2 Update behavior

The snapshot updates when:

- Relevant local records change.
- Account changes.
- Local day changes.
- Sync status changes.

### 18.3 Consistency

Due count and daily goal should come from the same coherent local generation point where possible.

### 18.4 Widget separation

Menu bar may access account-scoped repositories in the main process.

Widgets continue to use a compact App Group snapshot.

---

## 19. State model

Illustrative state:

```swift
@MainActor
@Observable
final class MenuBarFeature {
    enum Mode {
        case summary
        case miniReview(MiniReviewFeature)
        case signedOut
        case reauthenticationRequired
    }

    private(set) var mode: Mode = .summary
    private(set) var snapshot: MenuBarSnapshot?
    private(set) var isRefreshing = false

    func appeared() async
    func openQuickLookup()
    func quickAdd()
    func startMiniReview() async
    func openFullReview()
    func openMainWindow()
    func openSettings()
    func quit()
}
```

### 19.1 State ownership

Menu bar owns:

- Popover presentation.
- Summary mode.
- Mini Review presentation.
- Lightweight refresh state.

It does not own:

- Canonical vocabulary.
- Review-event synchronization.
- Authentication credentials.
- Main-window navigation state.

---

## 20. Architecture

### 20.1 Components

```text
MenuBarScene
MenuBarFeature
MenuBarSnapshotProvider
MiniReviewFeature
SceneCoordinator
ReviewRepository
VocabularyRepository
SyncCoordinator
ReminderScheduler
```

### 20.2 Shared application environment

The menu bar uses the existing account-scoped environment.

It must not create:

- A second API client with separate token state.
- A separate sync coordinator.
- A separate audio player.
- A second local database connection with incompatible ownership.

### 20.3 SwiftUI scene

Use the appropriate native SwiftUI menu bar scene where its behavior satisfies:

- Rich popover content.
- Keyboard focus.
- Mini Review.
- Settings and window activation.

Use AppKit bridging only for missing lifecycle or focus behavior.

### 20.4 Scene coordination

Actions such as Open Voca, Open Review, Open Activity, and Quick Lookup route through the platform scene coordinator.

---

## 21. Keyboard behavior

### 21.1 Popover

- Tab moves through actions.
- Return activates focused action.
- Escape closes the popover.

### 21.2 Mini Review

```text
Space     Reveal
1         Again
2         Hard
3         Good
4         Easy
Escape    Pause and close
```

### 21.3 Text entry

If Quick Add includes a text field:

- Ordinary letter keys must not activate review shortcuts.
- Standard editing shortcuts remain intact.

### 21.4 Global shortcut

The Quick Lookup global shortcut remains independent of whether the menu bar popover is open.

---

## 22. Accessibility

### 22.1 Menu bar item label

Examples:

```text
Voca, 24 cards due
Voca, no cards due
Voca, synchronization needs attention
```

### 22.2 Popover reading order

Recommended:

1. Account or action-required state.
2. Due summary.
3. Daily goal.
4. Review actions.
5. Word of the day.
6. Quick actions.
7. Sync status.
8. Open Voca.
9. Settings.
10. Quit.

### 22.3 Mini Review

Use the same semantics as full Review:

- Prompt.
- Reveal state.
- Answer.
- Grade names and keyboard numbers.
- Progress.

### 22.4 VoiceOver updates

Announce:

- Review card changed.
- Answer revealed.
- Grade recorded.
- Session completed.
- Sync action required.

Avoid repeatedly announcing routine refresh.

### 22.5 Larger text

At larger text sizes:

- Popover may grow vertically.
- Secondary sections may be hidden behind disclosure.
- Grade buttons may wrap or stack.
- No important text truncates.

### 22.6 Increased Contrast

- Menu bar state does not rely on a faint status dot.
- Selection and focus remain visible.
- Due and warning states include text.

### 22.7 Reduced Motion

- Popover content changes without large transitions.
- Mini Review reveal is subtle.
- Completion uses a static acknowledgment.

### 22.8 Voice Control

Actions require distinct names:

- Review Five Cards.
- Open Full Review.
- Quick Lookup.
- Quick Add.
- Play Word of the Day.
- Open Voca.

---

## 23. Privacy

### 23.1 Private content preference

Setting:

```text
Show vocabulary content in menu bar
```

When disabled:

- Hide word of the day.
- Avoid displaying specific words in Mini Review until review is explicitly started.

### 23.2 Due count

Due count is generally low sensitivity, but users may hide it.

### 23.3 Screen sharing

Potential later privacy mode:

- Hide word content when screen sharing is detected or manually enabled.

Do not rely on automatic detection in the first release.

### 23.4 Logs

Allowed:

- Popover opened.
- Action category.
- Mini Review count.
- Refresh duration.
- Error category.

Disallowed:

- Word of the day text.
- Review word text.
- Meaning.
- Personal notes.
- Search query.

### 23.5 Signed-out cleanup

Immediately remove:

- Due count.
- Word content.
- Daily-goal state.
- Account-specific pending indicators.

---

## 24. Energy and performance

### 24.1 Idle state

While the popover is closed:

- No continuous animations.
- No continuous timers except a coarse day-boundary or scheduled refresh mechanism.
- No clipboard polling.
- No AI work.
- No unnecessary audio preloading.

### 24.2 Popover presentation

Target:

```text
Cached popover content displayed within 150 ms.
```

### 24.3 Refresh

Render cached snapshot first.

Never keep the popover blank while waiting for remote data.

### 24.4 Mini Review

Preload only:

- Current card.
- Next card.
- Required cached audio metadata.

### 24.5 Memory

Closing the popover should release:

- Temporary views.
- Completed Mini Review presentation state.
- Heavy word-detail content.

Preserve:

- Durable session state.
- Shared repositories.
- Compact snapshot.

### 24.6 Profiling

Measure:

- Idle CPU.
- Idle wakeups.
- Memory with main window closed.
- Popover-open latency.
- Refresh network frequency.
- Mini Review transition time.

---

## 25. Error behavior

### 25.1 Snapshot unavailable

Show:

```text
Voca couldn't load your learning summary.
[Retry] [Open Voca]
```

Keep Quick Lookup available if independent services work.

### 25.2 Offline

Show cached state and:

```text
Offline
```

Do not treat ordinary offline mode as a blocking error.

### 25.3 Authentication expired

Show:

```text
Sign in again to continue.
Your pending changes remain on this Mac.

[Sign In]
```

### 25.4 Review persistence failure

Mini Review must not advance if local grade persistence fails.

Offer:

- Retry.
- End Safely.
- Open Voca.

### 25.5 Remote sync failure

If local grade is durable:

- Advance.
- Mark pending.
- Avoid a blocking alert.

### 25.6 Word-of-the-day unavailable

- Omit the section.
- Do not fail the popover.

### 25.7 Shortcut unavailable

Quick Lookup remains available as a button.

Settings shows shortcut-registration details.

---

## 26. Reminder and day-boundary behavior

### 26.1 Local day change

At local day boundary:

- Refresh daily goal.
- Refresh streak summary.
- Select a new word of the day.
- Clear Pause Reminders Today.
- Recalculate due summary.

### 26.2 Sleep across midnight

After wake:

- Detect date change.
- Update snapshot once.
- Avoid showing previous-day goal as current.

### 26.3 Time-zone change

- Recalculate day display.
- Preserve accepted events.
- Defer authoritative streak correction to synchronization.

### 26.4 Date-change animation

Do not animate the menu bar item or issue a notification solely because the local day changed.

---

## 27. Main commands

Suggested menu bar actions:

```text
Quick Lookup
Quick Add
Review Five Cards
Open Full Review
Open Voca
Open Activity
Settings
Quit Voca
```

### 27.1 Dynamic commands

When active review exists:

```text
Resume Review
```

replaces:

```text
Review Five Cards
```

When signed out:

```text
Sign In
```

replaces review actions.

### 27.2 Destructive actions

Quit is not destructive and should not require confirmation unless:

- A non-durable user operation is genuinely in progress.

Pending durable sync work does not block quitting.

---

## 28. Analytics boundaries

### 28.1 Allowed events

- Menu bar enabled.
- Menu bar disabled.
- Popover opened.
- Review Five Cards started.
- Mini Review completed.
- Quick Lookup invoked.
- Quick Add invoked.
- Open Voca invoked.
- Refresh timing.
- Technical error category.

### 28.2 Prohibited content

- Word text.
- Meaning.
- Review card content.
- Personal note.
- Search query.
- Tag names.
- Clipboard content.

### 28.3 Background metrics

Safe:

- Refresh count.
- Network request count.
- Idle wakeup measurements during internal testing.

Do not collect continuous user-level energy telemetry without explicit product review.

---

## 29. Testing strategy

### 29.1 Enablement tests

- Enable item.
- Disable item.
- Relaunch.
- Main app remains functional.
- Login-item configuration remains separate.

### 29.2 Lifecycle tests

- Close main window.
- Use menu bar.
- Reopen main window.
- Quit.
- Relaunch at login.

### 29.3 Account tests

- Signed in.
- Signed out.
- Reauthentication required.
- Account switch.
- Pending mutations.

### 29.4 Summary tests

- Due cards.
- No cards due.
- Goal incomplete.
- Goal complete.
- Active review.
- Offline.
- Sync action required.

### 29.5 Mini Review tests

- Start with five or more due cards.
- Start with fewer than five.
- Reveal and grade.
- Rapid duplicate grade input.
- Close mid-session.
- Resume.
- Complete offline.
- Reconnect and synchronize.

### 29.6 Word-of-the-day tests

- Deterministic daily selection.
- Deleted selected card.
- Privacy preference disabled.
- Offline.
- Local day change.

### 29.7 Accessibility tests

- Menu item due-count label.
- VoiceOver reading order.
- Keyboard-only Mini Review.
- Larger text.
- Increased Contrast.
- Reduce Motion.

### 29.8 Energy tests

- Idle for one hour.
- Main window closed.
- Offline idle.
- Signed-out idle.
- Popover opened repeatedly.
- Mini Review.

### 29.9 Performance tests

- First popover open.
- Warm popover open.
- Snapshot refresh.
- Account switch.
- Review transition.

---

## 30. Requirement traceability

### `MENU-001` — Optional menu bar item

Covered by:

- Enablement preference.
- Independent disable behavior.
- Relaunch persistence.

### `MENU-002` — Due count

Covered by:

- Display modes.
- User preference.
- Count semantics.
- No-due state.

### `MENU-003` — Quick actions

Covered by:

- Quick Lookup.
- Quick Add.
- Start or resume Review.
- Open Voca.

### `MENU-004` — Mini Review

Covered by:

- Five-card scope.
- Reveal.
- Four grades.
- Durable events.
- Completion and full-review transition.

---

## 31. Acceptance scenarios

### Scenario A — Enable menu bar

1. Open Settings.
2. Enable Show Voca in the Menu Bar.
3. Close the main window.
4. Open menu bar popover.

Expected:

- Item appears.
- Voca remains usable without a main window.
- Cached summary appears.

### Scenario B — Disable menu bar

1. Disable the menu bar preference.

Expected:

- Item disappears.
- Main app remains open.
- Quick Lookup follows its independent setting.

### Scenario C — Due count preference

1. Enable numeric due count.
2. Complete reviews.

Expected:

- Count updates.
- Zero follows the selected display policy.
- No duplicate progress occurs.

### Scenario D — Mini Review

1. Open menu bar.
2. Start Review Five Cards.
3. Reveal and grade with keyboard.
4. Complete.

Expected:

- Five or fewer due cards are reviewed.
- Each grade persists once.
- Summary updates immediately.

### Scenario E — Resume active review

1. Pause a full Review session.
2. Open menu bar.

Expected:

- Resume Review is primary.
- Independent Mini Review is not started.

### Scenario F — Main window closed

1. Close all main Voca windows.
2. Use Quick Lookup from menu bar.
3. Open Voca.

Expected:

- Quick Lookup works.
- Main workspace is created or restored.

### Scenario G — Signed out

1. Sign out.
2. Open menu bar.

Expected:

- Private account state is gone.
- Sign In appears.
- Prior due count and word content are absent.

### Scenario H — Offline

1. Disconnect.
2. Open menu bar.
3. Complete a cached Mini Review.

Expected:

- Cached summary appears.
- Grades are stored locally.
- Pending state appears.
- Reconnection synchronizes once.

### Scenario I — Launch at login

1. Enable menu bar and Launch at Login.
2. Log in to macOS.

Expected:

- Voca starts in background.
- Menu bar appears.
- Main window does not open automatically.

### Scenario J — Word privacy

1. Disable vocabulary content in menu bar.
2. Open popover.

Expected:

- Word of the day is hidden.
- Due and goal summaries remain.

### Scenario K — Sync conflict

1. Create a personal-note conflict.
2. Open menu bar.

Expected:

- Action-required summary appears.
- Raw note text is not shown.
- Open Activity routes correctly.

### Scenario L — VoiceOver

1. Enable VoiceOver.
2. Focus menu bar item.
3. Open popover.
4. Complete Mini Review.

Expected:

- Due count is announced.
- Reading order is logical.
- Review states and grades are clear.

### Scenario M — Idle energy

1. Leave Voca running with the main window closed.
2. Do not open the popover for an extended period.

Expected:

- No continuous high-frequency wakeups.
- No clipboard polling.
- Refresh requests remain within policy.

---

## 32. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. The menu bar companion is optional.
2. Numeric due count is user-configurable and hidden by default.
3. Closing the main window leaves Voca running when menu bar mode is enabled.
4. Quit Voca explicitly terminates ambient services.
5. Mini Review contains no more than five cards.
6. An active full session replaces the Mini Review entry point with Resume Review.
7. Mini Review uses the same review-event contract as full Review.
8. Quick Add reuses Quick Lookup in the first release.
9. Word of the day uses deterministic local selection.
10. Vocabulary content in the menu bar can be hidden.
11. Launch at Login is optional and disabled by default.
12. Login launch does not open the main workspace automatically.
13. Cached snapshot renders before remote refresh.
14. Routine synchronization does not animate the menu bar icon.
15. Background refresh is conservative and energy-aware.

---

## 33. Open questions

1. Should the menu bar item be enabled during onboarding or only through Settings?
2. Should the default show a numeric due count?
3. Which template icon best represents Voca at menu-bar size?
4. Should the Dock icon always remain visible?
5. Should the popover include Word of the Day by default?
6. What exact rule selects Word of the Day?
7. Should Quick Add open Quick Lookup or a dedicated compact form?
8. Should Mini Review share an existing review-session object?
9. How should Escape behave during an active Mini Review?
10. Should Mini Review completion automatically close the popover?
11. How frequently should background due-count refresh occur?
12. Should Low Power Mode disable periodic refresh?
13. Should Launch at Login automatically register Quick Lookup?
14. Should signed-out local lookup remain available?
15. Should a privacy mode hide all word content temporarily?
16. Should action-required sync state appear on the menu bar icon?
17. Should reminder controls appear directly or under More?
18. Should Open Voca restore Today or the last destination?
19. How should account switching work if multiple account partitions remain locally?
20. Does the selected SwiftUI menu bar API provide sufficient keyboard focus for Mini Review?

---

## 34. Dependencies

The menu bar companion depends on:

- Account-scoped shared application environment.
- Local Today-style snapshot.
- Due-card query.
- Stable review-event behavior.
- Offline queue.
- Quick Lookup coordinator.
- Main scene coordinator.
- Settings and launch-at-login service.
- Menu bar scene support.
- Notification scheduler.
- Audio coordinator.
- Account privacy cleanup.

Backend dependencies:

- Due-card state.
- Idempotent review events.
- Daily-goal data or derivable events.
- Active-card state.
- Incremental synchronization.

---

## 35. Definition of done

The menu bar companion is complete for the macOS differentiation release when:

- It can be enabled and disabled independently.
- The menu bar item renders correctly in Light and Dark Mode.
- Due status follows the user's display preference.
- Signed-out state exposes no prior private data.
- Cached summary appears immediately.
- Quick Lookup and Quick Add route correctly.
- Mini Review records each grade exactly once.
- Active full Review is resumed instead of duplicated.
- Closing the main window leaves ambient features available.
- Open Voca restores or creates the main workspace.
- Launch at Login works without opening the main window.
- Offline Mini Review follows the documented capability.
- Sync status is understandable but unobtrusive.
- Word-content privacy preference works.
- VoiceOver, keyboard, larger text, Increased Contrast, and Reduce Motion pass.
- Idle CPU, wakeups, memory, and network frequency meet the agreed targets.
- Critical lifecycle, account, review, and synchronization tests pass.

---

## 36. Next document

The next document should be:

```text
docs/macos-system-integrations.md
```

It should define:

- App Intents.
- Shortcuts actions and entities.
- Spotlight indexing.
- macOS Services.
- Widgets.
- Notifications.
- Deep-link contracts.
- Authentication behavior.
- Extension dependency boundaries.
- Shared App Group snapshots.
- Privacy and signed-out cleanup.
- Accessibility.
- Testing.
- Acceptance criteria mapped to `SYS-*`.
