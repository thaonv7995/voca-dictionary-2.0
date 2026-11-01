# Voca for macOS — Product Requirements

> Detailed product requirements for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Product Requirements Document
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document translates the Voca for macOS product vision into:

- User problems.
- Target users.
- User journeys.
- Functional requirements.
- Non-functional requirements.
- Release priorities.
- Acceptance criteria.
- Scope boundaries.
- Product risks.
- Measurable success conditions.

This document defines **what the product must achieve**. Technical implementation details belong in `macos-architecture.md`, while detailed layouts and navigation belong in `macos-information-architecture.md`.

---

## 2. Product summary

Voca for macOS is a native language-learning workspace designed around two complementary usage modes.

### 2.1 Workspace mode

The main application provides:

- Daily learning dashboard.
- Vocabulary library.
- FSRS review sessions.
- Reading, listening, writing, and conversation practice.
- AI-assisted vocabulary learning.
- Learning insights.
- Import, export, and collection management.

### 2.2 Ambient mode

The application remains available while the user works in other applications through:

- Global Quick Lookup.
- Menu bar companion.
- macOS Services.
- Spotlight.
- Shortcuts.
- App Intents.
- Widgets.
- Notifications.

The transition between ambient mode and workspace mode must be seamless.

---

## 3. Problem statement

Language learners frequently encounter unfamiliar words while:

- Browsing the web.
- Reading documents.
- Working with email.
- Reading technical documentation.
- Writing content.
- Reviewing PDFs.
- Watching or listening to learning material.

Current workflows commonly require the learner to:

1. Leave the current application.
2. Open a dictionary or browser.
3. Search manually.
4. Copy a definition.
5. Open a flashcard application.
6. Create and organize a card.
7. Remember to review the card later.

This workflow is slow and disruptive. It also separates discovery, understanding, storage, and retention into unrelated tools.

Voca for macOS should unify these steps into one learning loop:

```text
Encounter → Understand → Save → Review → Practice → Retain
```

---

## 4. Product principles

### PRN-001: Capture must not interrupt the user's current task

The fastest vocabulary-capture flows should work without opening or navigating the main application.

### PRN-002: The Mac application must behave like a Mac application

The application must use native window, menu, toolbar, table, inspector, keyboard-focus, drag-and-drop, and Settings conventions.

### PRN-003: Saved vocabulary must lead to learning

Saving a word is not the end of the workflow. Every saved word should be available for review, examples, practice, and progress tracking.

### PRN-004: AI must remain contextual and intentional

AI should assist explicit learning tasks and use visible context. The interface must not treat generic chat as the product's primary experience.

### PRN-005: Important workflows must work from the keyboard

Users must be able to search, navigate, add words, begin reviews, reveal answers, grade cards, and invoke commands without using the pointer.

### PRN-006: Offline behavior must be understandable

Users must know when data is local, synchronized, pending, or blocked by an error.

### PRN-007: Privacy-sensitive features must be opt-in

Clipboard monitoring, document analysis, and AI transmission must be explicit and understandable.

### PRN-008: iOS compatibility must not limit macOS quality

Domain behavior should be shared where valuable. macOS interaction and information architecture should remain platform-specific.

---

## 5. Target users

### 5.1 Persona A: The knowledge worker

#### Profile

- Uses the Mac throughout the workday.
- Reads English technical documentation, email, and workplace content.
- Encounters unfamiliar words in context.
- Does not want to interrupt work to maintain flashcards.

#### Primary needs

- Fast lookup.
- Immediate pronunciation.
- One-step saving.
- Minimal notifications.
- Useful work-related examples.
- Background availability.

#### Success condition

The user can understand and save a word in less than ten seconds without leaving the current application.

### 5.2 Persona B: The dedicated learner

#### Profile

- Studies on a schedule.
- Maintains a growing vocabulary library.
- Uses spaced repetition.
- Wants measurable progress.

#### Primary needs

- Daily study plan.
- Reliable review scheduling.
- Focused sessions.
- Progress and retention insights.
- Reading and listening exercises.

#### Success condition

The user can open Voca and begin the most relevant daily learning activity immediately.

### 5.3 Persona C: The power user

#### Profile

- Prefers keyboard navigation and automation.
- Imports and manages substantial vocabulary collections.
- Uses Shortcuts or other macOS automation.
- Expects efficient batch operations.

#### Primary needs

- Command Palette.
- Customizable shortcuts.
- Smart Lists.
- Bulk editing.
- Import and export.
- Multiple windows.
- App Intents.

#### Success condition

The user can manage a large library without repetitive manual navigation.

### 5.4 Persona D: The Chinese learner

#### Profile

- Studies Hanzi and Mandarin.
- Needs more than a translated definition.
- Practices writing, listening, and character recognition.

#### Primary needs

- Hanzi and pinyin.
- Mandarin pronunciation.
- Vietnamese meaning.
- Stroke order.
- Writing practice.
- Character-focused examples.

#### Success condition

The user can study the visual, phonetic, semantic, and writing aspects of a Chinese word in a connected workflow.

---

## 6. Jobs to be done

### JTBD-001: Understand a word immediately

When I encounter an unfamiliar word, I want a concise explanation and pronunciation without leaving my current task.

### JTBD-002: Save a word for later learning

When a word is relevant, I want to add it to my vocabulary with minimal manual data entry.

### JTBD-003: Know what to study today

When I open Voca, I want to see what needs attention and begin promptly.

### JTBD-004: Retain saved vocabulary

When words become due, I want efficient FSRS review sessions with meaningful answer controls.

### JTBD-005: Use vocabulary in context

When I recognize a word but cannot use it naturally, I want examples, comparisons, exercises, and conversation practice.

### JTBD-006: Process vocabulary from documents

When I have a PDF, screenshot, image, article, or passage, I want Voca to identify useful unfamiliar words and help me save selected items.

### JTBD-007: Understand progress

When I invest time in learning, I want clear evidence of retention, growth, consistency, and weak areas.

### JTBD-008: Automate repeated workflows

When I repeatedly add or review vocabulary, I want to invoke Voca through keyboard shortcuts, Spotlight, Services, and Shortcuts.

---

## 7. Requirement conventions

Each requirement uses the following fields:

- **ID:** Stable requirement identifier.
- **Priority:** P0, P1, P2, or P3.
- **Requirement:** Product behavior.
- **Acceptance:** Observable completion criteria.

Priority meaning:

- **P0:** Required for the first usable native product.
- **P1:** Required for a complete first public release.
- **P2:** High-value macOS differentiation.
- **P3:** Advanced or later enhancement.

---

## 8. Application foundation requirements

### APP-001 — Native macOS application

- **Priority:** P0
- **Requirement:** Voca must run as a native macOS application and use native desktop interaction patterns.
- **Acceptance:**
  - The application launches as a standard macOS application.
  - It has a standard application menu.
  - It supports normal window movement, resizing, minimization, and restoration.
  - It supports Light Mode and Dark Mode.
  - It does not require a browser window.

### APP-002 — Deployment target

- **Priority:** P0
- **Requirement:** The application must define and enforce a documented minimum macOS version.
- **Acceptance:**
  - The deployment target is declared in project configuration.
  - Unsupported API usage is detected during build.
  - The selected target is documented with the rationale.

### APP-003 — Main window

- **Priority:** P0
- **Requirement:** The primary workspace must use a desktop-oriented navigation and content layout.
- **Acceptance:**
  - The window presents primary navigation.
  - The content area changes based on the selected destination.
  - A contextual inspector can be shown or hidden.
  - The window remains usable at the documented minimum size.
  - The layout expands appropriately on large displays.

### APP-004 — Window state restoration

- **Priority:** P1
- **Requirement:** Voca should restore relevant window state between launches.
- **Acceptance:**
  - The main window restores its size and position.
  - The selected primary destination is restored when appropriate.
  - Sidebar and inspector visibility are restored.
  - Restoration never bypasses authentication requirements.

### APP-005 — Multiple windows

- **Priority:** P3
- **Requirement:** The user should be able to open selected words or workspaces in separate windows.
- **Acceptance:**
  - A word can be opened in a separate window.
  - Closing a secondary window does not close the main workspace.
  - Multiple windows preserve independent selections where expected.

### APP-006 — Standard menus

- **Priority:** P0
- **Requirement:** Primary actions must be available in standard macOS menus.
- **Acceptance:**
  - File, Edit, View, Study, Vocabulary, Window, and Help commands are organized consistently.
  - Disabled commands reflect the current context.
  - Menu commands expose their keyboard shortcuts.

### APP-007 — Command Palette

- **Priority:** P3
- **Requirement:** Users should be able to search for and execute application commands from a Command Palette.
- **Acceptance:**
  - `Command + K` opens the palette by default.
  - Commands can be filtered by typing.
  - Results include navigation and contextual actions.
  - Recent commands are discoverable.

---

## 9. Authentication and account requirements

### AUTH-001 — Sign in

- **Priority:** P0
- **Requirement:** Existing Voca users must be able to sign in using the current backend.
- **Acceptance:**
  - Valid credentials open the authenticated workspace.
  - Invalid credentials produce a clear inline error.
  - A network failure is distinguishable from invalid credentials.
  - Password fields use secure text entry.

### AUTH-002 — Registration

- **Priority:** P1
- **Requirement:** New users should be able to create an account where backend policy permits.
- **Acceptance:**
  - Required fields are validated before submission.
  - Server validation errors are mapped to understandable messages.
  - Successful registration leads to an authenticated or clearly defined verification flow.

### AUTH-003 — Session persistence

- **Priority:** P0
- **Requirement:** Authentication should persist securely across launches.
- **Acceptance:**
  - Credentials are stored in Keychain.
  - Expired access credentials are refreshed using the existing rotation flow.
  - Refresh failure returns the user to sign in without exposing sensitive details.

### AUTH-004 — Sign out

- **Priority:** P0
- **Requirement:** Users must be able to sign out from the application menu and account settings.
- **Acceptance:**
  - Server logout is attempted where supported.
  - Local credentials are removed.
  - Private authenticated content is dismissed.
  - The behavior of cached local learning data is explained.

### AUTH-005 — Server configuration

- **Priority:** P1
- **Requirement:** Development and advanced users should be able to use a configured backend URL.
- **Acceptance:**
  - Production uses the approved default URL.
  - Development builds can use a local backend.
  - Invalid URLs are rejected.
  - Authentication credentials remain isolated from unrelated server configurations.

---

## 10. Today requirements

### TODAY-001 — Daily summary

- **Priority:** P0
- **Requirement:** Today must summarize the user's immediate learning workload.
- **Acceptance:**
  - The due-card count is visible.
  - Daily-goal progress is visible.
  - The primary Start Review action is prominent.
  - Empty and completed-day states are meaningful.

### TODAY-002 — Continue learning

- **Priority:** P1
- **Requirement:** Users should be able to resume an incomplete or recent learning activity.
- **Acceptance:**
  - A paused review session can be resumed when session data remains valid.
  - The destination and activity type are clearly named.
  - Stale server state is handled without data loss.

### TODAY-003 — Difficult cards

- **Priority:** P1
- **Requirement:** Today should identify cards that need additional attention.
- **Acceptance:**
  - Difficult-card criteria are documented.
  - Users can open the resulting collection.
  - Users can start a focused practice activity from it.

### TODAY-004 — Suggested practice

- **Priority:** P1
- **Requirement:** Today should recommend a relevant practice activity.
- **Acceptance:**
  - Recommendations reflect due cards, weak topics, or recent vocabulary.
  - The reason for a recommendation is understandable.
  - The user can dismiss or replace a recommendation.

### TODAY-005 — Weekly summary

- **Priority:** P2
- **Requirement:** Today should provide a compact view of recent learning consistency.
- **Acceptance:**
  - Reviews, learning time, or completed goals are summarized.
  - The summary does not overwhelm the primary daily action.
  - The user can open detailed Insights.

---

## 11. Vocabulary requirements

### VOC-001 — Vocabulary table

- **Priority:** P0
- **Requirement:** Vocabulary must be manageable through a native desktop table.
- **Acceptance:**
  - Rows represent user vocabulary entries.
  - Columns can include word, pronunciation, meaning, level, due date, tags, and created date.
  - Supported columns can be sorted.
  - Columns can be resized.
  - Selection follows macOS behavior.
  - Large libraries remain responsive.

### VOC-002 — Search

- **Priority:** P0
- **Requirement:** Users must be able to search vocabulary quickly.
- **Acceptance:**
  - Search supports word text.
  - Search supports relevant meanings where local data permits.
  - Search updates without blocking the interface.
  - Clearing the query restores the previous unfiltered state.
  - Keyboard focus can move to search through a shortcut.

