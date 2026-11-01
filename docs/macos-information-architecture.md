# Voca for macOS — Information Architecture

> Navigation, window model, sidebar hierarchy, selection, routes, deep links, restoration, and responsive behavior for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Information Architecture Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how users understand, navigate, and move between the major areas of Voca for macOS.

It specifies:

- Application scenes and window types.
- Main navigation hierarchy.
- Sidebar organization.
- Content and inspector ownership.
- Route and deep-link model.
- Selection behavior.
- Search and filtering scope.
- Window-size adaptation.
- State restoration.
- Navigation rules for Quick Lookup, menu bar, Spotlight, widgets, notifications, Services, and Shortcuts.

This document defines **where features live and how users reach them**. It does not define implementation modules or visual styling in detail.

---

## 2. Information architecture principles

### IA-PRN-001 — Today answers “What should I do now?”

Today must prioritize the next useful learning action rather than duplicate all available statistics.

### IA-PRN-002 — Vocabulary is the primary content workspace

Vocabulary is where users search, browse, organize, inspect, edit, and compare saved words.

### IA-PRN-003 — Review is a task mode

Review has a clear start, active session, paused state, and completion state. It should not behave like an ordinary list page.

### IA-PRN-004 — Inspector preserves context

Secondary details and contextual actions should appear in an inspector when doing so allows the user to remain in the current collection.

### IA-PRN-005 — Destinations and documents are different

Primary destinations such as Today and Vocabulary belong in the main window. Individual words, imports, or focused sessions may open as documents or secondary windows.

### IA-PRN-006 — Every external entry point resolves to a canonical route

Quick Lookup, Spotlight, Shortcuts, widgets, notifications, Services, and URLs must resolve through the same route model as internal navigation.

### IA-PRN-007 — Window state belongs to the window

Each window owns its:

- Selected destination.
- Navigation path.
- Selected vocabulary item.
- Search query.
- Filters.
- Sort order.
- Layout mode.
- Sidebar visibility.
- Inspector visibility.

Global account, sync, and user settings remain application-level state.

### IA-PRN-008 — The interface must survive narrow widths

The application must remain understandable when columns collapse. Features must not depend on all three columns being visible simultaneously.

---

## 3. Application scene model

Voca uses multiple scene types, each with a specific purpose.

```text
Voca Application
├── Authentication Scene
├── Main Workspace Window Group
├── Word Window Group
├── Review Window
├── Quick Lookup Panel
├── Menu Bar Extra
├── Import Window
├── Activity Window
└── Settings Scene
```

### 3.1 Authentication scene

The authentication scene appears when no valid account session exists.

It owns:

- Sign in.
- Registration when available.
- Password recovery entry point if supported.
- Server configuration in development or advanced mode.
- Authentication errors.

It must not expose authenticated workspace content behind a dismissible sheet.

After successful authentication:

1. Initial account state is loaded.
2. The main workspace opens.
3. Authentication UI is removed.
4. Background synchronization continues without blocking basic local content.

### 3.2 Main workspace window group

The main workspace is the primary application surface.

It contains:

- Sidebar.
- Primary content.
- Optional detail column.
- Optional inspector.
- Toolbar.
- Window-specific navigation state.

Users may open more than one workspace window in a later milestone. The first release may limit the application to one main workspace if multi-window state would delay the foundation.

### 3.3 Word window group

An individual vocabulary item may be opened in a separate window.

Use cases:

- Comparing multiple words.
- Keeping a word visible while reading.
- Viewing extensive Hanzi information.
- Separating research from library navigation.

Identity:

```text
wordWindow(userCardID)
```

Opening the same word window again should focus the existing window unless the product explicitly supports duplicate instances.

### 3.4 Review window

Review can occur:

- Inside the main workspace.
- In a dedicated Focus Review window.

The dedicated window is preferred for full review sessions because it:

- Removes unrelated navigation.
- Supports task-focused sizing.
- Can enter full screen independently.
- Keeps the main workspace state intact.

Only one active full review session should exist per account unless the review domain explicitly supports concurrent sessions.

### 3.5 Quick Lookup panel

Quick Lookup is an ambient utility surface.

Properties:

- Invoked globally.
- Appears above the active application.
- Does not become a permanent primary workspace.
- Supports lookup, pronunciation, save, AI explanation, and opening full detail.
- Dismisses predictably with Escape, outside click, or successful navigation according to detailed behavior.

