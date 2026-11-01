# Voca for macOS — Vocabulary Workspace

> Detailed product, UX, interaction, state, and acceptance specification for the native macOS vocabulary-management experience.

## Document status

- **Status:** Draft
- **Document type:** Feature Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Primary requirement groups:** `VOC-*`, `LANG-*`, `SYNC-*`, `A11Y-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the complete Vocabulary workspace for Voca on macOS.

It covers:

- Vocabulary terminology and data concepts.
- Collections and Smart Lists.
- Table, list, and grid presentations.
- Search, filtering, sorting, and ranking.
- Selection and multi-selection.
- Word detail and inspector.
- Add, edit, duplicate, delete, Trash, and restore flows.
- Tags, topics, favorites, and personal notes.
- Batch actions.
- Context menus and commands.
- Drag and drop.
- English and Chinese presentation.
- Offline and synchronization behavior.
- Keyboard and accessibility behavior.
- Performance expectations.
- Product analytics boundaries.
- Acceptance criteria.

The Vocabulary workspace is the central desktop environment for understanding, organizing, and managing saved language content.

---

## 2. Product intent

Vocabulary should feel like a native macOS knowledge library rather than a collection of oversized mobile flashcards.

Users must be able to:

- Browse thousands of words efficiently.
- Search immediately.
- Inspect a word without losing the current collection.
- Select and update multiple words.
- Organize vocabulary with tags, topics, favorites, and Smart Lists.
- Add words with minimal manual entry.
- Understand synchronization state without persistent visual noise.
- Move smoothly from library management into review, practice, and AI assistance.

The workspace serves two related purposes:

1. **Language reference:** understand words, meanings, pronunciation, examples, and related content.
2. **Learning management:** organize words, inspect study state, and initiate learning activities.

Neither purpose should overwhelm the other.

---

## 3. Scope

### 3.1 Included

- System vocabulary collections.
- Native table view.
- Search.
- Structured filters.
- Sorting.
- Single and multi-selection.
- Word detail.
- Inspector.
- Add and edit.
- Duplicate handling.
- Favorite state.
- Tags and topics.
- Personal notes.
- TTS.
- English and Chinese content.
- Hanzi entry points.
- Context menus.
- Batch actions.
- Import and export entry points.
- Smart Lists.
- Trash and restore.
- Offline viewing.
- Pending synchronization states.

### 3.2 Related but specified elsewhere

- FSRS review session behavior.
- Today dashboard.
- Full AI assistant.
- OCR and document import.
- Global Quick Lookup.
- Menu bar.
- Spotlight and App Intents.
- Persistence and conflict-resolution internals.

Vocabulary exposes entry points to these features but does not own their complete behavior.

### 3.3 Excluded from the first version

- Shared public vocabulary collections.
- Collaborative editing.
- Nested folders.
- Custom arbitrary database columns.
- Rich-text personal notes.
- Full dictionary-authoring workflows.
- User-defined card templates.
- Spreadsheet-style direct editing of every table cell.

---

## 4. Domain terminology

### 4.1 Dictionary entry

A language-content entity that may include:

- Canonical word.
- Language.
- Pronunciation or pinyin.
- Meanings.
- Examples.
- Related words.
- Hanzi information.

A dictionary entry may exist without being saved by the current user.

### 4.2 User card

The user's saved relationship to a dictionary entry.

It includes:

- Learning level.
- Favorite state.
- Tags.
- Topic.
- Personal notes.
- Creation date.
- Review state.
- Review history.
- Next review.

### 4.3 Vocabulary item

The presentation model combining:

- Dictionary content.
- User-specific card state.

### 4.4 Collection

A dynamic set of vocabulary items produced by a system or saved rule.

Examples:

- All Words.
- Favorites.
- Recently Added.
- Difficult Words.
- Due Today.
- Trash.
- Smart List.

### 4.5 Smart List

A saved query containing:

- Filters.
- Search terms where supported.
- Sort rules.
- Language scope.
- Display preferences where appropriate.

A Smart List does not duplicate vocabulary.

### 4.6 Lookup result

A dictionary result that may not yet be part of user vocabulary.

The interface must distinguish:

```text
Found in dictionary
Saved in your vocabulary
```

---

## 5. Primary layout

The preferred expanded layout is:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Toolbar                                                                    │
├──────────────────┬────────────────────────────────┬────────────────────────┤
│ Sidebar          │ Vocabulary Collection          │ Word Detail            │
│                  │                                │                        │
│ All Words        │ Search / filter summary        │ Word identity          │
│ Favorites        │                                │ Meaning                │
│ Recent           │ Native table                   │ Example                │
│ Difficult        │                                │ Related content        │
│ Smart Lists      │                                │                        │
│ Trash            │                                ├────────────────────────┤
│                  │                                │ Optional Inspector     │
└──────────────────┴────────────────────────────────┴────────────────────────┘
```

### 5.1 Layout ownership

- **Sidebar:** collection selection.
- **Primary content:** table, list, or grid.
- **Detail:** selected word.
- **Inspector:** learning metadata, organization, notes, history, and contextual actions.

### 5.2 Narrow-window behavior

At narrower widths:

1. Sidebar collapses.
2. Collection remains the primary content.
3. Word detail becomes a navigation destination.
4. Inspector becomes an overlay.
5. Secondary toolbar commands move into overflow.

The app must not display three unusably narrow columns simultaneously.

---

## 6. Vocabulary navigation

### 6.1 System collections

Recommended system collections:

```text
All Words
Favorites
Recently Added
Difficult Words
Due Today
Trash
```

Potential later collections:

```text
Recently Reviewed
Never Reviewed
Without Tags
With Notes
English
Chinese
```

### 6.2 Collection behavior

Every collection defines:

- Title.
- Description where needed.
- Query rule.
- Supported actions.
- Trash visibility.
- Default sort.
- Empty state.

### 6.3 All Words

Contains all active saved vocabulary for the selected language scope.

Default sort:

```text
Recently updated or alphabetic, based on final product decision.
```

### 6.4 Favorites

Contains cards marked as favorite.

Removing favorite state removes the item from this collection without deleting it.

### 6.5 Recently Added

Contains active cards ordered by creation date descending.

The period may be:

- Last 7 days.
- Last 30 days.
- All vocabulary sorted by newest.

The final rule must be explicit in UI copy.

### 6.6 Difficult Words

Contains cards matching documented learning criteria such as:

- Repeated Again grades.
- High lapse count.
- Low recent accuracy.
- High FSRS difficulty.

The classification must not be an unexplained AI label.

### 6.7 Due Today

Contains cards eligible for review under the current server-defined study state.

Opening the collection is different from starting a review session.

### 6.8 Trash

Contains recoverable deleted user cards when backend behavior supports soft deletion.

Trash actions:

- Restore.
- Delete Permanently.
- Empty Trash.

If the backend only supports permanent deletion, Trash must not be simulated purely in the UI without a reliable data contract.

---

## 7. Toolbar specification

### 7.1 Expanded toolbar

Recommended order:

```text
[Toggle Sidebar]
[Back] [Forward]
[Language]
[Search……………………………………]
[Filter] [Sort] [View]
[Toggle Inspector]
[Add Word]
```

### 7.2 Language selector

Options:

```text
English
中文
All Languages
```

`All Languages` may be deferred if mixed-language table presentation is not sufficiently clear.

The selector controls:

- Collection query.
- Add Word defaults.
- Search normalization.
- Visible columns.
- TTS voice behavior.

### 7.3 Search

Search remains visible in standard and expanded widths.

At compact width:

- It may move into the content header.
- It must remain accessible through `Command + F`.

### 7.4 Filter

The filter control:

- Opens a popover or inspector.
- Shows an active-state indicator.
- Provides Clear All.
- Exposes active filters as visible tokens or a concise summary.

### 7.5 Sort

The sort control:

- Names the active primary sort.
- Shows direction.
- Supports optional secondary sort.

### 7.6 View picker

Options:

```text
Table
List
Grid
```

Table is the macOS default.

### 7.7 Add Word

The Add Word action:

- Is consistently reachable.
- Uses `Command + N`.
- Opens the appropriate add flow.
- Inherits the current language where appropriate.

---

## 8. Table view

### 8.1 Purpose

Table view is optimized for:

- Scanning.
- Sorting.
- Comparison.
- Multi-selection.
- Batch operations.
- Large libraries.

### 8.2 Default English columns

```text
Favorite
Word
Meaning
Level
Next Review
Tags
```

### 8.3 Default Chinese columns

```text
Favorite
Hanzi / Pinyin
Vietnamese Meaning
Level
Next Review
Tags
```

### 8.4 Optional columns

```text
Pronunciation
Language
Topic
Created Date
Updated Date
Last Reviewed
Review Count
Lapse Count
Difficulty
Stability
Has Notes
```

Technical FSRS columns such as stability and difficulty should be hidden by default unless users understand their meaning.

### 8.5 Column customization

Users should be able to:

- Show optional columns.
- Hide nonessential columns.
- Resize columns.
- Reorder columns where platform support is reliable.
- Restore defaults.

The primary Word column cannot be hidden.

### 8.6 Column-width behavior

Suggested initial constraints:

```text
Favorite             34–44
Word                 140–280
Meaning              220–500
Level                 70–100
Next Review           100–150
Tags                  140–300
```

User-selected widths persist per device.

### 8.7 Row density

Modes:

```text
Compact
Comfortable
```

Comfortable should be the initial default if pinyin is shown as a second line.

### 8.8 English word cell

Primary line:

- Word.

Optional secondary line:

- Pronunciation.

### 8.9 Chinese word cell

Primary line:

- Hanzi.

Secondary line:

- Pinyin.

Pinyin must not visually overpower the Hanzi.

### 8.10 Meaning cell

Display:

- Primary concise meaning.
- Optional secondary meaning when density allows.

Long meanings truncate in the table but appear fully in detail.

### 8.11 Level cell

Display:

- Text label.
- Optional subtle semantic color.

Do not use color alone.

### 8.12 Next Review cell

Examples:

```text
Due now
Today, 16:30
Tomorrow
Oct 28
Not scheduled
```

Use locale-aware dates and understandable relative time.

### 8.13 Tag cell

Show:

- First tags that fit.
- Overflow count such as `+3`.

Hover or detail may reveal the complete tag set.

### 8.14 Selection

Support native:

- Single selection.
- Command-click.
- Shift-click.
- Select All.
- Keyboard range extension.

Selection identity uses stable card IDs.

### 8.15 Row activation

Single click:

- Selects.
- Updates detail.

Double click or Return:

- Opens full word detail or separate word window according to the final interaction decision.

Space:

- May open Quick Look-style word preview if implemented.

### 8.16 Inline editing

The first release should not enable unrestricted spreadsheet-style editing.

Possible safe inline actions:

- Favorite toggle.
- Level selector.
- Tag assignment.

Complex content editing belongs in the edit flow or inspector.

---

## 9. List view

List view offers richer previews than Table while remaining vertically efficient.

### 9.1 Row content

```text
Word / Hanzi                         Favorite
Pronunciation / Pinyin
Primary meaning
Example preview
Level · Next review · Tags
```

### 9.2 Use cases

- Reading through recently added words.
- Reviewing content quality.
- Browsing examples.
- Smaller collections.

### 9.3 Multi-selection

List view must support the same selection semantics as Table.

### 9.4 Limitation

List view is not the default for large-library management because comparing structured metadata is slower than in Table.

---

## 10. Grid view

Grid view is optimized for:

- Visual browsing.
- Small curated collections.
- Favorites.
- Recently added vocabulary.

### 10.1 Card content

Show:

- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meaning.
- Favorite state.
- Learning level.
- Due indicator.

Do not show:

- Long examples by default.
- Full tag lists.
- Detailed FSRS metadata.