### VOC-003 — Filters

- **Priority:** P0
- **Requirement:** Vocabulary must support structured filtering.
- **Acceptance:**
  - Users can filter by language.
  - Users can filter by learning level.
  - Users can filter by due status.
  - Users can filter by favorites.
  - Users can filter by tag or topic where supported.
  - Active filters remain visible.
  - All filters can be cleared in one action.

### VOC-004 — Sort

- **Priority:** P0
- **Requirement:** Users must be able to order vocabulary by useful fields.
- **Acceptance:**
  - Sort supports common fields such as word, created date, level, and next review.
  - Sort direction is visible.
  - Sorting remains consistent with filtering and search.

### VOC-005 — Alternative layouts

- **Priority:** P2
- **Requirement:** Users should be able to switch between table, list, and grid views.
- **Acceptance:**
  - Table remains the desktop default.
  - Selection is preserved when practical.
  - View choice is remembered.
  - All layouts expose the same underlying collection.

### VOC-006 — Add word

- **Priority:** P0
- **Requirement:** Users must be able to add English and Chinese vocabulary.
- **Acceptance:**
  - Required input is clearly identified.
  - Existing words are detected before duplicate creation.
  - AI-assisted generation remains explicit.
  - The saved word appears in the vocabulary library.
  - Validation failures preserve entered data.

### VOC-007 — Edit word

- **Priority:** P0
- **Requirement:** Users must be able to edit supported vocabulary content and personal metadata.
- **Acceptance:**
  - Editable and server-generated fields are distinguishable.
  - Changes can be saved or cancelled.
  - Validation errors are shown next to the relevant field.
  - Successful changes appear everywhere the word is displayed.

### VOC-008 — Delete and restore

- **Priority:** P0
- **Requirement:** Users must be able to remove vocabulary safely.
- **Acceptance:**
  - Destructive actions are clearly marked.
  - Accidental deletion has an undo or Trash-based recovery path where technically feasible.
  - Batch deletion requires stronger confirmation.
  - Deletion synchronizes correctly.

### VOC-009 — Favorites

- **Priority:** P1
- **Requirement:** Users should be able to mark words as favorites.
- **Acceptance:**
  - Favorite state can be toggled from the table or detail.
  - Favorites are filterable.
  - Favorite state synchronizes across devices.

### VOC-010 — Tags and topics

- **Priority:** P1
- **Requirement:** Users should be able to organize vocabulary with tags and topics.
- **Acceptance:**
  - Tags can be added or removed.
  - Existing tags can be reused.
  - Tags can be applied to multiple selected items.
  - Tag filtering is available.

### VOC-011 — Multi-selection

- **Priority:** P1
- **Requirement:** The vocabulary workspace must support native multi-selection.
- **Acceptance:**
  - Shift-click and Command-click behave as expected.
  - The toolbar or context menu exposes valid batch actions.
  - Destructive batch actions show the number of affected items.

### VOC-012 — Smart Lists

- **Priority:** P3
- **Requirement:** Users should be able to save reusable filter and sort combinations.
- **Acceptance:**
  - A current query can be saved with a name.
  - Smart Lists appear in navigation.
  - Updating a Smart List does not duplicate vocabulary.
  - A Smart List can be renamed or deleted.

### VOC-013 — Word inspector

- **Priority:** P0
- **Requirement:** Selecting a vocabulary item should show contextual detail without forcing navigation away from the list.
- **Acceptance:**
  - The inspector shows essential word data.
  - Pronunciation is available.
  - Learning state is visible.
  - Edit, favorite, AI, and additional actions are available.
  - The inspector can be hidden.

### VOC-014 — Separate word window

- **Priority:** P3
- **Requirement:** A word should be openable in a separate window.
- **Acceptance:**
  - The window has a stable identity based on the vocabulary item.
  - Multiple different words can be open.
  - Updates remain consistent with the main window.

---

## 12. English and Chinese requirements

### LANG-001 — Language mode

- **Priority:** P0
- **Requirement:** Users must be able to switch between English and Chinese vocabulary.
- **Acceptance:**
  - The current language is visible.
  - Search and filters work within the selected mode.
  - Switching does not lose the current user's data.
  - Combined views explicitly identify language.

### LANG-002 — English content

- **Priority:** P0
- **Requirement:** English entries must support pronunciation, meanings, examples, and learning metadata.
- **Acceptance:**
  - Phonetic information is displayed where available.
  - English pronunciation plays through the selected voice.
  - Examples remain readable and selectable.

### LANG-003 — Chinese content

- **Priority:** P0
- **Requirement:** Chinese entries must support Hanzi, pinyin, Vietnamese meaning, examples, and learning metadata.
- **Acceptance:**
  - Hanzi receives visual priority.
  - Pinyin is displayed correctly.
  - Mandarin pronunciation is available.
  - Chinese content is not forced into an English-only layout.

### LANG-004 — Stroke order

- **Priority:** P1
- **Requirement:** Chinese word detail should present stroke-order animation for supported characters.
- **Acceptance:**
  - Each supported character can be selected.
  - Animation can be started, paused, and restarted.
  - Missing stroke data has a graceful state.
  - Cached data remains available offline after download.

### LANG-005 — Writing practice

- **Priority:** P2
- **Requirement:** Users should be able to practice writing Chinese characters.
- **Acceptance:**
  - The practice area accepts pointer or trackpad input.
  - The guide can be cleared.
  - Reference strokes can be shown or hidden.
  - The feature remains usable without requiring perfect handwriting recognition.

---

## 13. Review requirements

### REV-001 — Due queue

- **Priority:** P0
- **Requirement:** Users must be able to start a review session from due vocabulary.
- **Acceptance:**
  - The due count matches server-defined review eligibility.
  - Starting a session creates a stable queue.
  - Deleted or invalid cards are handled safely.
  - English and Chinese queues are identifiable.

### REV-002 — Reveal answer

- **Priority:** P0
- **Requirement:** A review card must support prompt and revealed states.
- **Acceptance:**
  - The answer is not shown before reveal unless the review mode requires it.
  - Space reveals the answer.
  - Pointer interaction can also reveal the answer.
  - Reveal state is announced accessibly.

### REV-003 — FSRS grading

- **Priority:** P0
- **Requirement:** Users must be able to grade cards as Again, Hard, Good, or Easy.
- **Acceptance:**
  - The four grades map to the backend review contract.
  - Keys 1 through 4 activate the grades after reveal.
  - Accidental duplicate submission is prevented.
  - The next card appears without disruptive delay.