Quick Lookup has its own transient state:

- Query.
- Detected language.
- Lookup result.
- Save state.
- Error state.

It must not overwrite the main workspace's search or selection.

### 3.6 Menu bar extra

The menu bar extra is an optional lightweight companion.

It contains:

- Due status.
- Quick Lookup entry.
- Quick Add.
- Mini Review.
- Word of the day.
- Sync state.
- Open Voca.

It must not become a reduced copy of the entire application.

### 3.7 Import window

Imports and document extraction use a dedicated window when the workflow is too complex for a sheet.

It contains:

1. Source selection.
2. Extraction or parsing.
3. Column or language configuration.
4. Candidate preview.
5. Duplicate resolution.
6. Confirmation.
7. Completion summary.

The import workflow must preserve progress when the main workspace selection changes.

### 3.8 Activity window

Activity provides operational transparency for:

- Synchronization.
- Offline mutation queue.
- Import jobs.
- OCR jobs.
- AI generation jobs where useful.
- Recoverable errors.

Routine successful operations should not create permanent clutter.

### 3.9 Settings scene

Settings uses the standard macOS Settings scene.

Top-level tabs:

- General.
- Study.
- Speech.
- AI.
- Integrations.
- Account.
- Storage and Diagnostics.
- Advanced.

Settings is global to the signed-in account and application unless a setting is explicitly device-specific.

---

## 4. Main workspace structure

### 4.1 Expanded layout

The preferred large-window structure is:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Toolbar                                                              │
├──────────────────┬───────────────────────────────┬───────────────────┤
│ Sidebar          │ Primary Content               │ Detail            │
│                  │                               │                   │
│ Navigation       │ Dashboard, table, list,       │ Selected word,    │
│ collections,     │ review setup, practice,       │ conversation, or  │
│ smart lists      │ assistant, or insights        │ contextual task   │
│                  │                               │                   │
│                  │                               ├───────────────────┤
│                  │                               │ Inspector         │
└──────────────────┴───────────────────────────────┴───────────────────┘
```

Not every destination uses all regions.

### 4.2 Column semantics

#### Sidebar

Owns high-level destination and collection selection.

#### Primary content

Owns the main task:

- Today dashboard.
- Vocabulary table.
- Review setup.
- Practice library.
- Assistant conversation.
- Insights reports.

#### Detail column

Owns a selected entity or subtask:

- Word detail.
- Practice details.
- Conversation context.
- Insight breakdown.

#### Inspector

Owns secondary metadata and contextual controls:

- Learning state.
- Tags.
- Notes.
- Review history.
- AI context.
- Display options.

The detail column and inspector must not duplicate identical information without a clear reason.

### 4.3 Recommended minimum sizes

Initial design targets:

- **Minimum window width:** 900 points.
- **Comfortable width:** 1200–1440 points.
- **Minimum window height:** 620 points.
- **Sidebar:** 200–280 points.
- **Primary content:** minimum 440 points.
- **Detail:** 320–480 points.
- **Inspector:** 280–360 points where separate.

Exact values belong in the design system and must be validated with accessibility text sizes.

---

## 5. Primary navigation hierarchy

The proposed sidebar hierarchy is:

```text
LEARN
├── Today
├── Review
├── Practice
├── Assistant
└── Conversation

LIBRARY
├── Vocabulary
├── Favorites
├── Recently Added
├── Difficult Words
└── Trash

SMART LISTS
├── User-created list
├── User-created list
└── Add Smart List…

