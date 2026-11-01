# Voca for macOS — Review Experience

> Product, UX, interaction, state, synchronization, accessibility, and acceptance specification for FSRS-based review on macOS.

## Document status

- **Status:** Draft
- **Document type:** Feature Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Related vocabulary specification:** [`macos-vocabulary.md`](macos-vocabulary.md)
- **Primary requirement group:** `REV-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the complete review experience for Voca on macOS.

It covers:

- Review eligibility.
- Due-card queues.
- Session configuration.
- Session lifecycle.
- Prompt and answer presentation.
- FSRS grading.
- Keyboard interaction.
- Focus Review window.
- English and Chinese variants.
- Audio behavior.
- Recognition, type-in, and listening modes.
- Pause, resume, cancellation, and recovery.
- Offline review.
- Idempotent grade submission.
- Session summary.
- Accessibility.
- Performance.
- Privacy.
- Acceptance criteria.

Review is the mechanism that converts saved vocabulary into durable knowledge. Reliability and speed are more important than decorative complexity.

---

## 2. Product intent

Review should help users answer one question repeatedly and honestly:

> How well did I remember this word?

The experience should:

- Start quickly.
- Keep the learner focused.
- Minimize pointer movement.
- Make keyboard controls predictable.
- Preserve progress safely.
- Avoid duplicate grade submission.
- Work when temporarily offline.
- Explain failures without losing completed work.
- Support English and Chinese naturally.

The review experience should not:

- Turn honest self-assessment into a competitive game.
- Reward users for choosing Easy inaccurately.
- Interrupt every answer with animation.
- Expose unnecessary algorithm complexity.
- Require the main application sidebar during an active session.

---

## 3. Product principles

### REV-PRN-001 — One card, one decision

Each review step should focus on:

1. Recall.
2. Reveal.
3. Self-assessment.
4. Continue.

### REV-PRN-002 — Keyboard is the fastest path

The full default review session must be completable without a pointer.

### REV-PRN-003 — Acknowledged grades are durable

Once the interface accepts a grade, it must be recorded locally before moving to the next card.

### REV-PRN-004 — Network latency must not define review pace

The next card should not wait on an ordinary remote round trip when safe local queuing is available.

### REV-PRN-005 — Grading remains user-controlled

Voca may provide interval previews and feedback, but must not infer a review grade without explicit user action.

### REV-PRN-006 — Review and practice are separate

FSRS grading changes scheduling state. Practice activities reinforce vocabulary but must not silently modify FSRS state.

### REV-PRN-007 — Session recovery is explicit

After interruption, Voca must offer a clear choice to resume or discard remaining session work without duplicating completed grades.

### REV-PRN-008 — Honest review over streak pressure

Visual feedback should encourage consistency without shaming users or promoting inaccurate grades.

---

## 4. Scope

### 4.1 Included

- Due-card overview.
- Session setup.
- Stable review queue.
- Prompt state.
- Revealed-answer state.
- Again, Hard, Good, and Easy grades.
- Keyboard shortcuts.
- Pronunciation.
- Focus Review window.
- Pause and resume.
- Session recovery.
- Session summary.
- English and Chinese cards.
- Recognition mode.
- Type-in mode.
- Listening mode.
- Offline grade queue.
- Review-event idempotency.
- Accessibility.

### 4.2 Related but specified elsewhere

- Today dashboard.
- Vocabulary detail.
- General synchronization.
- Notification reminders.
- Menu bar Mini Review.
- Widgets.
- AI-generated drills.
- Conversation practice.
- General design tokens.

### 4.3 Excluded from the first review release

- Competitive leaderboards.
- Social review challenges.
- Automatic grading from webcam behavior.
- Fully automated pronunciation scoring.
- User-authored review templates.
- Simultaneous review sessions on one account.
- Arbitrary custom FSRS parameters unless exposed by the backend.

---

## 5. Terminology

### 5.1 Due card

A user card eligible for review according to the authoritative study state.

### 5.2 Review session

A stable, ordered set of cards presented for review.

### 5.3 Review event

One explicit assessment of one card.

It includes:

- Stable operation ID.
- Session ID.
- User-card ID.
- Grade.
- Review timestamp.
- Client metadata needed for reconciliation.

### 5.4 Prompt

The information shown before answer reveal.

### 5.5 Answer

The information shown after reveal.

### 5.6 Grade

The learner's self-assessment:

```text
Again
Hard
Good
Easy
```

### 5.7 Mode

The interaction used to recall a card:

```text
Recognition
Type-in
Listening
```

### 5.8 Active session

A session with remaining cards or uncommitted local events.

### 5.9 Mini Review

A deliberately short review flow presented from the menu bar. It uses the same review domain behavior but a separate compact UI.

---

## 6. Review entry points

Users may enter Review from:

- Sidebar Review.
- Today Start Review.
- Due-count toolbar action.
- Notification.
- Menu bar.
- Widget.
- App Intent.
- Shortcut.
- Command Palette.
- Vocabulary Due Today collection.
- Difficult Words targeted review.

All entry points must route through a shared session-start use case.

### 6.1 Entry-point semantics

#### Start Review

Starts or configures a full review session.

#### Review Five Cards

Starts a limited session of no more than five cards.

#### Review Selected Words

Starts a targeted session using an explicit vocabulary selection. The UI must distinguish this from a scheduled due review.

#### Resume Review

Opens the currently active recoverable session.

### 6.2 Canonical routes

```text
/review
/review/setup
/review/session/{sessionID}
/review/summary/{sessionID}
```

---

## 7. Review overview

The Review destination before a session presents:

- Due-card count.
- Language scope.
- Estimated session size.
- Session mode.
- Audio preference.
- Start Review.
- Resume active session when one exists.
- Next due information when none are currently due.

### 7.1 Ready state

Example:

```text
24 cards are due