### REV-004 — Pronunciation

- **Priority:** P0
- **Requirement:** Review sessions must support pronunciation playback.
- **Acceptance:**
  - Pronunciation can be played through keyboard or pointer.
  - Auto-play is configurable.
  - Playback failure does not block grading.
  - The selected language voice is respected.

### REV-005 — Session progress

- **Priority:** P0
- **Requirement:** Users must understand review-session progress without unnecessary distraction.
- **Acceptance:**
  - Remaining or completed-card progress is visible.
  - Progress does not reveal private answer content.
  - The interface avoids overly celebratory interruptions between cards.

### REV-006 — Pause and resume

- **Priority:** P1
- **Requirement:** Users should be able to pause a review session.
- **Acceptance:**
  - Completed grades remain recorded.
  - Remaining cards can be resumed when valid.
  - The user can discard a session deliberately.
  - Application termination does not create duplicate reviews.

### REV-007 — Focus mode

- **Priority:** P1
- **Requirement:** Review should offer a distraction-reduced presentation.
- **Acceptance:**
  - Navigation and unrelated controls are hidden or minimized.
  - Essential actions remain accessible.
  - The user can exit focus mode at any time.

### REV-008 — Review modes

- **Priority:** P2
- **Requirement:** Review should support additional modes beyond recognition.
- **Acceptance:**
  - Type-in answer mode is available.
  - Listening-first mode is available.
  - Mode selection is clear before or during session setup.
  - Grades still use the same learning-state contract.

### REV-009 — Session summary

- **Priority:** P1
- **Requirement:** Completing a session should produce a useful summary.
- **Acceptance:**
  - Reviewed-card count is shown.
  - Accuracy or grade distribution is shown.
  - Difficult cards can be opened.
  - The user can return to Today or begin targeted practice.

---

## 14. Quick Lookup requirements

### QUICK-001 — Global invocation

- **Priority:** P2
- **Requirement:** Quick Lookup must be invokable through a configurable global keyboard shortcut.
- **Acceptance:**
  - The default shortcut is documented.
  - The panel can appear while another application is active.
  - Shortcut registration failure is reported.
  - The shortcut can be changed or disabled.

### QUICK-002 — Immediate text entry

- **Priority:** P2
- **Requirement:** The search field must be ready immediately when Quick Lookup opens.
- **Acceptance:**
  - Keyboard input goes directly to the search field.
  - Existing stale queries are handled according to documented behavior.
  - Escape dismisses the panel.

### QUICK-003 — Concise lookup result

- **Priority:** P2
- **Requirement:** Quick Lookup must display the minimum information needed to understand a word.
- **Acceptance:**
  - Word, pronunciation, concise meaning, and example are shown where available.
  - Loading, no-result, offline, and error states are distinct.
  - The result remains readable in a compact panel.

### QUICK-004 — Quick save

- **Priority:** P2
- **Requirement:** Users must be able to save a lookup result without opening the main window.
- **Acceptance:**
  - The save action indicates success.
  - Existing vocabulary is detected.
  - Network failure preserves the user's intent where offline queuing is available.

### QUICK-005 — Open full detail

- **Priority:** P2
- **Requirement:** Users must be able to continue from Quick Lookup to full word detail.
- **Acceptance:**
  - The main application opens or activates.
  - The correct word is selected.
  - The Quick Lookup panel dismisses according to expected behavior.

### QUICK-006 — Clipboard suggestion

- **Priority:** P3
- **Requirement:** Quick Lookup may suggest useful clipboard text without automatically submitting it.
- **Acceptance:**
  - The behavior is configurable.
  - Clipboard content is not sent to the network before user action.
  - Unsupported or sensitive-looking content is not automatically inserted.

### QUICK-007 — Multi-display behavior

- **Priority:** P2
- **Requirement:** Quick Lookup must appear in a predictable location across multiple monitors and Spaces.
- **Acceptance:**
  - The panel appears on the active display.
  - It remains fully inside the visible frame.
  - Full-screen spaces are tested.

---

## 15. Menu bar requirements

### MENU-001 — Optional menu bar item

- **Priority:** P2
- **Requirement:** Users should be able to enable or disable the menu bar companion.
- **Acceptance:**
  - The preference is available in Settings.
  - Disabling it removes the item without affecting the main application.
  - State is preserved across launches.

### MENU-002 — Due count

- **Priority:** P2
- **Requirement:** The menu bar should communicate due-card state without creating persistent visual pressure.
- **Acceptance:**
  - Due count or status follows a documented display policy.
  - Users can hide numeric count.
  - The value updates after reviews and synchronization.

### MENU-003 — Quick actions

- **Priority:** P2
- **Requirement:** The menu bar panel should provide common lightweight actions.
- **Acceptance:**
  - Quick Lookup is available.
  - Quick Add is available.
  - Start Review is available.
  - Open Voca is available.

### MENU-004 — Mini review

- **Priority:** P2
- **Requirement:** Users should be able to review a small number of cards from the menu bar panel.
- **Acceptance:**
  - The session size is intentionally limited.
  - Reveal and grading controls are usable in the compact surface.
  - Review results use the same FSRS behavior as the main application.

---

## 16. Practice and AI requirements

### AI-001 — Contextual assistant

- **Priority:** P1
- **Requirement:** The assistant must make its active learning context visible.
- **Acceptance:**
  - Users can see whether context comes from a word, selection, Smart List, or imported text.
  - Context can be removed.
  - Sending a request is explicit.

### AI-002 — Streaming responses

- **Priority:** P1
- **Requirement:** AI responses should stream when supported by the backend.
- **Acceptance:**
  - Partial content appears progressively.
  - The user can cancel generation.
  - Cancellation does not corrupt conversation state.
  - Stream failure produces a retryable state.

### AI-003 — Explain word

- **Priority:** P1
- **Requirement:** Users should be able to request a contextual explanation of a word.
- **Acceptance:**
  - The request includes the selected word.
  - The explanation matches the active language.
  - Generated content is visually distinguished from stored vocabulary data.

### AI-004 — Compare words

- **Priority:** P1
- **Requirement:** Users should be able to compare commonly confused words.
- **Acceptance:**
  - Two or more words can be selected.
  - Differences are presented with examples.
  - Relevant compared words can be added to vocabulary.