PROGRESS
└── Insights
```

The bottom utility area contains:

```text
ACCOUNT / STATUS
├── Sync status
├── Account
└── Settings
```

### 5.1 Sidebar simplification rule

The sidebar should avoid showing destinations that:

- Have no meaningful content.
- Duplicate another destination.
- Are used rarely and belong in menus.
- Exist only for administrative implementation reasons.

If the sidebar becomes visually crowded:

- Recently Added and Difficult Words may move under Vocabulary.
- Assistant and Conversation may be grouped under Practice.
- Trash may move to a More section.

### 5.2 Sidebar badges

Allowed badges:

- Review due count.
- Recoverable sync problem.
- Optional unfinished activity.

Avoid badges for:

- Marketing.
- AI suggestions.
- Routine completed synchronization.
- Every new vocabulary word.

---

## 6. Destination specifications

## 6.1 Today

### Route

```text
/today
```

### Purpose

Present the highest-value daily learning actions.

### Primary content

- Due review summary.
- Daily goal.
- Start Review.
- Continue active session.
- Difficult words.
- Suggested practice.
- Recent vocabulary.
- Weekly summary.

### Detail behavior

Today normally uses a single broad content area.

Selecting a difficult or recent word may:

- Open the inspector.
- Navigate to Vocabulary with the word selected.
- Open a separate word window, depending on the action.

### Toolbar

- Language context.
- Start Review.
- Quick Add.
- Refresh or sync state.

### Empty states

- No vocabulary.
- No due cards.
- Daily goal complete.
- Offline without local data.

## 6.2 Vocabulary

### Canonical route

```text
/vocabulary
```

### Collection routes

```text
/vocabulary/all
/vocabulary/favorites
/vocabulary/recent
/vocabulary/difficult
/vocabulary/due
/vocabulary/trash
/vocabulary/smart/{smartListID}
```

### Entity route

```text
/vocabulary/word/{userCardID}
```

### Preferred layout

```text
Sidebar collection → Table/list/grid → Word detail → Optional inspector
```

### Primary content state

- Collection identity.
- Search query.
- Filters.
- Sort descriptors.
- Layout mode.
- Selection.
- Column visibility.
- Scroll position where feasible.

### Selection

- Zero selection: show collection summary or instruction.
- One selection: show word detail.
- Multiple selection: show batch-action summary.

### Toolbar

- Search.
- Language selector.
- Filter.
- Sort.
- Layout picker.
- Add Word.
- Import.
- Toggle inspector.

## 6.3 Review

### Routes

```text
/review
/review/setup
/review/session/{sessionID}
/review/summary/{sessionID}
```

### States

```text
Unavailable
Ready
Configuring
Active
Paused
Submitting
Completed
Recoverable Error
```

### Navigation rules

- Entering `/review` shows due summary and setup.
- Starting a session opens the active review route.
- An active session cannot be replaced silently.
- Navigating away prompts only if unsaved or invalid state would be lost.
- Completing a session leads to summary.

### Focus window option

The active session may move into a dedicated window while the main workspace remains on `/review`.

## 6.4 Practice

### Routes

```text
/practice
/practice/drills
/practice/reading
/practice/listening
/practice/writing
/practice/session/{sessionID}
```

### Primary content

- Practice-type selection.
- Context selection.
- Difficulty.
- Vocabulary source.
- Recent sessions.

### Detail content

- Selected practice configuration.
- Active generated exercise.
- Results.

## 6.5 Assistant

### Routes

```text
/assistant
/assistant/conversation/{conversationID}
```

### Layout

```text
Conversation list → Conversation → Context inspector
```

### Context inspector

Shows:

- Selected words.
- Active Smart List.
- Imported text.
- Language.
- Level.
- Prompt mode.
- Provider and model where useful.

### Navigation rule

Opening Assistant from a word creates or activates a context containing that word. It must not silently add unrelated previously selected vocabulary.

## 6.6 Conversation

### Routes

```text
/conversation
/conversation/setup
/conversation/session/{sessionID}
/conversation/summary/{sessionID}
```

### Primary content

- Scenario.
- Role.
- Target language.
- Target vocabulary.
- Conversation history.

### Session states

- Setup.
- Waiting for user.
- Generating.
- Playing speech.
- Paused.
- Completed.

## 6.7 Insights

### Routes

```text
/insights
/insights/retention
/insights/activity
/insights/growth
/insights/forecast
/insights/difficult
/insights/listening
```

### Layout

Insights uses:

- Report navigation.
- Date-range controls.
- Language filter.
- Main chart or summary.
- Supporting textual and tabular detail.

Selecting a data point may navigate to a filtered Vocabulary collection.

---

## 7. Vocabulary information model

The macOS information architecture distinguishes these concepts:

### 7.1 Dictionary content

Shared or generated linguistic information:

- Canonical word.
- Language.
- Pronunciation or pinyin.
- Meanings.
- Examples.
- Collocations.
- Related words.
- Hanzi data.

### 7.2 User vocabulary state

User-specific information:

- Learning level.
- Favorite state.
- Tags.
- Topic.
- Notes.
- Creation date.
- Review history.
- FSRS state.
- Next review.

### 7.3 Collection

A set of user vocabulary defined by:

- System rule.
- Saved query.
- Import batch.
- Manual organization if later supported.

### 7.4 Search result

A transient filtered projection, not a duplicated collection.

### 7.5 Lookup result

A word found through lookup that may or may not already exist in the user's vocabulary.

The UI must clearly distinguish:

```text
Dictionary result ≠ Saved user card
```

Saving creates or links user vocabulary state rather than unnecessarily duplicating shared dictionary content.

---

## 8. Word detail information hierarchy

Word detail should follow a stable hierarchy across the inspector, detail column, word window, and Quick Lookup.

### Level 1 — Identity

- Word or Hanzi.
- Pronunciation or pinyin.
- Language.
- Audio action.
- Favorite state.

### Level 2 — Immediate understanding

- Concise meaning.
- Primary example.
- Learning level.

### Level 3 — Extended language content

- Additional meanings.
- Additional examples.
- Collocations.
- Synonyms.
- Antonyms.
- Related words.

### Level 4 — Personal learning data

- Tags.
- Topic.
- Notes.
- FSRS state.
- Next review.
- Review history.

### Level 5 — Learning actions

- Ask AI.
- Compare.
- Generate examples.
- Start focused practice.
- Edit.
- Delete.

### Chinese extension

- Character breakdown.
- Stroke order.
- Writing practice.
- Mandarin pronunciation.

Quick Lookup generally shows Levels 1 and 2. The inspector shows Levels 1, 2, 4, and selected actions. The full word view may show all levels.

---

## 9. Inspector ownership

### 9.1 General rule

The inspector contains contextual information about the current selection or task, not primary navigation.

### 9.2 Destination ownership

#### Today

Usually no persistent inspector.

#### Vocabulary

Inspector may show:

- Learning metadata.
- Tags.
- Notes.
- Review history.
- Secondary actions.

#### Review setup

Inspector may show:

- Session settings.
- Selected collection.
- Audio behavior.

#### Active review

No standard inspector in Focus mode.

#### Practice

Inspector may show:

- Target vocabulary.
- Difficulty.
- Generation context.

#### Assistant

Inspector shows active context.

#### Insights

Inspector may show:

- Metric definition.
- Filters.
- Selected data-point detail.

### 9.3 Multi-selection inspector

When multiple vocabulary rows are selected, the inspector changes to batch mode.

It may show:

- Number selected.
- Shared language where consistent.
- Common tags.
- Add or remove tags.
- Favorite action.
- Export.
- Delete.

It must not display one arbitrary selected word as if it were the only selection.

---

## 10. Selection model

### 10.1 Selection identity

Selections use stable domain identifiers rather than table indexes.

Example:

```text
Set<UserCardID>
```

This prevents incorrect selection when:

- Sorting changes.
- Filtering changes.
- Synchronization inserts data.
- Rows are refreshed.

### 10.2 Selection persistence

Selection should be preserved when:

- Changing sort.
- Editing the selected word.
- Refreshing data.
- Showing or hiding the inspector.

Selection may be cleared when:

- Switching to an unrelated collection where the word is absent.
- Changing account.
- Deleting the selected item permanently.
- Applying a filter that excludes it.

### 10.3 Search selection behavior

If a selected item remains in results, keep it selected.

If it leaves the result set:

- Clear detail.
- Do not automatically select the first result unless explicitly designed.
- Preserve keyboard focus in the search field.

### 10.4 Multi-selection and navigation

Opening a word from multi-selection should:

- Use the focused row when one exists.
- Avoid destroying the original multi-selection unless the user explicitly navigates.

---

## 11. Search architecture

Voca has several search scopes.

### 11.1 Collection search

Used inside Vocabulary.

Scope:

- Current collection.
- Current language filter.
- Active structured filters.

Shortcut:

```text
Command + F
```

### 11.2 Global application search

Searches across:

- Saved vocabulary.
- Smart Lists.
- Features and commands where useful.
- Recent conversations if enabled.

Shortcut:

```text
Shift + Command + F
```

Global search results are grouped by content type.

### 11.3 Quick Lookup

Searches:

1. Saved local vocabulary.
2. Cached dictionary content.
3. Remote dictionary or generation services.

It is optimized for rapid understanding and saving, not library management.

### 11.4 Command Palette

Searches actions and navigation destinations, not vocabulary content by default.

Shortcut:

```text
Command + K
```

### 11.5 Spotlight

Searches the system index and deep-links to the relevant Voca entity.

### 11.6 Search query state

Each workspace window owns its search query.

Quick Lookup, Spotlight, and the Command Palette have independent transient queries.

---

## 12. Filter architecture

### 12.1 Filter categories

Vocabulary filters may include:

- Language.
- Level.
- Due state.
- Favorite state.
- Tags.
- Topics.
- Created date.
- Last reviewed date.
- Has notes.
- Has audio.
- Difficulty or lapse state.

### 12.2 Filter presentation

Filters use:

- Toolbar filter button.
- Popover or inspector for detailed controls.
- Visible filter tokens or summary.
- Clear All action.

### 12.3 Filter URL representation

Temporary filters do not need to appear fully in public deep links.

Saved Smart Lists use stable identifiers:

```text
voca://vocabulary/smart/{smartListID}
```

### 12.4 Empty filtered state

The empty state must distinguish:

- No vocabulary exists.
- No items match search.
- No items match filters.
- Content is unavailable offline.

---

## 13. Toolbar architecture

### 13.1 Persistent leading controls

Where appropriate:

- Toggle sidebar.
- Back and forward navigation.
- Destination title.

### 13.2 Persistent trailing controls

Where appropriate:

- Sync state.
- Toggle inspector.
- Primary create action.

### 13.3 Destination-specific controls

#### Today

- Start Review.
- Language.

#### Vocabulary

- Search.
- Filter.
- Sort.
- Layout mode.
- Add Word.

#### Review

- Session configuration.
- Audio.
- Focus mode.

#### Practice

- New Practice.
- Context.
- Difficulty.

#### Assistant

- New Conversation.
- Context inspector.
- Stop generation.

#### Insights

- Date range.
- Language.
- Export report if later supported.

### 13.4 Toolbar overflow

At narrower widths:

1. Keep destination title.
2. Keep the primary action.
3. Keep search when central to the destination.
4. Move secondary actions into overflow.
5. Never hide an active-state indicator without an alternative.

---

## 14. Command routing

Commands resolve against the active context.

### 14.1 Command priority

When a command is invoked:

1. Active modal or sheet.
2. Active focused control.
3. Active detail or session.
4. Active destination.
5. Active window.
6. Application-level fallback.

### 14.2 Examples

#### Delete

- Text field focused: delete text.
- Vocabulary selection active: delete selected cards.
- Smart List focused: delete Smart List after confirmation.
- No valid selection: disabled.

#### Play Pronunciation

- Active review card: play review pronunciation.
- Selected vocabulary word: play selected word.
- Quick Lookup result: play lookup result.
- Otherwise: disabled.

#### Add Word

- Always opens Quick Add or Add Word.
- If relevant text is selected in-app, prefill but do not save automatically.

### 14.3 Destructive commands

Destructive commands must display:

- The affected object.
- The number of affected items.
- Whether recovery is possible.

---

## 15. Route model

The conceptual route model should support internal navigation and external deep links.

Illustrative Swift route definitions:

```swift
enum AppRoute: Hashable, Codable {
    case today
    case vocabulary(VocabularyRoute)
    case review(ReviewRoute)
    case practice(PracticeRoute)
    case assistant(AssistantRoute)
    case conversation(ConversationRoute)
    case insights(InsightsRoute)
    case activity
}