English: 18
Chinese: 6

[Start Review]
```

### 7.2 No cards due

Show:

- Confirmation that the user is caught up.
- Next scheduled review when available.
- Optional practice action.
- Optional Difficult Words action.

Do not:

- Manufacture additional due cards.
- Pressure the user to study indefinitely.
- Present an error state.

### 7.3 Offline state

If a valid cached queue can be created:

- Allow offline review.
- Explain that grades will synchronize later.

If no valid local due data exists:

- Explain that Voca cannot determine the due queue offline.
- Offer Retry.
- Offer practice that does not alter FSRS state.

---

## 8. Review eligibility

### 8.1 Authority

The backend remains authoritative for:

- Final due eligibility.
- FSRS scheduling.
- Accepted review events.
- Reconciled study state.

The Mac client may cache enough study state to support offline review.

### 8.2 Eligibility inputs

Potential inputs:

- Due timestamp.
- Card active state.
- Language scope.
- Collection restriction.
- User study settings.
- Session-size limit.
- Exclusion of deleted or suspended cards.

### 8.3 Suspended and deleted cards

Cards that become suspended or deleted before presentation:

- Are removed from the remaining queue.
- Are not graded.
- Do not cause session failure.

### 8.4 Cards already reviewed elsewhere

If another device reviews a queued card:

- Reconcile before presentation when synchronization has already reported the change.
- If already presented offline, submit using stable event semantics and resolve with server policy.
- Never silently create multiple accepted review events for one intended action.

---

## 9. Session setup

### 9.1 Required configuration

The default setup should require minimal decisions.

Defaults:

- Due cards.
- Current or combined language scope.
- Recognition mode.
- User's saved audio preference.
- User's preferred session size.

### 9.2 Optional configuration

- Language.
- Card source.
- Maximum card count.
- Review mode.
- Auto-play audio.
- Answer direction.
- Focus window.

### 9.3 Card source

Possible sources:

```text
All due cards
English due cards
Chinese due cards
Selected Smart List
Difficult Words
Selected vocabulary
```

### 9.4 Session-size presets

Suggested:

```text
5
10
20
All due
```

The default should reflect user settings.

### 9.5 Estimated duration

Voca may display an approximate duration based on:

- Card count.
- Historical average.
- Selected mode.

It must be labeled as an estimate.

### 9.6 Start behavior

Starting:

1. Validates authentication or offline capability.
2. Resolves source.
3. Builds a stable queue.
4. Creates a session identity.
5. Persists session snapshot.
6. Opens active Review.

---

## 10. Session identity and queue

### 10.1 Stable session ID

Each session receives a stable local identifier:

```text
ReviewSessionID
```

### 10.2 Queue snapshot

The session persists:

- Ordered user-card IDs.
- Current index.
- Completed card IDs.
- Pending review event IDs.
- Mode.
- Language scope.
- Source.
- Created timestamp.
- Last activity timestamp.

It should not persist unnecessary duplicate dictionary content.

### 10.3 Queue order

Queue ordering should:

- Follow backend or study-service recommendations.
- Avoid predictable categorization that reveals answers.
- Remain stable after session start.
- Exclude invalid cards safely.

### 10.4 Queue mutation

Cards may be removed when:

- Deleted.
- Suspended.
- No longer accessible.

Cards should not normally be inserted into an active session because new cards became due.

### 10.5 Concurrent session rule

Only one full active session per account is recommended.

Starting another session presents:

```text
Resume Current Session
End Current Session and Start New
Cancel
```

---

## 11. Session lifecycle

State model:

```text
Preparing
Ready
Presenting Prompt
Presenting Answer
Recording Grade
Advancing
Paused
Completing
Completed
Recoverable Error
Discarded
```

### 11.1 Preparing

Tasks:

- Load local card content.
- Confirm valid queue.
- Prepare first audio if configured.

### 11.2 Presenting Prompt

Allowed actions:

- Reveal.
- Play available prompt audio.
- Edit or inspect through a deliberate command.
- Pause.

Grade actions are disabled until reveal except in specialized modes where grading follows typed-answer evaluation.

### 11.3 Presenting Answer

Allowed actions:

- Play pronunciation.
- Choose grade.
- Open word detail.
- Pause.

### 11.4 Recording Grade

The client:

1. Creates the review event.
2. Persists it locally.
3. Marks the current card completed locally.
4. Begins synchronization.
5. Advances to the next card.

### 11.5 Paused

The session remains recoverable.

### 11.6 Completing

Voca:

- Ensures all accepted local events are durable.
- Calculates local summary.
- Continues remote synchronization if needed.

### 11.7 Completed

The user sees the session summary.

Pending remote events may remain visible as:

```text
Saved on this Mac · Waiting to sync
```

---

## 12. Review window

### 12.1 Recommended presentation

Full review should use a dedicated window or a focused workspace mode.

Preferred dedicated-window structure:

```text
┌──────────────────────────────────────────────────────────────┐
│ Progress                           Audio   Pause   More       │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                         Prompt                               │
│                                                              │
│                  [Reveal Answer · Space]                     │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│ Again          Hard           Good           Easy            │
│   1              2              3              4              │
└──────────────────────────────────────────────────────────────┘
```

### 12.2 Suggested dimensions

```text
Minimum width       720
Preferred width     880–1080
Minimum height      560
Preferred height    680–820
```

### 12.3 Full screen

The Review window may enter full screen independently.

Full screen:

- Removes unrelated controls.
- Preserves essential progress.
- Keeps Escape behavior predictable.

### 12.4 Sidebar

The active Review window does not show the main sidebar.

### 12.5 Window closure

Closing an active session should:

- Pause safely.
- Never discard silently.
- Avoid unnecessary confirmation if all work is already durable.

If discard is requested explicitly, show consequences.

---

## 13. Review card anatomy

### 13.1 Shared regions

```text
Session metadata
Prompt
Prompt support
Reveal
Answer
Answer support
Grade controls
```

### 13.2 Prompt region

May contain:

- Word.
- Meaning.
- Hanzi.
- Audio.
- Example with omitted target.
- Type-in field.

### 13.3 Answer region

May contain:

- Word or Hanzi.
- Pronunciation or pinyin.
- Meaning.
- Example.
- User note when enabled.
- Additional context.

### 13.4 Secondary metadata

May display:

- Learning level.
- Tags.
- Source collection.

Do not display scheduling data before recall if it could bias the grade.

### 13.5 Stable layout

The prompt should not jump unpredictably after reveal.

Recommended:

- Preserve the prompt location.
- Reveal answer below with a controlled transition.
- Keep grade controls in a stable bottom region.

---

## 14. Recognition mode

Recognition is the default mode.

### 14.1 Forward direction

Prompt:

- Word or Hanzi.

Answer:

- Pronunciation or pinyin.
- Meaning.
- Example.

### 14.2 Reverse direction

Prompt:

- Meaning.

Answer:

- Word or Hanzi.
- Pronunciation.
- Example.

Reverse direction may be:

- A user preference.
- A session option.
- Interleaved according to backend policy.

### 14.3 Recall behavior

The user:

1. Attempts recall.
2. Presses Space.
3. Reads the answer.
4. Chooses a grade.

---

## 15. Type-in mode

### 15.1 Purpose

Type-in mode tests productive recall.

### 15.2 Prompt

May show:

- Meaning.
- Example with target removed.
- Audio.
- Language indicator.

### 15.3 Input

The answer field:

- Receives initial focus.
- Supports native editing.
- Does not submit on every keystroke.

### 15.4 Submit

Recommended:

```text
Return       Check answer
```

After checking:

- Show expected answer.
- Show typed answer.
- Highlight relevant difference accessibly.
- Enable FSRS grade controls.

### 15.5 Comparison normalization

English may normalize:

- Case.
- Leading and trailing whitespace.
- Unicode normalization.

Chinese may normalize:

- Whitespace.
- Unicode normalization.

Do not automatically ignore a materially incorrect character.

### 15.6 Automatic grading

The comparison may offer feedback:

```text
Exact match
Close match
Different answer
```

It must not automatically submit an FSRS grade in the first version.

### 15.7 Alternatives

If multiple valid answers exist:

- Display accepted alternatives.
- Avoid marking a valid synonym wrong when the card explicitly supports it.

---

## 16. Listening mode

### 16.1 Purpose

Listening mode emphasizes audio recognition.

### 16.2 Prompt

Prompt consists of:

- Audio.
- Replay action.
- Optional language indicator.

The written word is hidden until reveal.

### 16.3 Controls

```text
Space or configured shortcut   Replay audio before reveal
Return                          Reveal or check response
```

Final shortcuts must avoid conflict with general reveal behavior.

### 16.4 Answer

Show:

- Word or Hanzi.
- Pronunciation or pinyin.
- Meaning.
- Example.

### 16.5 Audio failure

If audio cannot be loaded:

- Allow retry.
- Allow skip without grading.
- Allow conversion to recognition mode.
- Do not force an inaccurate grade.

---

## 17. English review cards

### 17.1 Forward recognition

Prompt:

```text
concise
```

Answer:

```text
/kənˈsaɪs/
brief but comprehensive
Keep your explanation concise.
```

### 17.2 Reverse recognition

Prompt:

```text
brief but comprehensive
```

Answer:

```text
concise
/kənˈsaɪs/
```

### 17.3 Example cloze

Prompt:

```text
Keep your explanation ______.
```

Answer:

```text
concise
```

### 17.4 Part of speech

Part of speech may appear after reveal.

It should not be required if backend content does not provide it reliably.

---

## 18. Chinese review cards

### 18.1 Hanzi to meaning

Prompt:

```text
简洁
```

Answer:

```text
jiǎnjié
ngắn gọn, súc tích
```

### 18.2 Meaning to Hanzi

Prompt:

```text
ngắn gọn, súc tích
```

Answer:

```text
简洁
jiǎnjié
```

### 18.3 Audio to Hanzi

Prompt:

- Mandarin audio.

Answer:

```text
简洁
jiǎnjié
ngắn gọn, súc tích
```

### 18.4 Pinyin prompt

Pinyin-only prompting should be configurable and not assumed useful for every learner.

### 18.5 Writing prompt

Writing practice may be a Practice mode rather than an FSRS review mode initially.

It should not modify FSRS scheduling unless the user explicitly grades recall.

---

## 19. Reveal behavior

### 19.1 Default command

```text
Space
```

### 19.2 Before reveal

- Grade controls are disabled or hidden.
- Answer content is inaccessible visually and to VoiceOver.
- The Reveal action is prominent.

### 19.3 After reveal

- Answer content becomes available.
- Grade controls become enabled.
- Focus remains stable unless accessibility behavior requires moving it.
- Pronunciation may auto-play if configured.

### 19.4 Repeat reveal

Pressing Space after reveal must not accidentally grade.

It may:

- Do nothing.
- Replay pronunciation if explicitly configured.

The default should avoid accidental actions.

### 19.5 Reduced motion

Use immediate or subtle opacity change instead of large flips.

---

## 20. FSRS grades

### 20.1 Grade meanings

#### Again

The learner did not recall the answer.

#### Hard

The learner recalled with substantial difficulty or uncertainty.

#### Good

The learner recalled correctly with normal effort.

#### Easy

The learner recalled immediately and confidently.

### 20.2 Controls

Each button displays:

- Number.
- Label.
- Optional next-interval preview.

```text
[1 Again] [2 Hard] [3 Good] [4 Easy]
```

### 20.3 Keyboard

After reveal:

```text
1    Again
2    Hard
3    Good
4    Easy
```

Before reveal:

- Number keys must not submit grades.

### 20.4 Interval preview

If the backend or local study engine can provide reliable estimates:

```text
Again   10m
Hard    2d
Good    5d
Easy    12d
```

If estimates are not authoritative:

- Omit them.
- Do not show misleading values.

### 20.5 Submission lock

After selecting a grade:

- Disable all grade controls immediately.
- Persist one event.
- Ignore repeated key input until advancing.

### 20.6 Undo grade

Potential behavior:

- Allow Undo immediately before another card is graded.

This requires:

- Backend cancellation or compensating behavior.
- Local queue support.
- Clear scheduling reconciliation.

Until reliable, do not promise grade undo.

---

## 21. Keyboard interaction

### 21.1 Default shortcuts

```text
Space                       Reveal answer
1                           Again
2                           Hard
3                           Good
4                           Easy
Option + P                  Play pronunciation
E                           Edit current word
A                           Ask Assistant
Command + Shift + P         Pause session
Escape                      Open pause controls or exit focus state
Command + .                 Cancel current cancellable operation
```

Final shortcuts must be validated against:

- Text input.
- VoiceOver.
- macOS-reserved commands.
- Application menus.

### 21.2 Type-in exceptions

When the answer field has focus:

- Letter shortcuts do not trigger application commands.
- Return checks the answer.
- Escape exits the field or opens pause behavior according to focus state.

### 21.3 Shortcut discoverability

Shortcuts appear in:

- Study menu.
- Tooltips.
- Grade buttons.
- First-session onboarding.
- Review help.

### 21.4 Keyboard focus order

Prompt state:

1. Prompt content.
2. Pronunciation if available.
3. Reveal.
4. Pause.

Answer state:

1. Answer content.
2. Pronunciation.
3. Again.
4. Hard.
5. Good.
6. Easy.
7. Additional actions.

---

## 22. Pronunciation and audio

### 22.1 Auto-play settings

Options:

```text
Never
When prompt appears
When answer is revealed
Listening mode only
```

Settings may differ for:

- English.
- Chinese.

### 22.2 Manual playback

Available in:

- Prompt when appropriate.
- Revealed answer.
- Toolbar.
- Keyboard command.

### 22.3 Playback coordination

Only one Voca audio source plays at a time.

Starting new audio stops the prior playback.

### 22.4 Preloading

Voca may preload the next card's cached or remote audio when:

- Network policy permits.
- Session mode requires it.
- Battery and resource use remain reasonable.

### 22.5 Failure

Audio failure:

- Never blocks reveal.
- Never blocks grade.
- Offers retry.
- Does not repeat noisy alerts on every card.

### 22.6 Speech accessibility

Audio controls need labels such as:

```text
Play pronunciation for concise
Replay Mandarin pronunciation for 简洁
```

---

## 23. Progress

### 23.1 Visible progress

Show one of:

```text
7 of 24
17 remaining
```

The final choice should remain stable across the session.

### 23.2 Progress bar

A subtle progress bar may accompany the count.

### 23.3 Pending synchronization

Do not mix remote sync progress with learning progress.

If needed, show a subtle separate status:

```text
2 reviews waiting to sync
```

### 23.4 Time

Elapsed time may appear:

- In pause state.
- In summary.

Avoid displaying a constantly prominent timer if it creates pressure.

---

## 24. Pause behavior

### 24.1 Pause triggers

- Explicit Pause.
- Window close.
- Application termination.
- Account state change.
- System interruption where relevant.

### 24.2 Pause screen

Show:

- Completed count.
- Remaining count.
- Elapsed time.
- Resume.
- End Session.
- Return to Voca.

### 24.3 Persistence

Before entering paused state:

- Persist current index.
- Persist completed event IDs.
- Preserve unsubmitted durable events.

### 24.4 End Session

Ending:

- Keeps already completed review events.
- Discards only the remaining queue.
- Produces a partial summary.

Copy must make this clear.

### 24.5 Discard

The product should avoid the ambiguous word “Discard” when completed grades will remain.

Prefer:

```text
End Session
```

with explanation:

```text
Completed reviews will be kept. Remaining cards will return to the due queue.
```

---

## 25. Resume and recovery

### 25.1 Resume prompt

If a recoverable session exists:

```text
Resume Review
Started today at 09:20
12 of 24 cards completed
```

Actions:

- Resume.
- End Session.

### 25.2 Validation

Before resume:

- Verify account.
- Load session snapshot.
- Remove invalid remaining cards.
- Reconcile accepted pending events where possible.
- Restore current card safely.

### 25.3 Interrupted grade

If the application stopped after local persistence but before UI advancement:

- Detect completed operation ID.
- Advance without creating a duplicate event.

### 25.4 Corrupt session

If session data is invalid:

- Preserve durable review events.
- End the broken session.
- Return remaining cards to future due calculation.
- Explain recovery.

### 25.5 Session expiry

Long-abandoned sessions may require:

- Reconciliation.
- Queue rebuild.
- Explicit notice.

The expiry rule must be documented and consistent.

---

## 26. Offline review

### 26.1 Offline prerequisites

Offline review requires cached:

- User card.
- Prompt and answer content.
- Study state.
- Due timestamp.
- Required audio when listening mode depends on it.

### 26.2 Starting offline

If cached study state is fresh enough under product policy:

- Build local due queue.
- Label session as offline-capable.

If freshness is insufficient:

- Explain limitation.
- Offer nongraded practice.

### 26.3 Recording offline grades

For each grade:

1. Generate stable operation ID.
2. Persist review event.
3. Update local predicted study state.
4. Mark event pending.
5. Advance.

### 26.4 Reconnection

On reconnect:

- Submit pending events in deterministic order.
- Use idempotency key.
- Apply authoritative server state.
- Update local schedules.

### 26.5 Ambiguous remote result

If network loss occurs after submission:

- Do not create a new operation ID.
- Retry or reconcile using the same ID.

### 26.6 Conflict

If server state changed on another device:

- Submit original event when contract permits.
- Recalculate authoritative sequence.
- Notify only if user action is required.
- Never silently drop a completed grade.

---

## 27. Review-event contract

Recommended event shape:

```swift
struct ReviewEvent: Codable, Hashable, Sendable {
    let operationID: UUID
    let sessionID: ReviewSessionID
    let userCardID: UserCardID
    let grade: ReviewGrade
    let reviewedAt: Date
    let mode: ReviewMode
    let clientVersion: String
}
```

The final backend contract may add:

- Previous state version.
- Time zone.
- Device identifier that does not expose private hardware data.
- Sequence number.

### 27.1 Idempotency

The backend should guarantee:

```text
Same operationID
→ same accepted review event
→ no duplicate scheduling update
```

### 27.2 Ordering

Events for one card must be processed in a deterministic order.

### 27.3 Local predicted state

The client may show predicted next-review information while offline.

It must reconcile to the server's authoritative state later.

### 27.4 Unsupported backend

If backend idempotency is unavailable:

- Robust offline grading remains blocked.
- The client may require online review.
- The limitation must be explicit in roadmap and Activity.

---

## 28. Editing during review

### 28.1 Entry

The user may open Edit with:

- `E`.
- More menu.

### 28.2 Presentation

Editing should:

- Pause card timing if timing is measured.
- Preserve prompt or answer state.
- Open a sheet or secondary window.

### 28.3 Save

After save:

- Update current card content.
- Preserve session position.
- Do not submit a review grade.

### 28.4 Delete

Deleting the current card:

- Requires confirmation.
- Removes it from the remaining queue.
- Does not create a grade.
- Advances after successful local persistence.

### 28.5 Content error

Users may report or flag incorrect generated content in a later version without leaving review.

---

## 29. Ask Assistant during review

### 29.1 Purpose

The user may need:

- Explanation.
- Comparison.
- Another example.
- Usage clarification.

### 29.2 Behavior

Ask Assistant:

- Opens contextual assistance.
- Includes only the current word and explicitly selected content.
- Does not grade the card.
- Preserves session state.

### 29.3 Presentation

Prefer:

- Side panel.
- Separate temporary window.

Avoid replacing the review window entirely.

### 29.4 AI effect on grade

The learner still selects the grade.

Voca must not reduce the grade automatically because assistance was used.

It may display a subtle reminder to grade honestly.

---

## 30. Mini Review

### 30.1 Scope

Mini Review supports:

- Up to five cards.
- Recognition mode.
- Reveal.
- Four grades.
- Pronunciation.

### 30.2 Excluded

- Editing.
- Long explanations.
- AI workspace.
- Complex session setup.
- Writing practice.
- Full history.

### 30.3 Domain behavior

Mini Review uses:

- Same due-card source.
- Same event IDs.
- Same persistence.
- Same backend grade contract.

### 30.4 Transition

Open Full Review:

- Continues with remaining due cards.
- Does not repeat cards already graded.

---

## 31. Session summary

### 31.1 Required information

- Cards reviewed.
- Completed state.
- Again count.
- Hard count.
- Good count.
- Easy count.
- Difficult cards.
- Pending synchronization status.

### 31.2 Optional information

- Time spent.
- Average response time.
- Language breakdown.
- Current streak.
- Daily-goal contribution.

Response-time metrics must not pressure users or imply that faster always means better.

### 31.3 Next actions

- Return to Today.
- Review Difficult Cards.
- Start Practice.
- Open Vocabulary.
- Close.

### 31.4 Partial-session summary

If ended early:

- Label it as a partial session.
- Keep completed reviews.
- Show remaining due count.

### 31.5 Pending events

If offline:

```text
Your 12 completed reviews are saved on this Mac and will sync automatically.
```

---

## 32. Notifications and review

### 32.1 Reminder routing

Review notification:

```text
Open notification
→ Review overview
→ Resume active session or start due session
```

### 32.2 Actions

Possible actions:

- Review Now.
- Remind in One Hour.
- Done for Today.

“Done for Today” should silence reminders, not alter card schedules.

### 32.3 Privacy

Notifications should not show specific vocabulary by default when screen privacy is a concern.

---

## 33. Error behavior

### 33.1 Card content unavailable

Action:

- Skip without grade.
- Mark for refresh.
- Continue session.

### 33.2 Grade persistence failure

Do not advance until local persistence succeeds.

Show:

- Retry.
- End Session Safely.

### 33.3 Remote submission failure

If local persistence succeeded:

- Advance.
- Mark pending.
- Retry later.

### 33.4 Authentication expiry

If local review may continue safely:

- Pause.
- Request reauthentication.
- Resume after authentication.

If not safe:

- Preserve session.
- Return to sign in.

### 33.5 Audio failure

- Continue review.
- Offer Retry.
- Avoid repeated blocking alerts.

### 33.6 Invalid session

- Preserve completed events.
- Explain recovery.
- Return remaining cards to due-state calculation.

---

## 34. Accessibility

### 34.1 VoiceOver card order

Prompt state:

1. Session progress.
2. Prompt.
3. Prompt audio.
4. Reveal.
5. Pause.

Answer state:

1. Prompt.
2. Answer.
3. Pronunciation.
4. Example.
5. Again.
6. Hard.
7. Good.
8. Easy.
9. Additional actions.

### 34.2 Reveal announcement

After reveal, announce:

```text
Answer revealed
```

Do not automatically read a very long answer unless VoiceOver navigation naturally reaches it.

### 34.3 Grade labels

Example:

```text
Good, keyboard shortcut 3, next review approximately 5 days
```

Only announce interval if reliable.

### 34.4 Color independence

Grade controls include:

- Number.
- Label.
- Color.

### 34.5 Focus

Keyboard focus remains visible.

After grade:

- Focus moves logically to the next card content.
- It does not remain on a disabled prior-grade control.

### 34.6 Reduced Motion

- No required card flip.
- Minimal answer transition.
- Minimal completion effects.

### 34.7 Larger text

- Prompt wraps.
- Answer remains readable.
- Grade controls may stack or adapt.
- No important content truncates.

### 34.8 Audio alternatives

Listening mode must provide a documented alternative when the user cannot or chooses not to use audio.

---

## 35. Performance

### 35.1 Card transition

The next locally available card should appear without a perceptible network wait.

### 35.2 Preloading

Prepare:

- Next card content.
- Cached audio metadata.
- Necessary display formatting.

Do not preload:

- Full AI explanation.
- Heavy stroke resources.
- Long review history.

### 35.3 Persistence

Local event persistence must be fast and transactional.

### 35.4 Memory

Do not load an entire very large due collection when:

- Session size is limited.
- Cursor-based retrieval is available.

### 35.5 Energy

- Avoid continuous timers.
- Avoid unnecessary audio prefetch.
- Avoid polling remote review state during every card.

---

## 36. Privacy and analytics

### 36.1 Allowed analytics

- Session started.
- Session completed.
- Session ended early.
- Review mode.
- Card count.
- Grade distribution in aggregate.
- Offline session used.
- Technical latency.

### 36.2 Disallowed analytics

- Word text.
- Meaning.
- Personal note.
- Typed answer.
- Assistant explanation content.
- Audio content.

### 36.3 Response time

If measured:

- Keep local or aggregate.
- Do not use as a ranking metric.
- Do not present as evidence that slower recall is failure.

---

## 37. State model

Illustrative session state:

```swift
@MainActor
@Observable
final class ReviewFeature {
    enum Phase {
        case preparing
        case prompt
        case answer
        case recording
        case paused
        case completing
        case completed(ReviewSummary)
        case failed(ReviewError)
    }