### AI-005 — Drills

- **Priority:** P1
- **Requirement:** Users should be able to generate structured exercises from selected vocabulary.
- **Acceptance:**
  - Drill context is selected before generation.
  - Questions have identifiable answer choices.
  - Correctness feedback is provided.
  - Audio is supported where generated content allows it.

### AI-006 — Reading practice

- **Priority:** P1
- **Requirement:** Users should be able to generate reading passages grounded in their vocabulary.
- **Acceptance:**
  - Target level or difficulty can be selected.
  - Target vocabulary is identifiable.
  - Comprehension questions are available.
  - Words in the passage can be looked up.

### AI-007 — Conversation practice

- **Priority:** P1
- **Requirement:** Users should be able to practice a guided conversation.
- **Acceptance:**
  - A scenario or role can be selected.
  - The user can enter responses.
  - Corrections are available.
  - Useful vocabulary can be saved.
  - A session summary is generated.

### AI-008 — AI privacy

- **Priority:** P0
- **Requirement:** Users must understand when their content will be processed by an AI provider.
- **Acceptance:**
  - AI actions are explicit.
  - Large imported content receives an appropriate preview or warning.
  - AI features can be disabled.
  - Sensitive credentials are never displayed after storage.

---

## 17. Import and capture requirements

### CAP-001 — Drag and drop

- **Priority:** P2
- **Requirement:** The application must accept supported content through drag and drop.
- **Acceptance:**
  - Supported types are visually indicated during drag.
  - Unsupported types are rejected clearly.
  - Dropped content opens a preview or appropriate workflow.
  - Dropping content never silently creates a large collection.

### CAP-002 — Text capture

- **Priority:** P2
- **Requirement:** Users should be able to process pasted or dropped text.
- **Acceptance:**
  - Language can be detected or selected.
  - Existing vocabulary is identified.
  - Candidate words can be selected individually or in bulk.
  - Saving occurs only after confirmation.

### CAP-003 — Image OCR

- **Priority:** P2
- **Requirement:** Users should be able to extract vocabulary from images and screenshots.
- **Acceptance:**
  - OCR processing has a visible progress state.
  - Extracted text can be reviewed.
  - Recognition errors can be corrected.
  - Candidate words can be selected before creation.

### CAP-004 — PDF extraction

- **Priority:** P3
- **Requirement:** Users should be able to extract vocabulary from PDFs.
- **Acceptance:**
  - Text-based PDFs are supported.
  - Scanned PDFs may use OCR where feasible.
  - Large documents show progress.
  - The user can cancel processing.
  - Extracted content is not uploaded to AI without explicit action.

### CAP-005 — CSV and JSON import

- **Priority:** P1
- **Requirement:** Users should be able to import supported vocabulary files.
- **Acceptance:**
  - File structure is validated.
  - CSV columns can be mapped.
  - A preview shows valid, invalid, and duplicate rows.
  - Import produces a completion summary.

### CAP-006 — Export

- **Priority:** P1
- **Requirement:** Users should be able to export all or selected vocabulary.
- **Acceptance:**
  - Supported export formats are documented.
  - Selection scope is clear.
  - Export uses a standard save panel.
  - Sensitive account credentials are never included.

### CAP-007 — macOS Services

- **Priority:** P2
- **Requirement:** Voca should provide useful actions for selected text in compatible applications.
- **Acceptance:**
  - Look Up in Voca is available.
  - Add to Voca is available.
  - Explain with Voca is available where AI is enabled.
  - Empty or extremely large selections are handled.

---

## 18. System integration requirements

### SYS-001 — Spotlight indexing

- **Priority:** P2
- **Requirement:** Saved vocabulary should be discoverable through Spotlight.
- **Acceptance:**
  - Eligible vocabulary is indexed.
  - A result shows a useful title and description.
  - Selecting the result opens the exact word.
  - Deleted vocabulary is removed from the index.
  - Sign-out behavior is documented.

### SYS-002 — App Intents

- **Priority:** P2
- **Requirement:** Core Voca actions should be exposed through App Intents.
- **Acceptance:**
  - Add Word is available.
  - Look Up Word is available.
  - Show Due Count is available.
  - Start Review or Open Today's Session is available.
  - Intent execution reuses application domain services.

### SYS-003 — Shortcuts

- **Priority:** P2
- **Requirement:** Users should be able to include Voca actions in Shortcuts workflows.
- **Acceptance:**
  - Actions have understandable names and parameters.
  - Output values are useful to subsequent actions.
  - Authentication-required actions return actionable errors.

### SYS-004 — Widgets

- **Priority:** P2
- **Requirement:** Voca should provide useful desktop and Notification Center widgets.
- **Acceptance:**
  - Due count is available.
  - Word of the day is available.
  - Daily-goal progress is available.
  - Widget data updates after meaningful changes.
  - Private content exposure is configurable.

### SYS-005 — Notifications

- **Priority:** P1
- **Requirement:** Review reminders must be useful, configurable, and non-spammy.
- **Acceptance:**
  - Notifications require permission.
  - Reminder schedule is configurable.
  - The same overdue state does not create excessive duplicate notifications.
  - Notifications can open the relevant review flow.
  - Notification content respects privacy preferences.

### SYS-006 — Launch at login

- **Priority:** P2
- **Requirement:** Users should be able to launch Voca at login, primarily to enable ambient features.
- **Acceptance:**
  - The setting is optional.
  - It uses the supported macOS mechanism.
  - Disabling it removes the login behavior.

---

## 19. Insights requirements

### INS-001 — Learning summary

- **Priority:** P1
- **Requirement:** Users should see a clear summary of recent learning activity.
- **Acceptance:**
  - Reviewed cards are summarized.
  - Added vocabulary is summarized.
  - Goal completion is summarized.
  - Date range is visible.

### INS-002 — Retention

- **Priority:** P1
- **Requirement:** Users should be able to understand retention trends.
- **Acceptance:**
  - Metric definitions are available.
  - Insufficient-data states are handled.
  - The report avoids presenting false precision.

### INS-003 — Difficult vocabulary

- **Priority:** P1
- **Requirement:** Users should be able to identify frequently lapsed or difficult cards.
- **Acceptance:**
  - The identification criteria are consistent.
  - Users can open the resulting collection.
  - Users can start targeted review or practice.

### INS-004 — Forecast