enum VocabularyRoute: Hashable, Codable {
    case collection(VocabularyCollection)
    case word(UserCardID)
    case add(prefill: String?)
    case importFlow
}

enum VocabularyCollection: Hashable, Codable {
    case all
    case favorites
    case recent
    case difficult
    case due
    case trash
    case smartList(SmartListID)
}

enum ReviewRoute: Hashable, Codable {
    case overview
    case setup
    case session(ReviewSessionID)
    case summary(ReviewSessionID)
}
```

The final implementation may differ, but it must preserve:

- Stable typed identities.
- Codable restoration where safe.
- Separation between destination and entity.
- Explicit handling of unavailable routes.

---

## 16. Deep-link model

### 16.1 URL scheme

Proposed internal URL scheme:

```text
voca://today
voca://vocabulary
voca://vocabulary/word/{userCardID}
voca://vocabulary/favorites
voca://vocabulary/smart/{smartListID}
voca://review
voca://review/start
voca://practice/reading
voca://assistant
voca://insights/retention
voca://quick-lookup?query={encodedQuery}
```

### 16.2 Universal links

If server-backed web links are introduced, they should map to the same canonical route model:

```text
https://voca.thaonv.online/app/word/{userCardID}
```

Universal links must not expose secret identifiers or authentication tokens.

### 16.3 Deep-link resolution

Resolution sequence:

1. Parse and validate route.
2. Check authentication.
3. Check account ownership.
4. Load local entity if available.
5. Fetch remotely if required.
6. Open the most suitable existing window.
7. Navigate to destination and selection.
8. Present an actionable unavailable state if resolution fails.

### 16.4 Unknown or stale entities

If a linked entity is:

- Deleted.
- Owned by another account.
- Not synchronized.
- Invalid.

Then Voca must:

- Avoid crashing.
- Avoid showing another entity.
- Explain that the item is unavailable.
- Offer navigation to the relevant collection.

---

## 17. External entry-point routing

### 17.1 Spotlight

```text
Spotlight result
→ Activate or open main workspace
→ Navigate to Vocabulary
→ Select exact word
→ Reveal detail
```

If the user requests a separate window:

```text
Spotlight result
→ Open word window
```

The first release should choose one consistent default.

### 17.2 Widget

Examples:

```text
Due widget
→ /review