    private(set) var phase: Phase = .preparing
    private(set) var session: ReviewSession
    private(set) var currentCard: ReviewCard?
    private(set) var progress: ReviewProgress
    private(set) var pendingEventCount = 0

    func reveal()
    func grade(_ grade: ReviewGrade) async
    func playPronunciation() async
    func pause()
    func resume() async
    func endSession() async
}
```

### 37.1 State invariants

- One current card at most.
- Grade is accepted only in answer state.
- Recording state prevents duplicate grade.
- Completed card has a durable event.
- Queue index advances exactly once per accepted event.
- Pause preserves a valid recoverable snapshot.

---

## 38. Application use cases

Required use cases:

```text
LoadReviewOverview
CreateReviewSession
ResumeReviewSession
RevealReviewAnswer
SubmitReviewGrade
PauseReviewSession
EndReviewSession
CompleteReviewSession
ReconcilePendingReviewEvents
LoadReviewSummary
```

### 38.1 Submit grade flow

```text
UI grade action
→ Validate state
→ Create stable ReviewEvent
→ Persist event and session progress transactionally
→ Update predicted local state
→ Advance UI
→ Enqueue or perform remote submission
→ Reconcile authoritative state
```

---

## 39. Backend requirements

The robust review experience may require:

- Stable user-card IDs.
- Due-card endpoint.
- Review submission endpoint.
- Client operation ID.
- Idempotent event acceptance.
- Authoritative updated study state.
- Incremental study-state synchronization.
- Event ordering behavior.
- Conflict response semantics.
- Optional interval previews.
- Soft-deleted-card handling.

### 39.1 Recommended response

A successful review response should include:

- Accepted operation ID.
- User-card ID.
- Authoritative study state.
- Next due timestamp.
- Server event timestamp.
- Version or revision.

### 39.2 Duplicate operation response

Submitting an already accepted operation ID should:

- Return the prior accepted result.
- Not create another review.
- Not change schedule again.

---

## 40. Testing strategy

### 40.1 Domain tests

- Grade mapping.
- Session queue.
- Stable operation IDs.
- Session completion.
- Invalid-card removal.

### 40.2 Use-case tests

- Create session.
- Submit one grade.
- Reject double grade.
- Pause and resume.
- End early.
- Recover after interruption.
- Reconcile offline events.

### 40.3 Persistence tests

- Grade and session progress transaction.
- Pending events survive restart.
- Duplicate operation ID is not inserted twice.
- Corrupt snapshot recovery.

### 40.4 Networking tests

- Successful submission.
- Timeout before server acceptance.
- Timeout after server acceptance.
- Duplicate retry.
- Authentication refresh.
- Conflict response.

### 40.5 UI tests

- Start session.
- Reveal with Space.
- Grade with keys 1–4.
- Play pronunciation.
- Pause.
- Resume.
- Complete.
- Verify summary.

### 40.6 Accessibility tests

- VoiceOver labels.
- Keyboard-only completion.
- Larger text.
- Increased Contrast.
- Reduce Motion.

### 40.7 Offline tests

- Start from cached due state.
- Grade all cards offline.
- Restart.
- Resume.
- Reconnect.
- Verify exactly-once remote results.

---

## 41. Requirement traceability

### `REV-001` — Due queue

Covered by:

- Eligibility.
- Session setup.
- Stable queue.
- Offline prerequisites.

### `REV-002` — Reveal answer

Covered by:

- Prompt state.
- Reveal behavior.
- Accessibility announcement.

### `REV-003` — FSRS grading

Covered by:

- Four grades.
- Submission lock.
- Review-event contract.
- Idempotency.

### `REV-004` — Pronunciation

Covered by:

- Manual audio.
- Auto-play.
- Playback coordination.
- Audio failure.

### `REV-005` — Session progress

Covered by:

- Progress count.
- Progress bar.
- Separate sync status.

### `REV-006` — Pause and resume

Covered by:

- Pause triggers.
- Snapshot.
- Resume validation.
- Recovery.

### `REV-007` — Focus mode

Covered by:

- Dedicated Review window.
- Full screen.
- No sidebar.

### `REV-008` — Review modes

Covered by:

- Recognition.
- Type-in.
- Listening.

### `REV-009` — Session summary

Covered by:

- Required summary.
- Partial session.
- Pending synchronization.
- Next actions.

---

## 42. Acceptance scenarios

### Scenario A — Keyboard-only review

1. Open Review.
2. Start a session.
3. Reveal using Space.
4. Grade using 1.
5. Repeat with 2, 3, and 4.
6. Complete session.
7. Open summary.

Expected:

- No pointer is required.
- No duplicate grade occurs.
- Focus remains logical.

### Scenario B — Rapid repeated key input

1. Reveal answer.
2. Press key 3 multiple times rapidly.

Expected:

- One review event is created.
- One card advancement occurs.

### Scenario C — Network loss after grade

1. Reveal and grade.
2. Disconnect after local persistence.
3. Continue reviewing.
4. Reconnect.

Expected:

- Session continues.
- Events synchronize.
- No duplicate backend reviews occur.

### Scenario D — Application termination

1. Complete several cards.
2. Terminate during the next prompt.
3. Relaunch.
4. Resume.

Expected:

- Completed grades remain.
- Current ungraded card remains available.
- No accepted event repeats.

### Scenario E — Ambiguous submission

1. Submit a grade.
2. Server accepts it.
3. Connection drops before response.
4. Retry with the same operation ID.

Expected:

- Server returns prior accepted result.
- Schedule changes once.

### Scenario F — Audio failure

1. Begin Listening mode.
2. Simulate failed audio.

Expected:

- Retry is available.
- User can skip or switch mode.
- No grade is forced.

### Scenario G — Chinese card

1. Start Chinese review.
2. View Hanzi prompt.
3. Reveal pinyin and Vietnamese meaning.
4. Play Mandarin audio.
5. Grade.

Expected:

- Correct Chinese hierarchy.
- Correct voice.
- Stable keyboard behavior.

### Scenario H — Edit current card

1. Reveal a card.
2. Open Edit.
3. Update note or allowed content.
4. Save.
5. Return to review.

Expected:

- Card state is preserved.
- No grade is submitted.
- Updated content appears.

### Scenario I — End early

1. Review five cards of twenty.
2. Pause.
3. End Session.

Expected:

- Five grades remain.
- Fifteen cards return to due calculation.
- Summary is labeled partial.

### Scenario J — VoiceOver

1. Start Review with VoiceOver.
2. Read prompt.
3. Reveal.
4. Navigate answer.
5. Grade as Good.

Expected:

- Answer state is announced.
- Grade label and shortcut are clear.
- Focus advances correctly.

---

## 43. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Recognition is the default review mode.
2. Full review uses a dedicated focus window.
3. Grades are disabled before answer reveal.
4. Number keys 1–4 map consistently to Again, Hard, Good, and Easy.
5. Accepted grade events are persisted before UI advancement.
6. Full offline review requires backend idempotency support.
7. Practice does not modify FSRS state unless an explicit review grade occurs.
8. Ending a session preserves completed grades.
9. Only one full active review session exists per account.
10. Review progress and synchronization progress are presented separately.
11. Grade colors always include labels and numbers.
12. AI assistance never selects a grade automatically.

---

## 44. Open questions

1. Does the existing backend accept an idempotency key for review events?
2. Is FSRS scheduling calculated exclusively by the server?
3. Can the client calculate reliable interval previews?
4. How fresh must cached study state be to begin an offline session?
5. Should sessions mix English and Chinese by default?
6. Should recognition direction be fixed, alternating, or configurable?
7. Should type-in mode accept synonyms?
8. Should response time appear in the summary?
9. Should grade undo be supported?
10. Should closing the Review window always pause without confirmation?
11. Should active sessions expire after a defined period?
12. Should Difficult Words targeted review modify FSRS state?
13. Should Mini Review share an existing full session or create its own limited session?
14. Should a notification open setup or start immediately?
15. Should user notes appear in answers by default?
16. Should examples be hidden until after grade to reduce cues?
17. What happens when another device reviews the same card during an offline session?
18. Which audio source is required for reliable offline Listening mode?

---

## 45. Definition of done

Review is complete for the first public release when:

- Due-card overview is correct.
- Sessions have stable identity and queue state.
- Reveal and four grades work by keyboard and pointer.
- Each accepted grade creates one durable event.
- Duplicate input cannot create duplicate review events.
- Pause, close, relaunch, and resume are safe.
- English and Chinese cards render correctly.
- Pronunciation is reliable and nonblocking.
- Session summary is useful.
- VoiceOver and larger-text workflows pass.
- Offline behavior matches the documented capability.
- Backend idempotency is verified before offline review is enabled.
- Critical domain, integration, and UI tests pass.
- The iOS and macOS applications use compatible review semantics.

---

## 46. Next document

The next document should be:

```text
docs/macos-today.md
```

It should define:

- Daily dashboard hierarchy.
- Due-card summary.
- Daily goal.
- Streak.
- Continue session.
- Difficult words.
- Suggested practice.
- Recent vocabulary.
- Weekly summary.
- English and Chinese progress.
- Empty and completed-day states.
- Offline behavior.
- Recommendation rules.
- Accessibility.
- Acceptance criteria mapped to `TODAY-*`.