- **Priority:** P2
- **Requirement:** Users should be able to view an approximate upcoming review workload.
- **Acceptance:**
  - Forecast period is visible.
  - Forecast is labeled as an estimate.
  - English and Chinese can be distinguished.

### INS-005 — Accessible data visualization

- **Priority:** P0
- **Requirement:** Charts must provide non-visual alternatives.
- **Acceptance:**
  - VoiceOver receives meaningful summaries.
  - Important values are not represented only by color.
  - Increased Contrast remains usable.
  - Tabular or textual summaries are available where appropriate.

---

## 20. Settings requirements

### SET-001 — General settings

- **Priority:** P0
- **Requirement:** Users must be able to configure basic application behavior.
- **Acceptance:**
  - Appearance preference is available where necessary.
  - Default start destination is configurable.
  - Language preference is visible.
  - Settings persist across launches.

### SET-002 — Study settings

- **Priority:** P1
- **Requirement:** Users should be able to configure study behavior.
- **Acceptance:**
  - Daily goal is configurable.
  - Reminder behavior is configurable.
  - Audio auto-play is configurable.
  - Review session size is configurable where supported.

### SET-003 — Speech settings

- **Priority:** P1
- **Requirement:** Users should be able to configure speech behavior.
- **Acceptance:**
  - English and Mandarin voices can be selected independently where available.
  - Speech speed is adjustable.
  - A preview action is available.

### SET-004 — AI settings

- **Priority:** P1
- **Requirement:** Users should be able to configure supported AI providers and models.
- **Acceptance:**
  - Credentials are stored securely.
  - Saved secrets are not revealed in plain text.
  - Connection or validation failure is understandable.
  - AI features can be disabled.

### SET-005 — Integration settings

- **Priority:** P2
- **Requirement:** Users should control macOS integration features.
- **Acceptance:**
  - Global shortcut can be changed.
  - Menu bar item can be disabled.
  - Launch at login can be changed.
  - Spotlight indexing behavior is documented.
  - Clipboard assistant can be disabled or paused.

### SET-006 — Storage and diagnostics

- **Priority:** P1
- **Requirement:** Users should be able to understand and manage local storage.
- **Acceptance:**
  - Cached-data size is shown where practical.
  - Audio and temporary caches can be cleared.
  - Diagnostics can be exported without credentials.
  - Local application data can be removed through a deliberate flow.

---

## 21. Offline and synchronization requirements

### SYNC-001 — Offline vocabulary access

- **Priority:** P1
- **Requirement:** Previously synchronized vocabulary should remain readable offline.
- **Acceptance:**
  - The vocabulary library loads without a network connection.
  - Word detail remains available for synchronized fields.
  - Offline state is visible without blocking use.

### SYNC-002 — Offline review

- **Priority:** P1
- **Requirement:** Eligible cached review sessions should remain usable offline.
- **Acceptance:**
  - The application can create or use a valid local due queue.
  - Grades are queued.
  - Reconnection does not submit duplicate review events.
  - Server conflicts have a documented resolution policy.

### SYNC-003 — Pending mutation queue

- **Priority:** P1
- **Requirement:** Supported offline changes must be queued for synchronization.
- **Acceptance:**
  - Pending changes survive application restart.
  - Retry uses bounded backoff.
  - Permanently failed operations appear in Activity.
  - The user can retry appropriate failures.

### SYNC-004 — Sync status

- **Priority:** P1
- **Requirement:** Users must be able to understand synchronization state.
- **Acceptance:**
  - Synced, syncing, offline, pending, and action-required states are distinguishable.
  - Normal successful sync does not produce disruptive alerts.
  - Last successful synchronization is available.

### SYNC-005 — Conflict handling

- **Priority:** P1
- **Requirement:** Conflicting changes must not be resolved silently when doing so could destroy user-authored data.
- **Acceptance:**
  - Automatic conflict rules are documented.
  - User-authored notes receive appropriate protection.
  - Unresolved conflict state is recoverable.

---

## 22. Accessibility requirements

### A11Y-001 — Full keyboard operation

- **Priority:** P0
- **Requirement:** All primary workflows must be operable from the keyboard.
- **Acceptance:**
  - Primary navigation is keyboard accessible.
  - Tables support keyboard selection.
  - Review can be completed without a pointer.
  - Focus is visible.
  - Keyboard traps do not occur.

### A11Y-002 — VoiceOver

- **Priority:** P0
- **Requirement:** Primary views and controls must provide meaningful VoiceOver output.
- **Acceptance:**
  - Controls have meaningful labels.
  - Repeated icons are distinguishable.
  - Review state changes are announced appropriately.
  - Charts have summaries.

### A11Y-003 — Contrast and color

- **Priority:** P0
- **Requirement:** The interface must remain understandable without relying on color alone.
- **Acceptance:**
  - Important states include text, icon, or shape distinctions.
  - Increased Contrast is usable.
  - Light and Dark Mode meet the documented contrast standard.

### A11Y-004 — Reduced motion

- **Priority:** P0
- **Requirement:** Non-essential motion must respect Reduce Motion.
- **Acceptance:**
  - Large transitions are simplified.
  - Learning feedback remains understandable.
  - Stroke-order animation remains user-controlled.

### A11Y-005 — Text size

- **Priority:** P1
- **Requirement:** Essential content must remain readable with larger accessibility text settings.
- **Acceptance:**
  - Definitions and examples wrap rather than truncate unnecessarily.
  - Primary actions remain reachable.
  - The minimum supported window size is reviewed with larger text.

---

## 23. Privacy and security requirements

### SEC-001 — Keychain

- **Priority:** P0
- **Requirement:** Authentication and provider credentials must be stored in Keychain.
- **Acceptance:**
  - Secrets are absent from plain-text preference files.
  - Secrets are absent from exported diagnostics.
  - Sign out removes relevant local credentials.

### SEC-002 — Logging

- **Priority:** P0
- **Requirement:** Logs must avoid sensitive user data.
- **Acceptance:**
  - Authorization headers are redacted.
  - Passwords and API keys are never logged.
  - Document content is not logged by default.
  - Diagnostic export has a redaction review.

### SEC-003 — Clipboard privacy

- **Priority:** P0
- **Requirement:** Clipboard monitoring must be disabled by default and require explicit consent.
- **Acceptance:**
  - Enabling explains the behavior.
  - A visible pause or disable action exists.
  - Clipboard content is not persisted unless saved.
  - Clipboard content is not sent automatically.

