# Voca for macOS — Quick Lookup

> Product, UX, window behavior, lookup pipeline, privacy, accessibility, performance, and acceptance specification for the global Quick Lookup experience.

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
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Primary requirement group:** `QUICK-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the complete Quick Lookup experience for Voca on macOS.

It covers:

- Global keyboard-shortcut invocation.
- Floating-panel behavior.
- Window activation and dismissal.
- Active-screen placement.
- Multiple displays and Spaces.
- Search input.
- Clipboard suggestions.
- Language detection.
- Local and remote lookup.
- Result ranking.
- English and Chinese layouts.
- Pronunciation.
- Saving vocabulary.
- Existing-card behavior.
- Assistant actions.
- Opening full word detail.
- Authentication and signed-out behavior.
- Offline support.
- Privacy.
- Accessibility.
- Performance.
- Error recovery.
- Testing and acceptance criteria.

Quick Lookup is intended to become the signature macOS capability of Voca:

> A learner should be able to understand and save a word within seconds without leaving the application where the word was encountered.

---

## 2. Product intent

Quick Lookup is an ambient utility rather than a smaller copy of the main Voca window.

It should feel:

- Immediate.
- Lightweight.
- Keyboard-first.
- Context-preserving.
- Predictable.
- Private.
- Native to macOS.

The typical interaction is:

```text
Encounter a word
→ Press global shortcut
→ Enter or confirm the word
→ Read concise result
→ Play pronunciation
→ Save if useful
→ Dismiss
→ Continue the original task
```

The panel should not require:

- Opening the main workspace.
- Navigating a sidebar.
- Choosing a dictionary before every search.
- Waiting for AI generation before showing known content.
- Completing a long form before saving.

---

## 3. Product principles

### QUICK-PRN-001 — Opening must feel immediate

The panel must appear independently from network availability or lookup completion.

### QUICK-PRN-002 — Local data appears first

Saved vocabulary and cached dictionary content should appear before remote enrichment.

### QUICK-PRN-003 — One primary result

The default panel should emphasize the most relevant result rather than present a complex search-results page.

### QUICK-PRN-004 — Saving is explicit

Voca may prefill or suggest content, but it does not add a card until the user chooses Add to Voca.

### QUICK-PRN-005 — Clipboard access remains private

Clipboard text is never sent to the network merely because Quick Lookup opened.

### QUICK-PRN-006 — The original workflow retains priority

Quick Lookup should dismiss predictably and return focus to the original application.

### QUICK-PRN-007 — Existing vocabulary is recognized

The panel must distinguish:

```text
Not saved
Already in your vocabulary
Saved locally and waiting to sync
```

### QUICK-PRN-008 — AI is optional enrichment

Known dictionary and saved-card results appear without requiring an AI request.

---

## 4. Scope

### 4.1 Included

- Global shortcut.
- Application command invocation.
- Menu bar invocation.
- Floating search panel.
- Local vocabulary lookup.
- Cached dictionary lookup.
- Remote dictionary lookup.
- English and Chinese.
- Pronunciation.
- Add Word.
- Existing-card state.
- Open full detail.
- Ask Assistant.
- Offline result handling.
- Clipboard suggestions.
- Configurable shortcut.
- Accessibility.
- Multi-display behavior.

### 4.2 Related but specified elsewhere

- Complete Add Word editing flow.
- Full vocabulary detail.
- Assistant conversation behavior.
- Menu bar layout.
- Services and Share Extension.
- Spotlight.
- App Intents.
- Clipboard monitoring outside explicit Quick Lookup use.
- General data synchronization.

### 4.3 Excluded from the first version

- Full vocabulary-table browsing.
- Batch word creation.
- PDF or document extraction.
- Long assistant conversations inside the panel.
- Review sessions.
- Complex tag-management UI.
- Arbitrary browser-extension integration.
- Passive automatic lookup whenever clipboard changes.

---

## 5. Entry points

Quick Lookup may be opened from:

- Global shortcut.
- Voca application menu.
- Menu bar companion.
- Command Palette.
- macOS Service.
- App Intent.
- Deep link.
- Main-window toolbar.

### 5.1 Default global shortcut

Proposed default:

```text
Option + Space
```

The final shortcut must be validated against:

- Spotlight.
- Input methods.
- Accessibility shortcuts.
- Common third-party applications.
- International keyboard layouts.

### 5.2 Application command

Menu location:

```text
Voca
└── Quick Lookup
```

or:

```text
File
└── Quick Lookup
```

The final menu location should follow the role of the command after prototype testing.

### 5.3 Menu bar

Selecting Quick Lookup from the menu bar:

- Closes the menu bar popover.
- Opens the floating panel.
- Focuses search.

### 5.4 macOS Service

Selected text may invoke:

```text
Look Up in Voca
```

The selected text becomes a suggestion or prefilled query.

It is not automatically saved.

### 5.5 Deep link

Proposed:

```text
voca://quick-lookup
voca://quick-lookup?query={encodedQuery}
```

External input must be length-limited and validated.

---

## 6. Window model

### 6.1 Window type

Quick Lookup should use a dedicated macOS floating panel or utility-window implementation.

Desired characteristics:

- Appears above the currently active application.
- Can become key for text entry.
- Does not permanently activate the full main workspace.
- Can dismiss without quitting Voca.
- Supports active-display placement.
- Works when the main Voca window is closed.
- Remains available when menu bar mode is enabled.

### 6.2 Window identity

Only one Quick Lookup panel should exist per running application.

Repeated invocation:

- Brings the existing panel forward.
- Focuses the search field.
- Preserves or resets the query according to the invocation policy.

It must not create multiple stacked panels.

### 6.3 Suggested dimensions

```text
Width             560–640 points
Collapsed height   72–96 points
Result height     260–440 points
Maximum height    520 points
```

The panel may expand vertically after a result appears.

It should not continually resize for minor status changes.

### 6.4 Window chrome

Recommended:

- No standard document toolbar.
- No sidebar.
- Minimal or hidden title.
- Standard system shadow.
- Native material or window background.
- Subtle border where needed for separation.

### 6.5 Key-window behavior

When opened:

- Quick Lookup becomes key.
- The query field becomes first responder.
- The previous active application is remembered for focus restoration.

### 6.6 Main-app activation

Quick Lookup should not unnecessarily bring all Voca windows forward.

Open Detail and advanced actions may activate the main application deliberately.

---

## 7. Positioning

### 7.1 Active display

Open on the display containing:

1. The currently focused window.
2. Otherwise the pointer.
3. Otherwise the main screen.

The final fallback order must be tested with assistive technologies and full-screen apps.

### 7.2 Vertical placement

Recommended:

- Horizontally centered.
- Positioned above vertical center, similar to a search utility.

The result expansion should grow downward when space permits.

### 7.3 Visible frame

The complete panel must remain inside the display's visible frame, excluding:

- Menu bar.
- Dock.
- Reserved system regions.

### 7.4 Multiple displays

Test:

- Displays above and below each other.
- Different scaling.
- Different resolutions.
- Main display changes.
- External display disconnect.

### 7.5 Spaces

Expected behavior:

- Opens in the currently active Space.
- Does not switch to the Space containing the main Voca window.
- Open Detail may activate the main workspace in its existing Space or open a suitable window according to final window policy.

### 7.6 Full-screen applications

Quick Lookup should appear over a full-screen application where macOS permits.

The implementation must avoid:

- Moving the user to another Space merely to show the panel.
- Leaving the panel stranded behind the full-screen application.

---

## 8. Invocation behavior

### 8.1 Fresh invocation

Default:

- Open panel.
- Focus query.
- Show empty or clipboard-suggestion state.

### 8.2 Repeated invocation while open

Recommended:

- Focus query.
- Select query text if the panel has been inactive briefly.
- Do not create another panel.

### 8.3 Query reset policy

Proposed:

- Preserve query while the panel remains open.
- Clear query after dismissal unless the dismissal led to Open Detail.
- Do not restore a stale query at the next unrelated invocation.

This requires prototype validation.

### 8.4 Prefilled invocation

Sources:

- Service-selected text.
- Deep link.
- App Intent.
- Main-window selected word.

Behavior:

- Validate and normalize text.
- Populate query.
- Start lookup immediately.
- Keep saving explicit.

### 8.5 Clipboard suggestion

If enabled:

- Read clipboard locally when opening.
- Detect whether content resembles a word or short phrase.
- Present it as a suggestion.
- Do not submit automatically.

Example:

```text
Search “meticulous” from your clipboard?
```

Actions:

- Search.
- Dismiss.

---

## 9. Dismissal

### 9.1 Dismiss triggers

- Escape.
- Clicking outside, if the panel is configured for transient dismissal.
- Successful Add followed by configured auto-dismiss.
- Open Detail.
- Explicit close command.

### 9.2 Escape hierarchy

```text
If a popover is open
→ close popover