Word-of-the-day widget
→ /vocabulary/word/{userCardID}

Goal widget
→ /today
```

### 17.3 Notification

```text
Review reminder
→ /review

Sync action required
→ /activity

Practice recommendation
→ appropriate /practice route
```

### 17.4 App Intent

An intent may:

- Complete without opening the application.
- Return a value to Shortcuts.
- Open a canonical route when user interaction is needed.

### 17.5 macOS Service

```text
Selected text
→ Validate selection
→ Open Quick Lookup or Add Word
→ Prefill text
→ Require explicit save
```

### 17.6 Menu bar

```text
Open Voca
→ Restore last main workspace state

Start Review
→ /review or active review window

Open Word
→ /vocabulary/word/{userCardID}
```

---

## 18. Back and forward navigation

### 18.1 Supported contexts

Back and forward navigation is useful for:

- Vocabulary collection to word detail.
- Insight report to filtered collection.
- Assistant references to word detail.
- Practice result to source vocabulary.

### 18.2 History model

History entries should capture:

- Route.
- Entity identifier.
- Collection context.
- Search and filter state where necessary.

History should not capture:

- Every keystroke.
- Every review card.
- Temporary popover state.
- Routine inspector tab changes unless materially navigational.

### 18.3 Review exception

Back navigation must not move through individual review cards.

Review cards are session state, not application navigation history.

---

## 19. Responsive window behavior

### 19.1 Expanded state

Available at comfortable width:

- Sidebar visible.
- Primary content visible.
- Detail visible.
- Inspector optional.

### 19.2 Standard state

At moderate width:

- Sidebar visible or collapsible.
- Primary content visible.
- Detail visible.
- Inspector overlays or replaces a secondary region.

### 19.3 Compact desktop state

At narrow supported width:

- Sidebar collapses.
- Primary content occupies the window.
- Word detail becomes navigation or a sheet-like presentation.
- Inspector becomes an overlay.
- Toolbar moves secondary actions to overflow.

### 19.4 Forbidden behavior

Do not:

- Shrink text below the design system minimum.
- Compress all controls into an unreadable toolbar.
- Require horizontal scrolling for primary navigation.
- Display an unusably narrow table and inspector simultaneously.
- Hide destructive-action context.

---

## 20. State restoration

### 20.1 Restorable window state

The main workspace may restore:

- Window frame.
- Sidebar visibility.
- Inspector visibility.
- Selected primary destination.
- Selected collection.
- Vocabulary layout mode.
- Sort order.
- Table-column visibility and widths.
- Non-sensitive search and filter state.

### 20.2 Conditionally restorable state

Restore only after validation:

- Selected word.
- Smart List.
- Assistant conversation.
- Practice session.
- Review session.

### 20.3 Non-restorable state

Do not persist:

- Passwords.
- Raw provider secrets.
- Temporary AI request bodies.
- Clipboard content.
- Transient popovers.
- Unconfirmed destructive dialogs.

### 20.4 Active review restoration

If an active review session existed:

1. Validate account.
2. Validate session and pending grades.
3. Offer Resume or Discard.
4. Do not submit a grade merely because the app restored.

---

## 21. Modal presentation rules

Use a sheet when:

- The task is dependent on its parent window.
- The task is short.
- The task should block the parent context.

Examples:

- Confirm deletion.
- Edit a small set of word fields.
- Configure a simple review.

Use a separate window when:

- The task is long-running.
- The task benefits from resizing.
- The parent workspace should remain usable.
- The task contains multiple steps.

Examples:

- Import.
- Document extraction.
- Activity.
- Full word window.
- Focus Review.

Use a popover when:

- The interaction is lightweight.
- It is anchored to a clear control.
- It contains no complex multi-step process.

Examples:

- Filter controls.
- Sort options.
- Compact account menu.

---

## 22. Empty, loading, and error states

### 22.1 Loading

Prefer:

- Existing local content with a subtle refresh state.
- Skeletons only where structure is stable.
- Progress indicators for user-started long operations.

Avoid replacing the whole workspace with a spinner during routine synchronization.

### 22.2 Empty library

Offer:

- Add first word.
- Import vocabulary.
- Try Quick Lookup.
- Learn how reviews work.

### 22.3 Empty filtered result

Offer:

- Clear search.
- Clear filters.
- Edit active Smart List.

Do not show first-run onboarding.

### 22.4 Offline

If local data exists:

- Show local content.
- Indicate offline state.
- Queue supported changes.

If no local data exists:

- Explain why content is unavailable.
- Offer retry.
- Preserve navigation context.

### 22.5 Error recovery

Errors should appear near the affected scope:

- Row or field validation inline.
- Destination load error in content.
- Sync issue in status and Activity.
- Global account failure at application level.

---

## 23. Focus and keyboard navigation

### 23.1 Default focus

#### Today

Primary Start Review action or content area, depending on accessibility behavior.

#### Vocabulary

Table or search, based on entry route.

#### Quick Lookup

Search field.

#### Review

Review card content before reveal, grading controls after reveal.

#### Assistant

Message field for a new empty conversation; conversation content for an existing one.

### 23.2 Focus restoration

After dismissing:

- A sheet returns focus to the invoking control.
- A popover returns focus to its anchor.
- Word detail returns focus to the originating row.
- Quick Lookup returns focus to the previously active application where possible.

### 23.3 Full keyboard route

A user must be able to:

1. Open Vocabulary.
2. Focus search.
3. Enter a query.
4. Move through results.
5. Open word detail.
6. Play pronunciation.
7. Edit or tag the word.
8. Return to the result list.

No pointer-only step is acceptable in this primary workflow.

---

## 24. Accessibility semantics

### 24.1 Regions

Major regions should expose understandable labels:

- Sidebar.
- Vocabulary results.
- Word detail.
- Inspector.
- Review card.
- Assistant conversation.
- Assistant context.

### 24.2 Sidebar

Sidebar groups must have meaningful names. Badges should announce their meaning, not only a number.

Example:

```text
Review, 24 cards due
```

### 24.3 Vocabulary table

VoiceOver should identify:

- Column name.
- Row position where useful.
- Selected state.
- Favorite state.
- Due state.

### 24.4 Detail updates

Selecting a word should not unexpectedly move VoiceOver focus unless the user invokes Open Detail.

### 24.5 Review

Reveal and grading state changes should be announced without reading the entire window repeatedly.

---

## 25. Navigation analytics

If product analytics are used, collect route-level events without capturing sensitive content.

Allowed examples:

- Destination opened.
- Review started.
- Review completed.
- Quick Lookup opened.
- Import started.
- Import completed.
- Inspector toggled.

Do not collect:

- Search query content.
- Clipboard content.
- Word notes.
- AI prompt text.
- Document text.
- Conversation messages.

---

## 26. Requirement traceability

This architecture supports the following Product Requirements groups:

- `APP-*`: scene, window, menu, and restoration model.
- `TODAY-*`: Today destination.
- `VOC-*`: collections, table, search, filters, selection, and detail.
- `LANG-*`: language-aware vocabulary routes and detail.
- `REV-*`: review state and dedicated focus window.
- `QUICK-*`: Quick Lookup panel and external routing.
- `MENU-*`: menu bar entry routes.
- `AI-*`: assistant context and conversation routes.
- `CAP-*`: import and capture window.
- `SYS-*`: Spotlight, intents, widgets, and notification routes.
- `INS-*`: report navigation and filtered collection transitions.
- `SET-*`: standard Settings scene.
- `SYNC-*`: Activity and sync-status presentation.
- `A11Y-*`: focus, region, keyboard, and responsive behavior.

---

## 27. Decisions proposed by this document

The following decisions should be reviewed and then recorded in `macos-decisions.md`:

1. Use a destination-based sidebar rather than an iOS-style tab bar.
2. Use Vocabulary as a collection-and-selection workspace.
3. Use a dedicated Focus Review window for full study sessions.
4. Keep Quick Lookup state independent from workspace search.
5. Use typed canonical routes for internal and external navigation.
6. Use stable user-card identifiers for selection and deep links.
7. Treat review cards as session state rather than navigation history.
8. Use a dedicated import window for multi-step capture workflows.
9. Keep Activity separate from routine UI notifications.
10. Prefer one canonical word-detail information hierarchy across all surfaces.

---

## 28. Open questions

1. Should Today or Vocabulary be the default initial destination?
2. Should word detail occupy a permanent third column or primarily use an inspector?
3. Should the first release support multiple main workspace windows?
4. Should clicking a Spotlight word open the main workspace or a dedicated word window?
5. Should difficult words be a top-level sidebar item or a Vocabulary subcollection?
6. Should Trash be a sidebar item or only accessible through a menu?
7. Should Assistant and Conversation remain separate top-level destinations?
8. Should Practice own Conversation as a subfeature?
9. Which table-column configuration should be the default for English and Chinese?
10. How long should search and filter state persist after application restart?
11. Should an imported document remain as a temporary source entity after word creation?
12. Should Quick Lookup support browsing multiple dictionary results?
13. Should global search include AI conversations?
14. Should Smart Lists allow nested groups?
15. Which routes should be exposed as public URLs versus internal-only routes?

---

## 29. Validation scenarios

### Scenario A — Narrow-window vocabulary

1. Open Vocabulary.
2. Select a word.
3. Reduce the window to minimum width.
4. Verify sidebar, result list, word detail, and inspector remain reachable.
5. Verify no essential action is clipped.

### Scenario B — Deep link while signed out

1. Invoke a word deep link.
2. Authenticate.
3. Verify Voca resumes the intended route.
4. Verify an invalid or inaccessible word does not expose unrelated content.

### Scenario C — Search during synchronization

1. Search a large vocabulary collection.
2. Trigger synchronization that inserts or updates rows.
3. Verify query and valid selection remain stable.
4. Verify row identity does not shift incorrectly.

### Scenario D — Spotlight to word

1. Search for a saved word in Spotlight.
2. Open the result.
3. Verify Voca activates.
4. Verify the correct account and word are shown.
5. Verify deleted content gives an unavailable state.

### Scenario E — Resume review

1. Begin a review.
2. Complete several cards.
3. Close the review window.
4. Reopen Review.
5. Verify completed grades are not duplicated.
6. Verify remaining cards can be resumed or discarded.

### Scenario F — Multi-selection

1. Select multiple vocabulary rows.
2. Apply a tag.
3. Change sorting.
4. Verify selection remains associated with the correct identifiers.
5. Delete one selected item remotely through synchronization.
6. Verify remaining selection is valid.

---

## 30. Definition of done

The information architecture is considered validated when:

- Every P0 product feature has an owning destination or scene.
- Primary user journeys can be completed without ambiguous navigation.
- External entry points map to canonical routes.
- Selection and restoration rules are defined.
- Expanded and narrow-window behavior is understood.
- Keyboard focus transitions are specified.
- Error and empty states have appropriate ownership.
- Product, design, and engineering agree on the window model.
- Prototype navigation can be implemented without inventing additional top-level concepts.

---

## 31. Next document

The next document should be:

```text
docs/macos-architecture.md
```

It should define:

- Repository and target structure.
- Shared iOS/macOS code strategy.
- Feature and module boundaries.
- State ownership.
- Dependency direction.
- Networking.
- Authentication.
- Persistence abstraction.
- Synchronization boundaries.
- AppKit bridges.
- App Intents and extension boundaries.
- Build configuration.
- Migration plan from the current `ios` directory.
- Testing seams.