### SEC-004 — AI transmission

- **Priority:** P0
- **Requirement:** User content must only be sent to an AI provider as part of an explicit AI action.
- **Acceptance:**
  - Passive browsing does not send content.
  - Document-analysis actions clearly identify their scope.
  - AI can be disabled.

### SEC-005 — Local-data removal

- **Priority:** P1
- **Requirement:** Users must be able to remove locally stored Voca data.
- **Acceptance:**
  - The action describes what will be deleted.
  - Account deletion is not implied unless explicitly supported.
  - The application returns to an appropriate signed-out or clean state.

---

## 24. Performance requirements

### PERF-001 — Application launch

- **Priority:** P0
- **Requirement:** The application should become interactable promptly on supported hardware.
- **Acceptance:**
  - Launch performance is measured in release builds.
  - Slow initialization does not freeze the window.
  - Non-essential synchronization is deferred.

### PERF-002 — Vocabulary search

- **Priority:** P0
- **Requirement:** Search must feel immediate for typical personal libraries.
- **Acceptance:**
  - Search work does not block the main thread.
  - Rapid query changes do not display stale results.
  - A large-library benchmark is defined.

### PERF-003 — Quick Lookup

- **Priority:** P2
- **Requirement:** Quick Lookup must appear immediately and begin local search before remote work completes.
- **Acceptance:**
  - Panel presentation is independent from network latency.
  - Cached or local results appear first.
  - Remote enrichment has a clear loading state.

### PERF-004 — Memory

- **Priority:** P1
- **Requirement:** Background and menu bar operation must not retain unnecessary feature state.
- **Acceptance:**
  - Large imported documents are released after processing.
  - Audio cache follows its storage policy.
  - Memory usage is profiled during long sessions.

### PERF-005 — Energy

- **Priority:** P1
- **Requirement:** Background features must minimize energy use.
- **Acceptance:**
  - Clipboard behavior does not rely on aggressive polling.
  - Synchronization avoids unnecessary repeated requests.
  - Menu bar operation is profiled for idle energy impact.

---

## 25. Reliability requirements

### REL-001 — Error states

- **Priority:** P0
- **Requirement:** User-facing failures must provide an actionable next step.
- **Acceptance:**
  - Network, authentication, validation, and server failures are distinguishable.
  - Retrying does not duplicate successful operations.
  - Unsaved user input is preserved where practical.

### REL-002 — Crash recovery

- **Priority:** P1
- **Requirement:** Important local user state should survive unexpected termination.
- **Acceptance:**
  - Pending offline operations persist safely.
  - Completed review grades are not lost after acknowledgement.
  - Temporary import state is either recoverable or explicitly disposable.

### REL-003 — Backward API compatibility

- **Priority:** P0
- **Requirement:** The macOS client must use supported backend contracts and handle compatible server evolution.
- **Acceptance:**
  - Unknown optional fields do not break decoding.
  - Required incompatibilities produce a clear upgrade message.
  - API behavior is covered by integration tests.

---

## 26. Localization requirements

### LOC-001 — Interface localization

- **Priority:** P1
- **Requirement:** User-facing interface text must be localizable.
- **Acceptance:**
  - User-facing strings are not embedded throughout feature logic.
  - Layouts tolerate longer translated text.
  - Vietnamese and English interface support can be added without architectural rework.

### LOC-002 — Learning-language separation

- **Priority:** P0
- **Requirement:** Interface language and learning language must remain independent.
- **Acceptance:**
  - Switching the vocabulary language does not change the interface language.
  - English and Chinese content use appropriate formatting.

---

## 27. Primary user journeys

### Journey A — First launch and sign in

1. User opens Voca.
2. Voca presents sign-in.
3. User enters credentials.
4. Voca authenticates.
5. Initial synchronization begins.
6. The main workspace opens.
7. Today identifies the next useful action.

#### Success criteria

- Errors are understandable.
- Initial synchronization does not block the complete interface unnecessarily.
- The user reaches working vocabulary or a meaningful empty state.

### Journey B — Global word lookup and save

1. User encounters a word in another application.
2. User invokes Quick Lookup.
3. User enters or confirms the word.
4. Voca shows a concise result.
5. User plays pronunciation.
6. User saves the word.
7. Voca confirms success.
8. User dismisses Quick Lookup and resumes the original task.

#### Success criteria

- No main-window navigation is required.
- Existing vocabulary is detected.
- Network failure does not produce duplicate saves.

### Journey C — Daily review

1. User opens Voca or invokes Start Review.
2. Voca creates the due queue.
3. User reads the prompt.
4. User reveals the answer.
5. User grades the card.
6. Voca records the review.
7. User completes or pauses the session.
8. Voca shows a summary.

#### Success criteria

- The full session is keyboard operable.
- Each grade is submitted once.
- Progress is preserved.

### Journey D — Manage vocabulary

1. User opens Vocabulary.
2. User searches or filters.
3. User selects a word.
4. Inspector displays detail.
5. User edits tags, favorite state, notes, or supported content.
6. Voca saves and synchronizes changes.

#### Success criteria

- The list position is preserved.
- Changes appear consistently in detail, Quick Lookup, and review.

### Journey E — Extract vocabulary from a document

1. User drops a PDF, image, or text into Voca.
2. Voca identifies the input type.
3. Text is extracted.
4. Language is detected or chosen.
5. Candidate words are displayed.
6. Existing vocabulary is identified.
7. User selects desired words.
8. User reviews generated content.
9. Voca creates the confirmed entries.

#### Success criteria

- Nothing is created before confirmation.
- The operation can be cancelled.
- AI upload is explicit.

### Journey F — Practice difficult words

1. User opens Today or Insights.
2. Voca identifies difficult words.
3. User chooses a drill, reading, or conversation activity.
4. Generated content uses the selected words.
5. User completes the activity.
6. Voca shows feedback.
7. User can review relevant word details.

#### Success criteria

- The source vocabulary is visible.
- Generated content does not alter FSRS state unless a defined review action occurs.

---

## 28. First public release scope

### Included

- Native macOS application.
- Authentication and secure session persistence.
- Today dashboard.
- Vocabulary table.
- Search, sort, and filters.
- Word detail and inspector.
- Add, edit, delete, favorite, and tags.
- English and Chinese.
- TTS.
- FSRS reviews.
- Review keyboard shortcuts.
- Session summary.
- Basic practice and assistant flows.
- Local vocabulary cache.
- Basic offline queue and sync status.
- Settings.
- Notifications.
- Accessibility baseline.
- CSV and JSON import/export.
- Signed and notarized distribution.