Else if an assistant preview is expanded
→ collapse preview

Else
→ dismiss Quick Lookup
```

### 9.3 Outside click

Product decision required:

- Dismiss immediately.
- Remain until Escape.

Recommended:

- Dismiss on outside click for ordinary lookup.
- Keep open during saving or a required error decision.

### 9.4 Focus restoration

After dismissal:

- Return focus to the previously active application where macOS permits.
- Do not activate the main Voca workspace.

### 9.5 Unsaved state

Ordinary lookup content requires no confirmation.

If the user has entered additional metadata in an expanded save form:

- Preserve draft or ask before dismissing.

The initial Quick Lookup should avoid complex forms that create this issue.

---

## 10. Visual structure

### 10.1 Empty state

```text
┌──────────────────────────────────────────────────────────┐
│ Search for a word or short phrase…                       │
└──────────────────────────────────────────────────────────┘
```

Optional supporting content:

- Clipboard suggestion.
- Recent lookup, if privacy policy permits.
- Keyboard hint.

Do not show:

- Full feature navigation.
- Dashboard cards.
- Marketing content.

### 10.2 Result state

```text
┌──────────────────────────────────────────────────────────┐
│ concise                                             ×    │
├──────────────────────────────────────────────────────────┤
│ concise                                         🔊       │
│ /kənˈsaɪs/                                               │
│                                                          │
│ brief but comprehensive                                  │
│                                                          │
│ Keep your explanation concise.                           │
│                                                          │
│ [Add to Voca]     [Ask Assistant]     [Open Detail]      │
└──────────────────────────────────────────────────────────┘
```

### 10.3 Existing-card state

Replace Add to Voca with:

```text
Saved in Vocabulary
```

Actions:

- Open Detail.
- Add Tag, if a compact action is approved.
- Start Review or Practice, where useful.

### 10.4 Pending-save state

Example:

```text
Saved on this Mac
Waiting to sync
```

### 10.5 Information priority

1. Word or Hanzi.
2. Pronunciation or pinyin.
3. Audio.
4. Concise meaning.
5. One primary example.
6. Save or saved state.
7. Assistant and detail actions.

---

## 11. Input behavior

### 11.1 Search field

The query field:

- Receives focus immediately.
- Supports standard macOS text editing.
- Supports paste.
- Supports clear.
- Supports input methods.
- Does not intercept ordinary editing shortcuts.

### 11.2 Supported input

Initial:

- One English word.
- One Chinese word or phrase.
- Short English phrase.
- Short Chinese phrase.

Longer input:

- Offer Extract Vocabulary or Ask Assistant.
- Do not attempt to render a single dictionary result incorrectly.

### 11.3 Limits

Apply a reasonable character limit for direct lookup.

Example policy:

```text
Up to 120 Unicode scalar values for direct lookup.
Longer content routes to text analysis.
```

The final limit should reflect API and UX capabilities.

### 11.4 Debounce

Suggested:

```text
150–250 milliseconds
```

Local exact matching may run sooner.

### 11.5 Return key

Behavior:

- If no lookup has started, submit current query.
- If a top result is visible, keep focus predictable and do not save accidentally.

Saving should not use plain Return by default unless a clear command mode is established.

### 11.6 Command + Return

Candidate:

- Open full detail.

### 11.7 Input cancellation

New query:

- Cancels obsolete remote work.
- Prevents stale result replacement.
- Preserves local result where appropriate until the new result is ready.

---

## 12. Query normalization

### 12.1 Shared normalization

- Trim leading and trailing whitespace.
- Collapse repeated internal whitespace for phrases.
- Apply Unicode normalization.
- Preserve original user-entered text for display.

### 12.2 English

For matching:

- Case folding.
- Normalize typographic apostrophes where appropriate.
- Preserve punctuation that changes meaning.

### 12.3 Chinese

Support:

- Hanzi.
- Pinyin with tone marks.
- Pinyin without tone marks.
- Pinyin tone numbers where feasible.

### 12.4 Unsupported content

If input is:

- A URL.
- A long paragraph.
- A file path.
- Mostly unsupported symbols.

Offer an appropriate alternative or explain that direct word lookup is unavailable.

---

## 13. Language detection

### 13.1 Detection rules

Initial deterministic rules:

- Hanzi characters suggest Chinese.
- Latin input uses recent or default language context.
- Pinyin-like input may produce Chinese candidates.

### 13.2 Ambiguous input

For ambiguous text:

- Search relevant local indexes.
- Rank exact saved matches first.
- Expose a compact language selector when needed.

### 13.3 Manual override

Language selector options:

```text
Auto
English
中文
```

The selected override applies to the current query.

### 13.4 Preference

The user's last explicit language selection may influence future ambiguous queries, but should not prevent exact matches in another language.

---

## 14. Lookup pipeline

Recommended pipeline:

```text
Query
→ Validate
→ Normalize
→ Detect language
→ Search saved local vocabulary
→ Search cached dictionary content
→ Render best local result
→ Start remote lookup if needed
→ Merge and rerank
→ Render enriched result
```

### 14.1 Stage 1: saved local vocabulary

Search:

- Canonical word.
- Normalized word.
- Hanzi.
- Pinyin.
- Meaning where useful.

Exact saved matches rank highest.

### 14.2 Stage 2: cached dictionary

Use known shared content already available locally.

### 14.3 Stage 3: backend lookup

Use remote service when:

- No sufficient local result exists.
- Cached content is incomplete.
- User explicitly requests refresh or enrichment.

### 14.4 Stage 4: AI generation

AI is not an automatic stage of ordinary lookup unless the backend product contract explicitly uses generation for missing dictionary data.

If needed:

- Mark generation clearly.
- Allow cancellation.
- Avoid repeated generation for the same canonical word when reusable content exists.

### 14.5 Result updates

When remote content enriches an existing local result:

- Preserve the result identity.
- Avoid flashing to an unrelated layout.
- Avoid moving the primary action unexpectedly.

---

## 15. Result ranking

Suggested order:

1. Exact saved canonical-text match.
2. Exact cached dictionary match.
3. Exact normalized match.
4. Exact Hanzi match.
5. Exact pinyin match.
6. Prefix match.
7. Inflection or variant match.
8. Meaning match.
9. Remote fuzzy match.

### 15.1 Saved-card boost

Saved status boosts the exact matching entity, but should not cause an unrelated saved word to outrank the exact query.

### 15.2 Language boost

Explicit language override is a strong ranking signal.

Auto-detected language is a softer signal.

### 15.3 Recency

Recent lookup or recently used vocabulary may break ties.

It must not reveal private history when history retention is disabled.

### 15.4 Multiple candidates

When multiple strong candidates exist:

- Show the top result.
- Provide a compact candidate list or disclosure.

Do not expand into a full search page.

---

## 16. Result states

State model:

```text
Empty
Clipboard Suggestion
Typing
Searching Local
Local Result
Searching Remote
Enriched Result
Multiple Candidates
No Result
Offline Result
Already Saved
Saving
Saved
Pending Sync
Error
Authentication Required
```

### 16.1 Local result

Show immediately.

If remote enrichment is running:

- Use a subtle status.
- Keep result interactive.

### 16.2 No result

Show:

- Query.
- Try another spelling.
- Switch language.
- Ask Assistant.
- Add Manually, if allowed.

### 16.3 Offline result

If local result exists:

- Show it.
- Indicate offline state subtly.

If no local result:

- Explain remote lookup is unavailable.
- Preserve query.
- Offer retry.

### 16.4 Error

Network or provider error should not erase a valid local result.

---

## 17. English result

### 17.1 Identity

- Canonical word.
- Phonetic transcription.
- Audio.
- Optional part of speech.

### 17.2 Meaning

Show one concise primary meaning.

Allow disclosure for:

- Additional meanings.
- Usage notes.

### 17.3 Example

Show one short primary example.

The target word may be emphasized without relying only on color.

### 17.4 Variant

If query is an inflected form:

```text
running
Form of run
```

The canonical save behavior must be explicit:

- Save canonical form.
- Save entered form where product policy permits.

### 17.5 Pronunciation

Use configured English voice or cached audio.

---

## 18. Chinese result

### 18.1 Identity

- Hanzi.
- Pinyin.
- Mandarin audio.

### 18.2 Meaning

Show concise Vietnamese meaning.

### 18.3 Example

Where available:

- Chinese sentence.
- Pinyin.
- Vietnamese translation.

The compact panel may show only the Chinese sentence and translation, with pinyin disclosed.

### 18.4 Character actions

Quick Lookup may offer:

- View Stroke Order.

This opens full detail rather than embedding a large writing canvas.

### 18.5 Pinyin query

When query is pinyin:

- Present matching Hanzi candidates.
- Show concise meanings for disambiguation.

---

## 19. Pronunciation

### 19.1 Action

Audio action must remain visible near word identity.

### 19.2 Keyboard shortcut

Candidate:

```text
Option + P
```

The final shortcut should match the main app.

### 19.3 Playback states

```text
Idle
Loading
Playing
Failed
Unavailable
```

### 19.4 Coordination

Starting Quick Lookup pronunciation stops other active Voca playback.

### 19.5 Auto-play

Default:

- Off.

Optional user preference:

- Auto-play exact result.

Auto-play must avoid unexpected speech when:

- The query came from clipboard suggestion.
- Several candidates exist.
- The panel opened accidentally.

### 19.6 Failure

- Keep lookup usable.
- Offer retry.
- Explain remote-only audio when offline.

---

## 20. Add to Voca

### 20.1 Eligibility

Add is available when:

- A valid dictionary result exists.
- User is authenticated.
- The result is not already saved.

### 20.2 Default save

Quick save creates:

- User card.
- Default learning state.
- Current language.
- Existing shared dictionary relationship.

It does not require tags or notes.

### 20.3 Optional metadata

A secondary disclosure may allow:

- Level.
- Tags.
- Topic.

The first release should keep this compact.

### 20.4 Save flow

```text
Add action
→ Validate saved status
→ Create stable operation ID
→ Persist local intent
→ Update panel to Saved
→ Synchronize
```

### 20.5 Save success

Show:

```text
Saved to Vocabulary
```

Optional:

- Auto-dismiss after a short delay.
- Remain open for additional actions.

This preference requires product validation.

### 20.6 Offline save

If dictionary content is available locally:

- Save user-card intent locally.
- Show Pending Sync.

If required content is unavailable:

- Preserve query.
- Explain that the word can be saved after reconnection.

### 20.7 Save error

If local persistence fails:

- Do not claim success.
- Preserve result.
- Offer retry.

If remote synchronization fails after local save:

- Keep Saved on This Mac.
- Show pending state.

---

## 21. Already-saved behavior

### 21.1 Saved state

Show:

- Saved indicator.
- Learning level.
- Next review where concise.

### 21.2 Actions

- Open Detail.
- Play Pronunciation.
- Ask Assistant.
- Start Practice.

Optional compact metadata action:

- Favorite.

### 21.3 Duplicate prevention

Pressing Add or an equivalent shortcut repeatedly must not create another user card.

### 21.4 Pending creation

If the word was created locally but has not synchronized:

```text
Saved on this Mac
Waiting to sync
```

The pending local card counts as already saved.

---

## 22. Ask Assistant

### 22.1 Purpose

Useful tasks:

- Explain in simpler language.
- Compare similar words.
- Provide another example.
- Explain grammar or usage.

### 22.2 Initial behavior

Recommended:

- Open the main Assistant workspace with the result as context.

Alternative:

- Show a compact one-response expansion in Quick Lookup.

The first release should prefer opening the full Assistant to keep the panel lightweight.

### 22.3 Context

Send only:

- Selected result.
- Explicit user request.
- Relevant language setting.

Do not include:

- Clipboard history.
- Unrelated recent words.
- Personal notes unless selected.

### 22.4 Offline state

Disable or explain that Assistant requires connectivity when no local model exists.

---

## 23. Open Detail

### 23.1 Saved word

Flow:

```text
Open Detail
→ Activate Voca main workspace
→ Navigate to Vocabulary
→ Select user card
→ Reveal detail
→ Dismiss Quick Lookup
```

### 23.2 Unsaved dictionary result

Options:

- Open a dictionary-result detail route.
- Prompt to save first.

Recommended:

- Allow full preview without requiring save.

### 23.3 Window policy

Default:

- Reuse most recent main workspace window.

If no main window exists:

- Create one.

A modifier-key variant may open a separate word window later.

### 23.4 Focus

After navigation:

- Main word detail becomes the intentional focus.
- Do not return focus to the original application.

---

## 24. Clipboard suggestion

### 24.1 Preference

Settings:

```text
Suggest short clipboard text when Quick Lookup opens
```

Default recommendation:

- Off until privacy UX is validated.

If enabled, explain behavior clearly.

### 24.2 Read timing

Read only when:

- User explicitly opens Quick Lookup.
- The preference is enabled.

Do not continuously monitor clipboard for this feature.

### 24.3 Candidate validation

Suggest only if:

- Plain text.
- Short.
- Not empty.
- Not obviously a token, password, or large structured value.
- Not the same suggestion recently dismissed.

### 24.4 Sensitive-content heuristics

Avoid suggestion for content resembling:

- Long random secrets.
- Credit-card numbers.
- Authentication tokens.
- Private keys.
- Multi-line confidential data.

Heuristics reduce risk but do not establish perfect sensitivity detection.

### 24.5 Network boundary

Clipboard content remains local until the user:

- Chooses Search.
- Edits and submits the query.

### 24.6 Persistence

Do not retain raw clipboard suggestions after panel dismissal.

---

## 25. Authentication

### 25.1 Signed-in state

All features available according to connectivity and capability.

### 25.2 Signed-out state

Potential experience:

- Allow local dictionary lookup if non-private content exists.
- Disable Add to Voca.
- Offer Sign In to Save.

Alternatively:

- Show compact Sign In requirement.

The final behavior depends on whether dictionary lookup is an authenticated backend capability.

### 25.3 Expired session

If a saved local result exists:

- Continue showing it.
- Require sign in for remote lookup or saving.

### 25.4 Sign-in routing

```text
Sign In to Save
→ Open authentication scene
→ Preserve pending lookup query
→ Return to Quick Lookup or open main word detail
```

The return behavior must be predictable.

---

## 26. Offline behavior

### 26.1 Available offline

- Search saved vocabulary.
- Search cached dictionary content.
- View meanings and examples.
- Play cached audio.
- Use approved system speech fallback.
- Save locally when content is sufficient.
- Open cached full detail.

### 26.2 Unavailable offline

- Remote lookup for uncached words.
- Remote TTS.
- Assistant generation.
- AI content enrichment.

### 26.3 Offline presentation

Use one concise status:

```text
Offline · Showing saved results
```

Do not repeat offline labels beside every field.

### 26.4 Reconnection

The current query may automatically retry remote enrichment when:

- The panel remains open.
- Query has not changed.
- The user has not dismissed the lookup.

Avoid replacing a valid local result unexpectedly.

---

## 27. Privacy and security

### 27.1 Query privacy

Local searches remain local.

Remote query transmission occurs only when:

- The user submits a lookup requiring remote data.
- The user explicitly invokes Assistant.

### 27.2 Clipboard

- No continuous read for Quick Lookup.
- No automatic upload.
- No raw clipboard history.
- No clipboard text in logs.

### 27.3 Logs

Allowed:

- Lookup source.
- Duration.
- Result category.
- Error category.
- Cache hit.

Disallowed:

- Query text.
- Clipboard text.
- Meaning.
- Assistant content.
- Tokens.

### 27.4 Analytics

Allowed:

- Panel opened.
- Invocation source.
- Local-result timing.
- Remote-result timing.
- Save conversion category without word content.
- Error category.

### 27.5 Screen privacy

Quick Lookup displays user-requested content above another application.

Settings may later offer:

- Hide meaning in screen-sharing mode.
- Disable clipboard suggestions.

The first release must at least avoid showing old results on fresh invocation.

---

## 28. Accessibility

### 28.1 Keyboard-only flow

Users must be able to:

1. Invoke Quick Lookup.
2. Enter query.
3. Start lookup.
4. Read result.
5. Play pronunciation.
6. Save.
7. Open detail.
8. Dismiss.

### 28.2 Focus order

Recommended:

1. Query field.
2. Language override.
3. Word identity.
4. Pronunciation.
5. Meaning.
6. Example.
7. Primary action.
8. Assistant.
9. Open Detail.
10. Additional candidates.

### 28.3 VoiceOver opening

On open:

- Announce Quick Lookup.
- Place focus in search field.

Do not announce stale prior-result content.

### 28.4 Search states

Announce meaningful changes:

```text
Searching
Result found
No result
Saved to Vocabulary
Offline result
```

Avoid announcing every streaming or loading-frame update.

### 28.5 Result identity

English example:

```text
concise, pronunciation kən-saɪs
```

Chinese example:

```text
简洁, pinyin jiǎnjié
```

### 28.6 Larger text

At larger text sizes:

- Panel grows vertically.
- Meaning and example wrap.
- Actions may stack.
- Primary query remains visible.

### 28.7 Increased Contrast

- Panel edge remains visible.
- Focus remains clear.
- Saved and error states include labels.

### 28.8 Reduced Motion

- Panel appears with minimal transition.
- Result expansion avoids dramatic movement.
- Saved confirmation is immediate or uses subtle opacity.

### 28.9 Voice Control

Actions require distinct accessible names:

- Add to Voca.
- Play Pronunciation.
- Ask Assistant.
- Open Detail.
- Clear Search.

---

## 29. Performance targets

These are initial product targets to validate on supported hardware.

### 29.1 Panel presentation

Target:

```text
Visible and ready for typing within 150 ms of shortcut handling.
```

The panel must not wait for:

- Database query.
- Authentication refresh.
- Network.
- AI.

### 29.2 Local exact result

Target:

```text
First local exact result within 100 ms after debounce.
```

### 29.3 Local broad result

Target:

```text
Useful local result within 250 ms for a typical 10,000-card library.
```

### 29.4 Remote result

Remote latency depends on network and server.

The UI should:

- Show local state first.
- Show progress without blocking.
- Permit cancellation.

### 29.5 Memory

Quick Lookup should initialize:

- Lookup-specific state.
- Shared repositories.
- No complete main-window feature tree.

### 29.6 Energy

The global shortcut listener should remain idle-efficient.

Quick Lookup must not poll the clipboard continuously.

---

## 30. Error behavior

### 30.1 Shortcut registration failure

Show in Settings:

```text
Option + Space is already used by another application.
Choose a different shortcut.
```

Quick Lookup remains available through menus.

### 30.2 Local database unavailable

- Explain local results cannot be loaded.
- Attempt remote lookup if safe and authenticated.
- Offer Open Voca for repair.

### 30.3 Remote lookup failure

If local result exists:

- Keep it.
- Show remote enrichment unavailable.

If none exists:

- Preserve query.
- Offer Retry.

### 30.4 Authentication failure

- Keep public or cached content visible.
- Offer Sign In for saving or remote actions.

### 30.5 Save conflict

If another device saved the word:

- Resolve to Already Saved.
- Do not show a destructive error.

### 30.6 Audio failure

- Keep result usable.
- Offer Retry.

### 30.7 Invalid query

Explain:

- Enter a word or short phrase.
- Use document extraction for longer text.

---

## 31. State model

Illustrative state:

```swift
@MainActor
@Observable
final class QuickLookupFeature {
    enum Phase {
        case empty
        case clipboardSuggestion(String)
        case searchingLocal
        case localResult(LookupResult)
        case searchingRemote(LookupResult?)
        case result(LookupResult)
        case noResult
        case saving(LookupResult)
        case saved(UserCardSummary)
        case failed(QuickLookupError)
    }