### 10.2 Grid sizing

Cards should use an adaptive width with a stable readable minimum.

Suggested:

```text
Minimum card width    220
Ideal card width      260–320
```

### 10.3 Selection

Grid supports:

- Single selection.
- Command-click.
- Shift-click where platform behavior permits.
- Keyboard movement.

### 10.4 Visual restraint

Grid cards may use a subtle surface and border, but should not become heavily decorated flashcards.

---

## 11. Search

### 11.1 Requirement

Search must feel immediate for a typical personal vocabulary library.

### 11.2 Searchable fields

English:

- Word.
- Normalized word.
- Pronunciation where useful.
- Meanings.
- Examples where performance permits.
- Personal notes when enabled.

Chinese:

- Hanzi.
- Pinyin with tone marks.
- Normalized pinyin without tone marks.
- Vietnamese meaning.
- Examples.
- Notes when enabled.

### 11.3 Query normalization

Normalization may include:

- Case folding.
- Leading and trailing whitespace removal.
- Unicode normalization.
- Pinyin tone-insensitive matching.
- Diacritic-insensitive matching where appropriate.

Normalization must not prevent exact diacritic-aware results from ranking highest.

### 11.4 Ranking

Suggested ranking:

1. Exact canonical word match.
2. Exact normalized word match.
3. Prefix word match.
4. Hanzi or pinyin match.
5. Meaning match.
6. Example match.
7. Note match.

Recent use may be a minor tie-breaker but should not override strong textual relevance.

### 11.5 Search behavior

- Results update after a short debounce.
- New queries cancel obsolete work.
- Stale results never replace newer results.
- Current structured filters remain active.
- Clear restores the collection.

### 11.6 Search state

Search query is window-specific.

It may persist during:

- Detail navigation.
- Inspector toggling.
- Layout switching.
- Sort changes.

It may reset when:

- User explicitly clears it.
- Account changes.
- A product-defined destination transition requests a clean collection.

### 11.7 No results

The empty search state provides:

- Query summary.
- Clear Search.
- Clear Filters when active.
- Add Word if the query appears to be a valid word.
- Remote Lookup if local search only was used.

---

## 12. Filtering

### 12.1 Filter categories

Initial filters:

```text
Language
Learning Level
Due State
Favorite
Tags
Topics
Created Date
Last Reviewed Date
Has Notes
```

Later:

```text
Difficulty
Lapse Count
Review Count
Has Audio
Source
```

### 12.2 Language

Options:

- English.
- Chinese.
- All.

### 12.3 Learning level

Supports multi-selection.

The labels must match backend and iOS semantics.

### 12.4 Due state

Examples:

```text
Due now
Due today
Due this week
Not due
Never reviewed
```

### 12.5 Favorite

Options:

- Any.
- Favorites only.
- Not favorite.

### 12.6 Tags and topics

Allow:

- Include any selected tag.
- Include all selected tags.
- Exclude selected tags in a later advanced mode.

The active matching rule must be visible.

### 12.7 Date filters

Provide presets:

```text
Today
Past 7 days
Past 30 days
Custom range
```

### 12.8 Active-filter summary

Example:

```text
English · Level B1–B2 · Due today · 2 tags
```

Users can:

- Remove one filter.
- Clear all.
- Save as Smart List.

### 12.9 Filter persistence

- Persist per collection during the current window session.
- Persist Smart List filters permanently.
- Do not unexpectedly apply a filter from one unrelated system collection to another.

---

## 13. Sorting

### 13.1 Supported sort fields

```text
Word
Meaning
Learning Level
Next Review
Created Date
Updated Date
Last Reviewed
Review Count
Difficulty
```

### 13.2 Default sorts

Suggested:

```text
All Words          Word ascending
Favorites          Word ascending
Recently Added     Created descending
Difficult Words    Difficulty descending
Due Today          Next review ascending
Trash              Deleted date descending
```

### 13.3 Secondary sort

Apply deterministic secondary sorting:

```text
Primary sort
→ canonical word
→ stable identifier
```

Stable order prevents rows from jumping during refresh.

### 13.4 Sort persistence

Remember sort by:

- Collection.
- Window.
- Device.

Smart Lists may define their own default sort.

---

## 14. Selection model

### 14.1 No selection

Detail displays:

- Collection summary.
- Selection guidance.
- Relevant primary action.

Avoid automatically selecting the first result after every query or filter change.

### 14.2 Single selection

Show:

- Full word detail.
- Contextual inspector.
- Word-specific commands.

### 14.3 Multiple selection

Show:

- Selection count.
- Shared attributes where meaningful.
- Batch actions.

Do not display one arbitrary card as though it were the only selection.

### 14.4 Selection preservation

Preserve selection across:

- Sort changes.
- Layout changes.
- Data refresh.
- Inspector visibility changes.
- Updates to selected items.

Clear invalid selected IDs when:

- Cards are permanently deleted.
- Active filters exclude them.
- Account changes.

### 14.5 Select All

`Command + A` applies to:

- The focused text field when editing text.
- Visible collection results when the collection has focus.

The interface should clarify whether Select All means:

- All loaded matching results.
- Every item matching a server-side query.

For large server-backed collections, batch operations should use an explicit query-selection model rather than loading every ID blindly.

---

## 15. Word detail

### 15.1 Detail states

```text
No selection
Loading
Loaded
Locally available
Refreshing
Pending update
Not found
Deleted
Offline unavailable
Error
```

### 15.2 Header

Contains:

- Word or Hanzi.
- Pronunciation or pinyin.
- Audio.
- Favorite.
- Language.
- More menu.

### 15.3 Immediate understanding

Contains:

- Primary meaning.
- Primary example.
- Optional translation.
- Learning level.
- Due state.

### 15.4 Extended content

May contain:

- Additional meanings.
- Additional examples.
- Collocations.
- Synonyms.
- Antonyms.
- Related words.
- Usage notes.

### 15.5 Personal learning

Contains:

- Personal notes.
- Tags.
- Topic.
- Creation date.
- Last reviewed.
- Next review.
- Review summary.

### 15.6 Actions

Primary:

- Play pronunciation.

Secondary:

- Edit.
- Favorite.
- Ask Assistant.
- Practice This Word.
- Open in New Window.

Destructive:

- Move to Trash.
- Delete Permanently when already in Trash.

### 15.7 Related-word navigation

Selecting a related word:

- Opens saved user card if present.
- Otherwise opens a lookup result.
- Never silently adds the word.

### 15.8 Detail loading

If local content exists:

- Show it immediately.
- Refresh in background.
- Avoid replacing it with a spinner.

---

## 16. Inspector

### 16.1 Sections

Recommended:

```text
Learning
Organization
Personal Notes
Review History
Actions
```

### 16.2 Learning

Fields:

- Level.
- Due date.
- Stability.
- Difficulty.
- Review count.
- Lapse count.

Advanced FSRS values may be hidden behind disclosure.

### 16.3 Organization

Fields:

- Favorite.
- Tags.
- Topic.
- Source.
- Created date.

### 16.4 Notes

Personal notes:

- Use plain text in the first release.
- Save explicitly or through reliable debounced autosave.
- Preserve drafts on failure.
- Indicate pending synchronization.

### 16.5 Review history

Show a concise history:

- Timestamp.
- Grade.
- Previous and new scheduling values where understandable.

Do not overwhelm typical users with raw algorithm fields.

### 16.6 Batch inspector

For multiple selection:

- Count.
- Shared language.
- Shared tags.
- Mixed favorite state.
- Add/remove tags.
- Set level if supported.
- Favorite/unfavorite.
- Export.
- Move to Trash.

---

## 17. Add Word flow

### 17.1 Entry points

- Toolbar Add Word.
- `Command + N`.
- File menu.
- Contextual Add from search.
- Quick Lookup.
- Service.
- Import.
- App Intent.

All entry points should use the same domain use case.

### 17.2 Minimal flow

1. Enter word.
2. Select or detect language.
3. Check local and remote duplicates.
4. Lookup existing dictionary content.
5. Preview result.
6. Confirm save.
7. Show saved state.

### 17.3 Add form

Initial fields:

- Word.
- Language.
- Level where user-selectable.
- Tags.
- Topic.
- Personal note.

Generated or dictionary fields:

- Pronunciation or pinyin.
- Meanings.
- Examples.

### 17.4 AI generation

AI content generation:

- Begins only on explicit action.
- Has progress and cancellation.
- Does not destroy manual input.
- Is labeled as generated where appropriate.

### 17.5 Successful add

After save:

- New item appears in relevant collections.
- Selection moves to the new item when Add Word originated in Vocabulary.
- Quick Lookup may remain compact and confirm success.
- Spotlight and widget snapshots update asynchronously.

### 17.6 Add failure

Preserve:

- Word.
- Selected language.
- Tags.
- Notes.
- Generated preview.

Provide:

- Retry.
- Save pending when offline support allows.
- Cancel.

---

## 18. Duplicate handling

### 18.1 Duplicate checks

Check:

- Exact saved user card.
- Normalized equivalent.
- Case variant.
- Pinyin normalization where applicable.
- Existing dictionary entry not yet saved by user.

### 18.2 Existing saved word

Display:

```text
This word is already in your vocabulary.
```

Actions:

- Open Existing.
- Add Tag.
- Update Level.
- Cancel.

Do not create another user card.

### 18.3 Existing dictionary content

If shared content exists but user card does not:

- Reuse shared dictionary content.
- Create only the user's card relationship.
- Allow personal metadata.

### 18.4 Ambiguous variant

When normalized forms match but may represent different language concepts:

- Present candidates.
- Show meanings.
- Require user selection.

### 18.5 Batch duplicates

Import preview classifies:

```text
New
Already Saved
Possible Duplicate
Invalid
```

User may:

- Skip.
- Merge metadata.
- Open existing.

---

## 19. Edit flow

### 19.1 Editable data

User-editable:

- Personal note.
- Tags.
- Topic.
- Favorite.
- Learning level where permitted.
- User-created example if supported.

Dictionary content editing depends on backend ownership and permissions.

### 19.2 Edit presentation

Use:

- Inspector for small metadata changes.
- Sheet or dedicated edit view for broader edits.

### 19.3 Draft behavior

An edit draft:

- Begins from canonical current data.
- Tracks changes.
- Supports cancel.
- Preserves data on save failure.

### 19.4 Concurrent update

If the server changes the item while editing:

- Nonconflicting changes may merge.
- User-authored note conflicts must not silently overwrite.
- The user receives a clear resolution path.

### 19.5 Undo

Local UI actions should use native Undo where feasible:

- Favorite.
- Tags.
- Level.
- Notes.

Undo behavior must remain consistent with synchronization.

---

## 20. Favorites

### 20.1 Toggle locations

- Table.
- List.
- Grid.
- Detail header.
- Inspector.
- Context menu.
- Menu command.

### 20.2 Optimistic update

Favorite may update optimistically when:

- The prior state is known.
- The mutation can be safely retried.
- Failure can restore or mark pending state.

### 20.3 Favorites collection

Unfavoriting inside Favorites:

- Removes the item from the current collection.
- Preserves the user card.
- Preserves selection behavior predictably.

---

## 21. Tags and topics

### 21.1 Tag purpose

Tags support flexible organization:

```text
work
technology
travel
writing
HSK
confusing
```

### 21.2 Topic purpose

Topic represents a broader primary category where the backend supports it.

The relationship between tags and topic must remain clear:

```text
Topic: one broad category
Tags: zero or more flexible labels
```

### 21.3 Tag editor

Features:

- Search existing tags.
- Create tag.
- Keyboard navigation.
- Remove tag.
- Prevent duplicate labels after normalization.

### 21.4 Batch tagging

For multiple selection:

- Add tags to all.
- Remove common tags.
- Show mixed state.

### 21.5 Tag deletion

Deleting a tag:

- Removes organization metadata.
- Does not delete vocabulary.
- Requires confirmation if widely used.

### 21.6 Tag color

Optional tag colors should be deferred unless they provide clear value and pass accessibility requirements.

---

## 22. Personal notes

### 22.1 Purpose

Notes capture user-specific context:

- Why the word matters.
- Workplace usage.
- Memory aid.
- Common mistake.
- Personal example.

### 22.2 Format

First release:

- Plain text.
- Line breaks.
- Searchable if privacy policy allows.

Later:

- Lightweight Markdown.

### 22.3 Save model

Options:

- Explicit Save.
- Debounced autosave with clear state.

Recommended initial behavior:

- Debounced autosave.
- Immediate local persistence.
- Visible pending sync state.
- Recoverable draft on failure.

### 22.4 Privacy

Personal notes:

- Are not indexed in Spotlight by default.
- Are not sent to AI unless explicitly included.
- Are not shown in widgets.
- Are removed during local-data deletion.

---

## 23. Batch operations

### 23.1 Supported initial operations

- Add tags.
- Remove tags.
- Set favorite.
- Remove favorite.
- Export.
- Move to Trash.

Potential later operations:

- Change learning level.
- Assign topic.
- Generate examples.
- Start targeted practice.

### 23.2 Batch-action presentation

When multiple items are selected:

- Toolbar presents common actions.
- Inspector presents shared values.
- Context menu presents batch operations.

### 23.3 Confirmation

Confirm:

- Move many items to Trash.
- Permanent deletion.
- Large AI generation.
- Large export if sensitive content is included.

Do not confirm:

- Add tag.
- Favorite.
- Export ordinary vocabulary.

### 23.4 Partial failure

Batch result reports:

- Succeeded.
- Failed.
- Pending.
- Skipped.

The user can retry failed items without duplicating successful operations.

---

## 24. Context menus

### 24.1 Single item

Recommended:

```text
Open
Open in New Window
Play Pronunciation
Favorite / Remove Favorite
Edit
Add Tag
Ask Assistant
Practice This Word
Export
Move to Trash
```

### 24.2 Multiple items

Recommended:

```text
Add Tag
Remove Tag
Favorite
Remove Favorite
Start Practice
Export
Move to Trash
```

### 24.3 Empty table area

Recommended:

```text
Add Word
Import…
Refresh
```

### 24.4 Command consistency

Context-menu actions must also exist through:

- Menus.
- Toolbar where primary.
- Inspector where contextual.
- Keyboard shortcuts where useful.

---

## 25. Keyboard model

### 25.1 Primary shortcuts

```text
Command + N                 Add Word
Command + F                 Focus collection search
Shift + Command + F         Global search
Command + A                 Select all in focused scope
Command + Return            Open selected word
Space                       Quick preview or pronunciation, final decision required
Command + I                 Show word information if used
Option + Command + I        Toggle inspector
Command + Delete            Move selected words to Trash
Command + Z                 Undo eligible action
Command + R                 Start Review
```

### 25.2 Navigation

```text
Up / Down                   Move table selection
Shift + Up / Down           Extend selection
Command + Up / Down         Move to collection boundary where native
Return                      Open selected item
Escape                      Dismiss transient UI
```

### 25.3 Pronunciation shortcut

The final pronunciation shortcut must avoid conflict with text editing and system commands.

Candidate:

```text
Option + P
```

The shortcut must be available through the Study or Vocabulary menu.

### 25.4 Focus restoration

After:

- Closing detail, focus returns to originating row.
- Dismissing Add Word, focus returns to Add Word control or table.
- Dismissing filter popover, focus returns to Filter.
- Completing tag edit, focus returns to the selected row or inspector control.

---

## 26. Drag and drop

### 26.1 Accepted drops into Vocabulary

- Plain text.
- Rich text.
- URL.
- Image.
- Screenshot.
- PDF.
- CSV.
- JSON.

### 26.2 Drop behavior

Plain word:

- Open Add Word preview.

Sentence or passage:

- Open vocabulary-extraction preview.

Image or PDF:

- Open import and OCR flow.

Vocabulary file:

- Open import mapping and preview.

### 26.3 Dropping on a tag

Potential later behavior:

- Apply the tag to selected or dragged vocabulary items.

This should not be included until drag semantics are visually clear.

### 26.4 Dragging out

Dragging a word from Voca may provide:

- Plain word.
- Word plus meaning.
- Voca deep link.

Do not expose private notes by default.

### 26.5 Drop feedback

Show:

- Accepted type.
- Intended action.
- Unsupported state.

Never process a large document silently.

---

## 27. Smart Lists

### 27.1 Creation

Users can save current:

- Language.
- Search query where supported.
- Filters.
- Sort.

### 27.2 Required fields

- Name.
- Query definition.

Optional:

- Icon.
- Default layout.

### 27.3 Editing

Users can:

- Rename.
- Change query.
- Duplicate.
- Delete.

Deleting a Smart List does not delete vocabulary.

### 27.4 Dynamic behavior

Membership updates automatically when:

- Vocabulary metadata changes.
- Review state changes.
- Synchronization updates content.

### 27.5 Smart List examples

```text
Work English due this week
Chinese words without notes
Frequently missed B2 vocabulary
Favorites added this month
```

### 27.6 Invalid rules

If a referenced tag is deleted:

- Mark the rule for review.
- Do not silently reinterpret it as another tag.
- Keep the Smart List recoverable.

---

## 28. Trash and deletion

### 28.1 Move to Trash

Preferred behavior:

- Removes card from active collections.
- Preserves recoverable state.
- Records deletion time.
- Synchronizes tombstone.

### 28.2 Undo

After moving to Trash:

- Offer transient Undo.
- Preserve selection context when restored.

### 28.3 Restore

Restoring:

- Returns card to active collections.
- Preserves prior metadata.
- Reconciles study state according to backend rules.