### Targeted for macOS differentiation release

- Global Quick Lookup.
- Menu bar companion.
- App Intents.
- Shortcuts.
- Spotlight.
- Services.
- Widgets.
- Drag-and-drop OCR.

These may be included in the first public release if the foundation is stable, but they must not compromise vocabulary and review reliability.

### Excluded from initial release

- Public social profiles.
- Shared or collaborative decks.
- Team administration.
- Browser-extension dependency.
- On-device language-model hosting.
- Real-time multi-user editing.
- Complete Anki package compatibility unless separately specified.
- Fully automated clipboard uploads.

---

## 29. Prototype requirements

The first technical prototype must include:

- Native macOS app target.
- Authentication against the existing backend.
- Main window with sidebar.
- Vocabulary table.
- Search.
- Word selection.
- Inspector or detail view.
- Pronunciation.
- English and Chinese data rendering.
- Keyboard navigation.
- Light and Dark Mode.

The prototype does not require:

- Final visual polish.
- Offline mutation sync.
- Menu bar.
- Quick Lookup.
- Widgets.
- Full AI workspace.
- Release packaging.

### Prototype acceptance

The prototype is approved when:

1. Existing users can sign in.
2. The vocabulary library loads.
3. Search and selection feel responsive.
4. Word detail is correct for English and Chinese.
5. Pronunciation works.
6. Keyboard navigation works.
7. The iOS application remains buildable.
8. The implementation demonstrates a viable shared-code boundary.

---

## 30. Product acceptance gates

### Gate 1 — Foundation

- Native app lifecycle is stable.
- Authentication works.
- Main navigation works.
- Accessibility foundation is present.

### Gate 2 — Vocabulary

- Core vocabulary CRUD works.
- Search and filters work.
- English and Chinese render correctly.
- TTS works.

### Gate 3 — Learning

- Due queue is correct.
- Reviews are submitted exactly once.
- Session pause and completion behavior is reliable.
- Today provides an actionable daily workflow.

### Gate 4 — Offline and synchronization

- Cached vocabulary works offline.
- Pending changes survive restart.
- Sync status is understandable.
- Conflict policy is tested.

### Gate 5 — macOS integration

- Quick Lookup is reliable.
- Global shortcut is configurable.
- Menu bar does not create excessive background load.
- Spotlight and Intents respect account and privacy state.

### Gate 6 — Production

- Accessibility audit passes.
- Critical UI tests pass.
- Crash-free and performance targets are met.
- App is signed and notarized.
- Data-removal and diagnostic flows are verified.

---

## 31. Open product decisions

The following decisions require dedicated investigation or specification:

1. Whether the minimum target remains macOS 14 or moves to a later version.
2. Whether Today or Vocabulary is the default first screen.
3. Whether Quick Lookup uses a utility panel, menu bar window, or another window style.
4. Whether Services, Share Extension, or App Intents provide the most reliable selected-text workflow.
5. Whether all user vocabulary is indexed in Spotlight by default.
6. Whether review session state is primarily server-owned or locally snapshotted.
7. Whether deleted vocabulary uses a recoverable Trash state or immediate backend deletion.
8. Which local persistence technology best supports synchronization.
9. Which import/export formats are guaranteed in the first public release.
10. Whether menu bar operation requires launch at login.
11. How AI conversation history is stored and synchronized.
12. Whether user notes are encrypted locally.
13. Whether clipboard suggestions are part of the first integration release.
14. Whether word detail uses the inspector, primary detail column, or both at each window width.
15. Whether separate word windows are included before the public release.

These decisions should be recorded in `macos-decisions.md`.

---

## 32. Dependencies

The macOS product depends on:

- Existing backend availability.
- Stable authentication and token-refresh contracts.
- Vocabulary APIs.
- Review and FSRS APIs.
- TTS and audio APIs.
- AI streaming APIs.
- User settings APIs.
- English and Chinese content support.
- A documented local persistence strategy.
- Apple signing and distribution setup.

Backend gaps discovered during design must be tracked explicitly rather than worked around silently in the UI.

---

## 33. Success metrics

### Activation

- Time to first successful sign-in.
- Time to first saved word.
- Percentage of new users completing a first review.

### Capture

- Median Quick Lookup completion time.
- Percentage of lookups converted into saved vocabulary.
- Number of words added through system integrations.
- Duplicate-prevention rate.

### Learning

- Review completion rate.
- Weekly review frequency.
- Daily-goal completion.
- Retention trend.
- Difficult-card recovery.

### Engagement

- Weekly active learners.
- Use of Today.
- Use of practice activities.
- Use of menu bar and Quick Lookup.

### Quality

- Crash-free sessions.
- Authentication failure rate.
- Sync success rate.
- Duplicate mutation rate.
- Search latency.
- Quick Lookup presentation latency.
- Accessibility defect count.

Metrics must not require collecting sensitive document, clipboard, or AI-prompt content.

---

## 34. Requirement traceability

Detailed feature documents should reference the requirement IDs in this document.

Examples:

- `macos-vocabulary.md` should map designs to `VOC-*`.
- `macos-review.md` should map behavior to `REV-*`.
- `macos-quick-lookup.md` should map behavior to `QUICK-*`.
- `macos-menu-bar.md` should map behavior to `MENU-*`.
- `macos-system-integrations.md` should map behavior to `SYS-*`.
- `macos-data-and-sync.md` should map behavior to `SYNC-*`.
- `macos-security-and-privacy.md` should map controls to `SEC-*`.

A feature must not be considered complete solely because its interface exists. Its acceptance criteria and relevant non-functional requirements must also pass.

---

## 35. Next documents

The next detailed documents should be produced in this order:

1. `macos-information-architecture.md`
2. `macos-architecture.md`
3. `macos-design-system.md`
4. `macos-vocabulary.md`
5. `macos-review.md`
6. `macos-today.md`
7. `macos-data-and-sync.md`
8. `macos-quick-lookup.md`
9. `macos-menu-bar.md`
10. `macos-system-integrations.md`

The Information Architecture document should now turn the requirements above into:

- Window types.
- Navigation hierarchy.
- Sidebar structure.
- Routes.
- Inspector ownership.
- Selection behavior.
- Deep links.
- Restoration rules.
- Compact and expanded window states.