    var query = ""
    var language: LookupLanguage = .automatic
    private(set) var phase: Phase = .empty
    private(set) var candidates: [LookupResult] = []

    func opened(with input: LookupInput?) async
    func queryChanged() async
    func submit() async
    func playPronunciation() async
    func addToVocabulary() async
    func openAssistant()
    func openDetail()
    func dismiss()
}
```

### 31.1 State invariants

- One panel instance.
- One current query.
- Obsolete lookup tasks cannot update current results.
- Save operation uses stable identity.
- Existing local pending card counts as saved.
- Clipboard suggestion is not a submitted query.

---

## 32. Technical architecture

### 32.1 Components

```text
QuickLookupCoordinator
QuickLookupWindowController
QuickLookupFeature
LookupWordUseCase
AddWordUseCase
SpeechService
GlobalShortcutService
ClipboardSuggestionService
SceneCoordinator
```

### 32.2 Coordinator

Responsibilities:

- Register invocation sources.
- Present panel.
- Place panel.
- Restore focus.
- Prevent duplicate panels.

It does not:

- Search vocabulary.
- Build API requests.
- Save user cards directly.

### 32.3 Window controller

Responsibilities:

- Manage AppKit panel.
- Set key-window behavior.
- Position on display.
- Handle dismissal.
- Bridge SwiftUI content.

### 32.4 Feature

Responsibilities:

- Query state.
- Lookup state.
- Result actions.
- Save state.
- User-visible errors.

### 32.5 Use cases

Quick Lookup reuses:

- Lookup Word.
- Add Word.
- Play Pronunciation.
- Open Word Route.

No direct API calls from window-controller code.

---

## 33. Global shortcut architecture

### 33.1 Service interface

```swift
protocol GlobalShortcutService: Sendable {
    func register(
        _ shortcut: GlobalShortcut,
        action: @escaping @Sendable () -> Void
    ) async throws