### 28.4 Permanent deletion

Requires confirmation showing:

- Number of cards.
- Irreversibility.
- Effect on notes and review history.

### 28.5 Empty Trash

Must:

- Require deliberate confirmation.
- Handle partial server failure.
- Report remaining items.

### 28.6 Backend dependency

Trash requires backend support for:

- Tombstones or soft deletion.
- Restore.
- Permanent delete.
- Sync semantics.

If unavailable, the feature must remain out of scope until the contract is implemented.

---

## 29. English-specific behavior

### 29.1 Identity

Show:

- Word.
- Phonetic transcription.
- Audio.

### 29.2 Content

Potential fields:

- Part of speech.
- Meanings.
- Examples.
- Collocations.
- Synonyms.
- Antonyms.

### 29.3 Search

Support:

- Case-insensitive matching.
- Inflection-aware lookup where backend data permits.
- Exact canonical word prioritization.

### 29.4 Pronunciation

Respect configured English voice.

Display fallback state if audio is unavailable.

---

## 30. Chinese-specific behavior

### 30.1 Identity

Show:

- Hanzi.
- Pinyin.
- Mandarin audio.

### 30.2 Content

Show:

- Vietnamese meaning.
- Example.
- Example pinyin where available.
- Character-level actions.

### 30.3 Search

Support:

- Hanzi.
- Pinyin with tones.
- Pinyin without tone marks.
- Vietnamese meanings.

### 30.4 Character detail

Selecting a character may expose:

- Character.
- Pinyin.
- Stroke count.
- Stroke-order animation.
- Writing practice.

### 30.5 Multi-character words

The word remains the primary vocabulary item.

Character-level detail is supporting information and must not automatically create separate user cards.

---

## 31. Pronunciation

### 31.1 Playback states

```text
Idle
Loading
Playing
Failed
Unavailable
```

### 31.2 Playback ownership

Only one Voca pronunciation plays at a time across:

- Vocabulary.
- Review.
- Quick Lookup.
- Menu bar.

### 31.3 Visual feedback

While playing:

- Audio icon may indicate activity.
- Stop or replay remains available.
- Row layout does not shift.

### 31.4 Failure

Pronunciation failure:

- Does not block other actions.
- Offers Retry.
- Explains offline or provider configuration when relevant.

### 31.5 Cache

If cached audio exists:

- Prefer it.
- Indicate no special state unless stale or invalid.

---

## 32. Offline behavior

### 32.1 Available offline

Previously synchronized:

- Vocabulary list.
- Word detail.
- Tags.
- Notes.
- Learning metadata.
- Cached audio.
- Cached Hanzi resources.

### 32.2 Offline writes

Potentially queue:

- Favorite.
- Tags.
- Notes.
- Supported edits.
- Add word when enough content exists.
- Move to Trash.

Permanent deletion may require online state in the initial release.

### 32.3 Offline indicator

Show one nonblocking collection-level state.

Do not place an offline icon on every row.

### 32.4 Pending row

Show row-level pending state only when:

- A local mutation is awaiting synchronization.
- A failure requires attention.
- A delete is pending.

### 32.5 Data freshness

The user may inspect:

- Last successful synchronization.
- Pending-change count.
- Action-required errors.

---

## 33. Synchronization behavior

### 33.1 Remote additions

New remote words should:

- Enter matching collections.
- Respect current sort.
- Avoid unexpectedly stealing selection.

### 33.2 Remote updates

If selected word changes remotely:

- Update nonediting content.
- Preserve local edit draft.
- Surface conflict only when necessary.

### 33.3 Remote deletion

If selected word is deleted remotely:

- Remove it from active results.
- Show an unavailable or deleted state.
- Do not automatically select an unrelated row.

### 33.4 Search stability

Synchronization must not replace newer query results with stale data.

### 33.5 Batch sync

Large synchronization updates should:

- Apply transactionally.
- Avoid repeated table flicker.
- Preserve valid selections by identifier.

---

## 34. Loading and state presentation

### 34.1 First load without local data

Show:

- Stable window structure.
- Collection loading state.
- Authentication or network error if needed.

### 34.2 Refresh with local data

Keep:

- Rows.
- Selection.
- Scroll position where practical.

Show:

- Subtle refresh state.

### 34.3 Empty collection

All Words:

- Add first word.
- Import.
- Try Quick Lookup.

Favorites:

- Explain favorites.
- Offer navigation to All Words.

Due Today:

- Confirm no cards are due.
- Offer Practice.

Trash:

- State that Trash is empty.

### 34.4 Filtered empty

Show:

- Search query.
- Active filters.
- Clear Search.
- Clear Filters.

---

## 35. Error behavior

### 35.1 Collection load error

If local data exists:

- Keep local data visible.
- Show refresh failure.

If no local data exists:

- Show content error.
- Offer Retry.

### 35.2 Mutation error

Preserve user intent.

Examples:

- Notes remain in draft.
- Favorite returns to prior state or shows pending.
- Tag operation reports failed items.

### 35.3 Authentication error

Move to reauthentication flow while preserving safe window route for restoration after sign-in.

### 35.4 Not found

Show:

- The word is unavailable or deleted.
- Return to Collection.
- Search Vocabulary.

Do not show a generic blank panel.

---

## 36. Accessibility

### 36.1 Table

VoiceOver should identify:

- Column.
- Word.
- Meaning.
- Selected state.
- Favorite state.
- Due state.

### 36.2 Detail

Content order:

1. Identity.
2. Pronunciation.
3. Meaning.
4. Example.
5. Learning state.
6. Additional sections.
7. Actions.

### 36.3 Multi-selection

Announce:

```text
12 vocabulary items selected
```

Batch controls must expose their affected count.

### 36.4 Color

Level, due state, and synchronization must include text or icon semantics.

### 36.5 Keyboard

Every requirement in the keyboard section must work without pointer interaction.

### 36.6 Larger text

At larger text sizes:

- Table may increase row height.
- Detail wraps.
- Inspector labels remain associated with controls.
- Toolbar moves secondary items into overflow.

### 36.7 Pronunciation

Accessible label:

```text
Play pronunciation for {word}
```

Playback state should be announced without continuously interrupting navigation.

---

## 37. Performance

### 37.1 Target datasets

Validate at least:

```text
1,000 cards
10,000 cards
50,000 cards for stress testing
```

Even if typical usage is smaller, architecture must not require rendering every item simultaneously.

### 37.2 Search

- Runs off the main thread.
- Cancels obsolete queries.
- Returns local results promptly.
- Uses indexed fields.

### 37.3 Table

- Uses stable IDs.
- Avoids expensive row-level formatters.
- Caches derived display values where appropriate.
- Does not load full audio or Hanzi resources per row.

### 37.4 Detail

Load heavy data lazily:

- Review history.
- Stroke data.
- Additional AI content.
- Audio.

### 37.5 Batch actions

Use chunking or query-based server operations for large selections.

The UI must remain responsive and cancellable where safe.

---

## 38. Privacy

### 38.1 Search

Local search queries should not be transmitted unless:

- Remote lookup is explicitly required.
- The user invokes AI or remote search.

### 38.2 Notes

Notes are excluded by default from:

- Spotlight.
- Widgets.
- Analytics.
- AI context.

### 38.3 Exports

Export UI must clearly state whether it includes:

- Notes.
- Tags.
- Review metadata.
- Examples.

Credentials are never exported.

### 38.4 Analytics

Allowed:

- Collection opened.
- Layout mode selected.
- Filter used.
- Batch action category.
- Add completed.
- Search performance timing without query content.

Not allowed:

- Search query.
- Word text.
- Meaning.
- Personal note.
- Tag names.
- Exported vocabulary content.

---

## 39. Contextual entry points

### 39.1 From Today

Selecting:

- Recent word opens word detail.
- Difficult Words opens the corresponding collection.
- Due count opens Due Today or Review, based on action label.

### 39.2 From Review

Edit or inspect:

- Opens word detail without corrupting session state.
- Returns to the same review card.

### 39.3 From Assistant

A referenced word:

- Opens saved detail.
- Opens lookup if unsaved.

### 39.4 From Spotlight

Opens canonical word route.

### 39.5 From Quick Lookup

Open Detail:

- Activates main workspace.
- Opens Vocabulary.
- Selects exact word.

### 39.6 From a widget

Word widget:

- Opens exact word.

Due widget:

- Opens Review, not merely the Vocabulary collection, when clearly labeled Start Review.

---

## 40. State model

Illustrative state:

```swift
@MainActor
@Observable
final class VocabularyFeature {
    enum Phase {
        case idle
        case loading
        case loaded
        case failed(AppError)
    }

    private(set) var phase: Phase = .idle
    private(set) var items: [VocabularyItem] = []
    private(set) var totalCount: Int = 0

    var collection: VocabularyCollection = .all
    var language: LanguageScope = .english
    var searchQuery = ""
    var filters = VocabularyFilters()
    var sort = VocabularySort.default
    var layout: VocabularyLayout = .table
    var selection: Set<UserCardID> = []
    var inspectorPresented = true
}
```

The final implementation should distinguish:

- Query state.
- Paginated result state.
- Canonical repository entities.
- Editable drafts.
- Pending mutations.

---

## 41. Repository query model

Illustrative query:

```swift
struct VocabularyQuery: Hashable, Sendable {
    var collection: VocabularyCollection
    var language: LanguageScope
    var searchText: String
    var filters: VocabularyFilters
    var sort: [VocabularySortDescriptor]
    var page: PageRequest
}
```

Result:

```swift
struct VocabularyPage: Sendable {
    var items: [VocabularyItem]
    var totalCount: Int
    var nextCursor: String?
}
```

The UI must not assume all results fit in memory.

---

## 42. Commands

### 42.1 Vocabulary menu

```text
Add Word
Edit Word
Play Pronunciation
Toggle Favorite
Add Tag
Open in New Window
Ask Assistant
Practice This Word
Export Selection
Move to Trash
```

### 42.2 View menu

```text
Table
List
Grid
Show Inspector
Customize Columns…
Compact Density
Comfortable Density
```

### 42.3 File menu

```text
New Word
Import…
Export…
```

### 42.4 Command enablement

Examples:

- Edit requires one selection.
- Play Pronunciation requires one playable selection.
- Batch Tag requires one or more selections.
- Delete requires one or more active selections.
- Restore is enabled only in Trash.

---

## 43. Requirement traceability

### `VOC-001` — Vocabulary table

Covered by:

- Table structure.
- Columns.
- Selection.
- Density.
- Performance.

### `VOC-002` — Search

Covered by:

- Search fields.
- Normalization.
- Ranking.
- Cancellation.
- Empty results.

### `VOC-003` — Filters

Covered by:

- Filter categories.
- Active summary.
- Persistence.
- Clear behavior.

### `VOC-004` — Sort

Covered by:

- Sort fields.
- Collection defaults.
- Stable secondary sorting.

### `VOC-005` — Alternative layouts

Covered by:

- Table.
- List.
- Grid.
- Layout persistence.

### `VOC-006` — Add word

Covered by:

- Entry points.
- Minimal flow.
- AI generation.
- Success and failure.

### `VOC-007` — Edit word

Covered by:

- Editable data.
- Draft.
- Conflict.
- Undo.

### `VOC-008` — Delete and restore

Covered by:

- Trash.
- Undo.
- Restore.
- Permanent deletion.

### `VOC-009` — Favorites

Covered by:

- Toggle locations.
- Optimistic behavior.
- Favorites collection.

### `VOC-010` — Tags and topics

Covered by:

- Tag model.
- Editor.
- Batch tagging.
- Deletion.

### `VOC-011` — Multi-selection

Covered by:

- Selection model.
- Batch actions.
- Batch inspector.