    func unregister() async
}
```

### 33.2 Shortcut model

Stores:

- Key.
- Modifiers.
- Enabled state.

### 33.3 Registration lifecycle

Register when:

- User enables Quick Lookup.
- Application starts in ambient mode.
- Shortcut preference changes.

Unregister when:

- Disabled.
- Application quits.
- Shortcut changes before re-registration.

### 33.4 Failure

Registration failure:

- Does not crash.
- Keeps menu invocation.
- Opens Settings remediation.

### 33.5 Permissions

Choose an implementation that avoids unnecessary broad permissions.

If system permissions are required:

- Explain why.
- Request only at user action.
- Provide a test action.

---

## 34. Clipboard-suggestion architecture

### 34.1 Service interface

```swift
protocol ClipboardSuggestionService: Sendable {
    func suggestion() async -> ClipboardSuggestion?
}
```

### 34.2 Isolation

The service returns:

- Validated short suggestion.
- Content category.

It must not:

- Persist full history.
- Trigger network.
- Start lookup.

### 34.3 Duplicate suppression

Store only a nonreversible local fingerprint long enough to avoid repeatedly suggesting dismissed content.

Do not retain the clipboard text itself.

---

## 35. Commands and shortcuts

Proposed panel commands:

```text
Escape                       Dismiss
Command + L                  Focus query
Command + A                  Select query text when field focused
Command + Return             Open Detail
Option + P                   Play Pronunciation
Command + S                  Add to Voca, if not saved
Command + Shift + A          Ask Assistant
Up / Down                    Navigate candidates
Return                       Submit query or choose candidate
```

`Command + S` requires validation because Save conventions may imply document saving.

Alternative:

```text
Command + Shift + S
```

All important commands should appear in:

- Tooltips.
- Menu commands.
- Accessibility actions.

---

## 36. Analytics boundaries

### 36.1 Allowed events

- Quick Lookup opened.
- Invocation source.
- Clipboard suggestion shown.
- Suggestion accepted or dismissed.
- Local cache hit.
- Remote lookup required.
- Result found.
- Save initiated.
- Save completed.
- Open Detail.
- Assistant opened.
- Technical latency.
- Error category.

### 36.2 Prohibited fields

- Query text.
- Word text.
- Meaning.
- Clipboard text.
- Selected application name unless separately approved and necessary.
- Assistant prompt.
- Personal notes.

### 36.3 Conversion metric

Safe metric:

```text
Percentage of successful lookups resulting in save.
```

The underlying word content is not required.

---

## 37. Testing strategy

### 37.1 State tests

- Empty invocation.
- Prefilled invocation.
- Clipboard suggestion.
- Local exact result.
- Local plus remote enrichment.
- No result.
- Offline result.
- Already saved.
- Pending save.
- Authentication required.

### 37.2 Concurrency tests

- Type rapidly.
- Cancel old request.
- Remote old response arrives late.
- Verify old response is ignored.

### 37.3 Save tests

- New word.
- Existing word.
- Pending local word.
- Offline save.
- Save timeout after server acceptance.
- Repeated save command.

### 37.4 Window tests

- One display.
- Multiple displays.
- Different scales.
- Full-screen application.
- Different Spaces.
- Main Voca window closed.
- Menu bar-only mode.

### 37.5 Focus tests

- Open from another app.
- Type immediately.
- Dismiss.
- Verify prior app focus.
- Open Detail.
- Verify Voca main window focus.

### 37.6 Shortcut tests

- Successful registration.
- Conflict.
- Change shortcut.
- Disable shortcut.
- Relaunch.

### 37.7 Clipboard tests

- Disabled preference.
- Short word.
- Long paragraph.
- Secret-like content.
- Multi-line text.
- Dismissed duplicate.
- Verify no automatic network request.

### 37.8 Accessibility tests

- VoiceOver open announcement.
- Keyboard-only lookup.
- Larger text.
- Increased Contrast.
- Reduce Motion.
- Voice Control labels.

### 37.9 Performance tests

- Cold first invocation.
- Warm invocation.
- 10,000-card local search.
- 50,000-card stress search.
- Remote latency.
- Idle energy use.

---

## 38. Requirement traceability

### `QUICK-001` — Global invocation

Covered by:

- Entry points.
- Global shortcut.
- Registration lifecycle.
- Conflict handling.

### `QUICK-002` — Immediate text entry

Covered by:

- Window activation.
- First responder.
- Input behavior.
- Performance targets.

### `QUICK-003` — Concise lookup result

Covered by:

- Visual structure.
- Information priority.
- English and Chinese layouts.
- Result states.

### `QUICK-004` — Quick save

Covered by:

- Add to Voca.
- Offline save.
- Duplicate prevention.
- Pending sync.

### `QUICK-005` — Open full detail

Covered by:

- Canonical main-workspace routing.
- Saved and unsaved result behavior.
- Window activation.

### `QUICK-006` — Clipboard suggestion

Covered by:

- Preference.
- Local validation.
- Sensitive-content heuristics.
- No automatic upload.

### `QUICK-007` — Multi-display behavior

Covered by:

- Active-display placement.
- Visible frame.
- Spaces.
- Full-screen applications.
- Display tests.

---

## 39. Acceptance scenarios

### Scenario A — Global English lookup

1. Focus another application.
2. Press the global shortcut.
3. Type an English word.
4. Read the local or remote result.
5. Play pronunciation.
6. Dismiss with Escape.

Expected:

- Panel appears on active display.
- Typing works immediately.
- Original application regains focus.

### Scenario B — Save from Quick Lookup

1. Look up an unsaved word.
2. Select Add to Voca.
3. Dismiss.
4. Open Vocabulary.

Expected:

- Word appears once.
- Shared dictionary content is reused.
- Correct language is assigned.

### Scenario C — Existing word

1. Look up a saved word.

Expected:

- Saved state appears.
- Add action is absent or disabled.
- Open Detail selects the existing card.

### Scenario D — Rapid queries

1. Type one query.
2. Immediately replace it with another.
3. Let the first remote response arrive last.

Expected:

- Only the second result is displayed.

### Scenario E — Offline local result

1. Disconnect.
2. Look up a synchronized word.

Expected:

- Local result appears.
- Cached pronunciation works when available.
- Offline status is concise.

### Scenario F — Offline unknown result

1. Disconnect.
2. Search for an uncached word.

Expected:

- Query is preserved.
- Remote-unavailable explanation appears.
- Retry is available.

### Scenario G — Chinese lookup

1. Enter Hanzi.
2. Verify pinyin and Vietnamese meaning.
3. Play Mandarin audio.
4. Save.

Expected:

- Chinese layout is correct.
- Mandarin voice is used.
- Saved card is classified as Chinese.

### Scenario H — Pinyin candidates

1. Enter pinyin without tone marks.

Expected:

- Relevant Hanzi candidates appear.
- Meanings help disambiguate.
- Selection does not save automatically.

### Scenario I — Clipboard suggestion

1. Enable clipboard suggestions.
2. Copy a short word.
3. Open Quick Lookup.

Expected:

- Suggestion appears.
- No lookup request occurs before acceptance.
- Dismissal does not retain raw text.

### Scenario J — Secret-like clipboard content

1. Copy a token-like random string.
2. Open Quick Lookup.

Expected:

- Content is not automatically suggested.
- Nothing is uploaded.

### Scenario K — Multiple displays

1. Focus an app on the secondary display.
2. Invoke Quick Lookup.

Expected:

- Panel appears fully inside that display's visible frame.

### Scenario L — Open Detail

1. Search a saved word.
2. Choose Open Detail.

Expected:

- Quick Lookup dismisses.
- Voca activates.
- Exact word detail opens.

### Scenario M — Shortcut conflict

1. Register an unavailable shortcut.

Expected:

- Clear error appears in Settings.
- Menu invocation still works.
- Another shortcut can be assigned.

### Scenario N — VoiceOver

1. Enable VoiceOver.
2. Invoke Quick Lookup.
3. Enter a query.
4. Read result.
5. Save.
6. Dismiss.

Expected:

- Search receives focus.
- State changes are announced once.
- Actions have distinct labels.
- Focus returns appropriately.

---

## 40. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Quick Lookup is a single-instance floating macOS panel.
2. The proposed default shortcut is Option + Space.
3. The panel opens on the active display and current Space.
4. Panel presentation never waits for network or authentication refresh.
5. Saved local vocabulary is searched before remote services.
6. One primary result is shown by default.
7. Clipboard suggestions are opt-in and require explicit acceptance.
8. Clipboard suggestions never trigger automatic network transmission.
9. Add to Voca is explicit.
10. Existing and pending local cards count as already saved.
11. Full Assistant behavior opens the main Assistant workspace.
12. Open Detail uses the canonical word route.
13. Query text is excluded from analytics and ordinary logs.
14. The panel closes without activating the main Voca workspace unless Open Detail or another advanced route is chosen.

---

## 41. Open questions

1. Is Option + Space sufficiently conflict-free for the target users?
2. Which global-hotkey implementation best avoids unnecessary permissions?
3. Should the panel dismiss on outside click?
4. Should successful save automatically dismiss the panel?
5. Should a new invocation preserve the prior query briefly?
6. Should clipboard suggestions be enabled or disabled by default?
7. Should Quick Lookup read selected text through Accessibility APIs, Services, or neither?
8. Can unauthenticated users perform dictionary lookup?
9. Does the backend expose a dedicated lightweight lookup endpoint?
10. How are inflected English forms resolved?
11. Should pinyin search be implemented locally, remotely, or both?
12. Should multiple candidates appear inline or in a disclosure list?
13. Should Quick Lookup support phrases in the first release?
14. Should the panel remember explicit language override?
15. Should Add to Voca expose tags before saving?
16. Should pronunciation auto-play be offered?
17. Should unsaved results open a full dictionary-preview window?
18. Should Open Detail reuse the last workspace or create a word window?
19. Which behavior works best over full-screen applications and multiple Spaces?
20. Should users be able to pin the panel temporarily?

---

## 42. Backend and system dependencies

Quick Lookup may require:

- Fast local full-text search.
- Lightweight remote dictionary lookup.
- Stable dictionary-entry identity.
- Duplicate detection.
- Idempotent card creation.
- TTS or cached audio.
- Canonical deep links.
- Global shortcut registration.
- AppKit panel coordination.
- Authentication bootstrap that does not delay presentation.
- Language detection and normalization.

Backend lookup should ideally return:

- Canonical entry ID.
- Language.
- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meanings.
- One primary example.
- Audio availability.
- Saved-user-card relationship where efficient.

---

## 43. Definition of done

Quick Lookup is complete for the macOS differentiation release when:

- It opens globally through a configurable shortcut.
- The panel is ready for typing immediately.
- It appears on the correct display and Space.
- Local exact results appear without network dependency.
- Remote lookup enriches or resolves unknown words.
- English and Chinese layouts are correct.
- Pronunciation works and remains nonblocking.
- Add to Voca creates no duplicates.
- Offline save behavior is truthful and durable.
- Existing and pending cards are recognized.
- Open Detail resolves to the exact word.
- Clipboard suggestion is opt-in and private.
- Query text is excluded from logs and analytics.
- Escape and outside-click behavior are predictable.
- Focus restoration works.
- VoiceOver, keyboard, larger text, Increased Contrast, and Reduce Motion pass.
- Performance and idle-energy targets pass.
- Multi-display, full-screen, and Spaces scenarios pass.

---

## 44. Next document

The next document should be:

```text
docs/macos-menu-bar.md
```

It should define:

- Menu bar icon and due-count policy.
- Enabled and disabled states.
- Signed-in and signed-out states.
- Popover layout.
- Word of the day.
- Quick Lookup and Quick Add.
- Mini Review.
- Sync status.
- Reminder controls.
- Launch-at-login behavior.
- Main-window lifecycle.
- Background refresh.
- Privacy.
- Accessibility.
- Energy use.
- Acceptance criteria mapped to `MENU-*`.