### `VOC-012` — Smart Lists

Covered by:

- Creation.
- Dynamic membership.
- Editing.
- Invalid rules.

### `VOC-013` — Word inspector

Covered by:

- Inspector sections.
- Notes.
- History.
- Batch state.

### `VOC-014` — Separate word window

Covered by:

- Row activation.
- Context menu.
- Canonical word route.

### `LANG-001` through `LANG-005`

Covered by:

- Language selector.
- English behavior.
- Chinese behavior.
- Stroke-order entry point.
- Writing-practice entry point.

---

## 44. Acceptance scenarios

### Scenario A — Search and inspect

1. Open All Words.
2. Press `Command + F`.
3. Search for a word.
4. Move selection using arrow keys.
5. Verify detail updates.
6. Play pronunciation.
7. Clear search.
8. Verify collection is restored.

### Scenario B — Filter and save Smart List

1. Filter English vocabulary to B1 and B2.
2. Add Due This Week.
3. Add a work tag.
4. Sort by Next Review.
5. Save as Smart List.
6. Reopen it after relaunch.
7. Verify dynamic membership.

### Scenario C — Batch tagging

1. Select a range.
2. Add a tag.
3. Verify all selected cards update.
4. Simulate one failed mutation.
5. Verify partial result and targeted retry.

### Scenario D — Add duplicate

1. Add an existing saved word.
2. Verify no duplicate card is created.
3. Open the existing item.
4. Add a new tag.

### Scenario E — Add shared dictionary entry

1. Look up a dictionary word not saved by the user.
2. Confirm save.
3. Verify shared content is reused.
4. Verify user's learning state is created.

### Scenario F — Offline note

1. Disconnect.
2. Edit a personal note.
3. Verify local save and pending status.
4. Relaunch while offline.
5. Verify draft persists.
6. Reconnect.
7. Verify synchronization.

### Scenario G — Chinese vocabulary

1. Switch to Chinese.
2. Search using Hanzi.
3. Search using pinyin without tone marks.
4. Select a result.
5. Play Mandarin pronunciation.
6. Open character stroke order.

### Scenario H — Trash

1. Move selected items to Trash.
2. Undo one operation.
3. Open Trash.
4. Restore one item.
5. Permanently delete another.
6. Verify active collections and synchronization.

### Scenario I — Large collection

1. Load 10,000 items.
2. Scroll rapidly.
3. Search repeatedly.
4. Change sort.
5. Multi-select.
6. Verify UI responsiveness and stable identity.

### Scenario J — Accessibility

1. Enable VoiceOver.
2. Navigate collection and table.
3. Select a word.
4. Read meaning and due state.
5. Add a tag.
6. Play pronunciation.
7. Complete the same workflow with keyboard only.

---

## 45. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Table is the default macOS Vocabulary presentation.
2. List and Grid are optional user-selected presentations.
3. Dictionary entry and user card are separate concepts.
4. Stable user-card IDs own selection.
5. Search and filters are collection-scoped.
6. Smart Lists store rules rather than duplicated cards.
7. Word detail preserves collection context.
8. Inspector owns learning metadata and organization.
9. Editing uses drafts rather than mutating canonical entities directly.
10. Personal notes are excluded from Spotlight, widgets, analytics, and AI by default.
11. Chinese rows display Hanzi and pinyin as a two-line identity.
12. Trash requires backend-supported soft deletion and restore.

---

## 46. Open questions

1. Should All Words default to alphabetic or recently updated order?
2. Should the primary word column include pronunciation by default?
3. Should `Space` open a Quick Look-style preview or play pronunciation?
4. Should double-click open detail in place or a separate window?
5. Should user notes autosave or require explicit Save?
6. Which learning levels are editable by users?
7. Does the backend support soft deletion and restoration?
8. Should search include personal notes by default?
9. Should Smart Lists store free-text search terms?
10. Should tag colors be supported?
11. Should difficult-word rules be server-defined or locally derived?
12. Should All Languages be available in the first release?
13. Should related unsaved words open Quick Lookup or main detail?
14. What maximum batch size should be supported directly?
15. Does the backend require new batch mutation endpoints?
16. Should table-column configuration be synchronized or device-local?
17. Which fields are canonical dictionary data versus user-editable content?
18. Should Trash preserve review history after restore?

---

## 47. Backend and data dependencies

The complete feature may require backend support for:

- Incremental vocabulary sync.
- Stable user-card identifiers.
- Language-aware search or query support.
- Tags and topics.
- Favorite state.
- Personal notes.
- Batch mutations.
- Idempotency keys.
- Soft deletion.
- Restore.
- Permanent deletion.
- Smart Lists if synchronized.
- Review summaries.
- Conflict versioning.

Missing capabilities must be documented before implementation. The macOS client should not silently invent server behavior that other clients cannot honor.

---

## 48. Definition of done

Vocabulary is complete for the first public release when:

- Table, search, filters, and sort work with a realistic large library.
- English and Chinese presentation is correct.
- Single and multi-selection are stable.
- Word detail and inspector are complete.
- Add, edit, favorite, tags, notes, and delete flows work.
- Duplicate creation is prevented.
- Offline local reading works.
- Supported offline changes are safely queued.
- Synchronization preserves valid selection and drafts.
- Primary actions are available through menus and keyboard.
- VoiceOver and larger-text workflows pass.
- Light Mode, Dark Mode, and Increased Contrast pass.
- Critical journeys have automated tests.
- Personal content is not exposed through system integrations without explicit policy.

---

## 49. Next document

The next document should be:

```text
docs/macos-review.md
```

It should define:

- Review eligibility.
- Session creation.
- FSRS grading.
- Prompt and answer models.
- Keyboard interactions.
- Focus Review window.
- English and Chinese card variants.
- Audio behavior.
- Type-in and listening modes.
- Pause, resume, and recovery.
- Offline review.
- Idempotency.
- Session summary.
- Accessibility.
- Performance.
- Acceptance criteria mapped to `REV-*`.
