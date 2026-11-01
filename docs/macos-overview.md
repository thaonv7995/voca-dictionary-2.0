# Voca for macOS

> Product vision, experience principles, feature scope, technical direction, delivery roadmap, and documentation map for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Purpose:** Product and technical overview
- **Target platform:** macOS 14 or later
- **Primary UI technology:** SwiftUI
- **Project:** Voca Dictionary
- **Last updated:** 2026-10-24

---

## 1. Executive summary

Voca for macOS will be a native language-learning workspace that integrates deeply with the Mac rather than simply reproducing the iOS interface on a larger screen.

The application will combine:

- A complete vocabulary library.
- FSRS-based spaced repetition.
- English and Chinese learning.
- Pronunciation and listening practice.
- AI-assisted explanations, exercises, reading, and conversation.
- Document, image, PDF, and clipboard-based vocabulary capture.
- Native macOS productivity features such as global keyboard shortcuts, menu bar access, app services, Spotlight, Shortcuts, widgets, multiple windows, drag and drop, and command menus.

The core product promise is:

> Voca should be available at the moment a learner encounters a new word, without forcing them to interrupt their current workflow.

Voca for macOS therefore has two complementary modes:

1. **Workspace mode:** a full desktop application for managing vocabulary, studying, practicing, and reviewing learning insights.
2. **Ambient mode:** lightweight access through Quick Lookup, the menu bar, Services, Spotlight, widgets, and Shortcuts.

The project should use a native SwiftUI macOS target. Networking, authentication, language models, FSRS behavior, API contracts, TTS, and other reusable logic should be shared with the existing iOS application where practical. The macOS user experience itself must be designed independently around desktop interaction patterns.

---

## 2. Product vision

### 2.1 Vision statement

Voca for macOS is a native language-learning companion that turns words encountered during everyday computer use into durable knowledge.

It should feel like a natural part of macOS:

- Fast enough to invoke while reading or writing.
- Quiet enough to remain available in the background.
- Powerful enough to serve as the primary vocabulary workspace.
- Keyboard-friendly for proficient users.
- Accessible to learners who prefer pointer, VoiceOver, or reduced motion.
- Reliable when the network is unavailable.

### 2.2 Product positioning

Voca for macOS is not:

- A stretched iPhone interface.
- A browser window inside a desktop shell.
- A generic AI chatbot with vocabulary features.
- A dictionary that stops at displaying definitions.
- A flashcard application that requires all content to be entered manually.

Voca for macOS is:

- A capture tool for words from any workflow.
- A structured personal vocabulary database.
- A spaced-repetition learning environment.
- A practice studio for reading, listening, speaking, and writing.
- An AI assistant grounded in the learner's own vocabulary.
- A system-integrated macOS productivity application.

### 2.3 Primary value loop

The core loop is:

1. The learner encounters an unfamiliar word.
2. The learner invokes Voca without leaving the current task.
3. Voca provides a concise explanation and pronunciation.
4. The learner saves the word with minimal effort.
5. Voca schedules the word using FSRS.
6. The learner reviews it in a focused session.
7. Voca reinforces it through examples, reading, listening, and conversation.
8. Learning data improves future recommendations.

Every major product decision should strengthen this loop.

---

## 3. Product goals

### 3.1 Primary goals

#### Goal A: Capture vocabulary with minimal interruption

Users should be able to look up and save a word from almost anywhere on macOS in a few seconds.

Key capabilities:

- Global Quick Lookup.
- Add from selected text.
- Add from clipboard.
- Add from Services.
- Drag and drop text, images, and documents.
- OCR and document vocabulary extraction.

#### Goal B: Provide a best-in-class desktop learning workspace

The main application should make excellent use of:

- Large displays.
- Multiple columns.
- Data tables.
- Inspectors.
- Keyboard navigation.
- Context menus.
- Multiple windows.
- Batch operations.

#### Goal C: Turn saved words into long-term knowledge

The application should connect capture directly to:

- FSRS reviews.
- Listening exercises.
- Generated examples.
- Reading practice.
- Conversation practice.
- Progress insights.

#### Goal D: Integrate deeply with macOS

Native system integrations are core product features, not optional extras:

- Menu bar.
- App Intents.
- Shortcuts.
- Spotlight.
- Services.
- Widgets.
- Notifications.
- Quick Look-style previews.
- Share extension where useful.

#### Goal E: Reuse proven iOS and backend behavior

The macOS application should share reliable domain behavior with the existing iOS application instead of implementing incompatible versions of:

- Authentication.
- API networking.
- Token refresh.
- Vocabulary models.
- FSRS state.
- AI streaming.
- TTS.
- User settings.
- English and Chinese language modes.

### 3.2 Non-goals for the first release

The first release does not need:

- Full replacement of every backend administrative screen.
- Collaborative vocabulary libraries.
- Social feeds or public profiles.
- A browser extension, unless system-level capture proves insufficient.
- Fully local large-language-model inference.
- A custom cross-platform UI framework.
- Perfect feature parity with every iOS-only interaction.

These features may be considered later, but they should not delay the native macOS foundation.

---

## 4. Target users

### 4.1 Knowledge workers

People who encounter English or Chinese while using:

- Browsers.
- Email.
- Documents.
- IDEs.
- Technical documentation.
- Research papers.
- Workplace chat.

Their priority is fast lookup and low-friction capture.

### 4.2 Dedicated language learners

People who actively study vocabulary every day and need:

- Structured reviews.
- Daily goals.
- Learning statistics.
- Reading and listening exercises.
- Clear progress tracking.

### 4.3 Advanced and power users

People who prefer:

- Keyboard-driven workflows.
- Automation.
- Shortcuts.
- Multiple windows.
- Smart filters.
- Batch import and export.
- Configurable behavior.

### 4.4 Chinese learners

People who need:

- Hanzi.
- Pinyin.
- Vietnamese meanings.
- Mandarin pronunciation.
- Stroke order.
- Writing practice.
- Character components and related words.

---

## 5. Experience principles

### 5.1 Native before custom

Use established macOS components and behavior before inventing custom alternatives:

- Native toolbar.
- Native sidebar.
- Native table.
- Native inspector.
- Standard menus.
- Standard Settings window.
- Context menus.
- Keyboard focus and selection conventions.

Customization should reinforce Voca's identity without making the application behave unlike a Mac app.

### 5.2 Fast paths remain short

Common actions should take very few steps:

- Global hotkey to lookup.
- Return to save.
- Space to reveal an answer.
- Number keys to grade a review.
- One command to start the next study session.

### 5.3 Progressive disclosure

Show the information needed for the current task first.

Examples:

- Quick Lookup shows a concise result and a few actions.
- The vocabulary table shows scannable fields.
- The inspector contains secondary metadata.
- Full AI analysis appears only when requested.

### 5.4 Keyboard and pointer are equal citizens

Every primary workflow should support:

- Pointer interaction.
- Keyboard navigation.
- Discoverable shortcuts.
- Focus indication.
- Context menus.
- Menu bar commands.

### 5.5 AI supports learning, not noise

AI should perform explicit learning tasks:

- Explain.
- Compare.
- Generate examples.
- Create exercises.
- Analyze a passage.
- Simulate a conversation.

It should not dominate the interface or turn every screen into a chatbot.

### 5.6 Privacy is visible

Users should understand:

- What data stays on the Mac.
- What data is sent to the backend.
- What content is sent to an AI provider.
- Whether clipboard monitoring is enabled.
- How to clear local data.

### 5.7 Offline behavior is intentional

Previously synchronized vocabulary and scheduled reviews should remain useful without a network connection. Offline actions should be queued and synchronized later.

---

## 6. Information architecture

### 6.1 Primary navigation

The main sidebar will include:

1. **Today**
2. **Vocabulary**
3. **Review**
4. **Practice**
5. **Assistant**
6. **Conversation**
7. **Insights**
8. **Favorites**
9. **Smart Lists**
10. **Trash**

The exact number of sidebar entries may be reduced during implementation by grouping secondary destinations.

### 6.2 Main window structure

The primary window uses a desktop-oriented three-column layout:

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Toolbar                                                              │
├────────────────┬────────────────────────────┬────────────────────────┤
│ Sidebar        │ Content                    │ Detail / Inspector     │
│                │                            │                        │
│ Navigation     │ Dashboard, table, list,    │ Selected word, study  │
│ and smart      │ session, conversation,     │ metadata, actions,    │
│ collections    │ or reports                 │ and contextual tools  │
└────────────────┴────────────────────────────┴────────────────────────┘
```

The inspector should be optional and remember its visibility per window where appropriate.

### 6.3 Secondary surfaces

Voca will also provide:

- Quick Lookup panel.
- Menu bar panel.
- Settings window.
- Focus Review window.
- Add Word window or sheet.
- Import preview window.
- Activity and synchronization window.
- Individual word windows.
- Widget surfaces.

---

## 7. Core product areas

### 7.1 Today

Today is the daily action center.

It should include:

- Due-card count.
- Daily goal progress.
- Start Review action.
- Recent vocabulary.
- Difficult cards.
- Suggested practice.
- Current streak.
- Weekly learning summary.
- English and Chinese progress.
- Continue Recent Session action.

The screen should prioritize an immediate next action over decorative analytics.

### 7.2 Vocabulary

Vocabulary is the primary desktop management workspace.

Required capabilities:

- Table, list, and grid presentations.
- Search.
- Language filter.
- Level filter.
- Topic and tag filters.
- Date filters.
- Sortable and resizable table columns.
- Multiple selection.
- Batch actions.
- Context menus.
- Drag and drop.
- Smart Lists.
- Favorites.
- Recently added and recently reviewed views.
- Duplicate detection.
- Import and export.

The table view should be the default on macOS.

### 7.3 Word detail

Word detail should support:

- Word or Hanzi.
- Phonetic transcription or pinyin.
- Pronunciation.
- Meanings.
- Examples.
- Collocations.
- Synonyms and antonyms.
- Personal notes.
- Tags and topics.
- Learning level.
- FSRS metadata.
- Next review time.
- Review history.
- Related words.
- AI actions.
- Hanzi stroke order and writing practice.

A word may be shown in:

- The inspector.
- The main detail column.
- A separate window.
- Quick Lookup.
- Spotlight results.

### 7.4 Review

The review experience should support:

- FSRS grading.
- Again, Hard, Good, and Easy.
- Keyboard-first interaction.
- Type-in answers.
- Listening prompts.
- Auto-play pronunciation.
- Session size selection.
- Pause and resume.
- Focus mode.
- Error review.
- End-of-session summary.

Essential shortcuts:

```text
Space       Reveal answer
1           Again
2           Hard
3           Good
4           Easy
P           Play pronunciation
E           Edit card
A           Ask AI
Escape      Pause or close session
```

### 7.5 Practice

Practice combines structured AI-assisted exercises:

- Multiple-choice drills.
- Reading comprehension.
- Listening comprehension.
- Sentence completion.
- Word distinction.
- Error correction.
- Article-based practice.
- English and Chinese modes.

Exercises should be grounded in:

- Selected vocabulary.
- A Smart List.
- Due cards.
- Difficult cards.
- A user-selected topic.
- Imported content.

### 7.6 Assistant

Assistant is a contextual learning workspace, not a generic chat screen.

It should support:

- Explain a word.
- Compare similar words.
- Generate contextual examples.
- Correct a sentence.
- Create a quiz.
- Create a reading passage.
- Analyze selected text.
- Extract useful vocabulary.
- Reference selected Voca cards.

The interface should expose the active context so users understand what the assistant is using.

### 7.7 Conversation

Conversation practice should support:

- Scenario selection.
- Role selection.
- Text-based conversation.
- Optional speech input.
- TTS responses.
- Vocabulary targets.
- Corrections after each response or at session end.
- Session summary.
- Suggested words to save.

### 7.8 Insights

Insights should help users make learning decisions.

Key reports:

- Retention.
- Vocabulary growth.
- Due-card forecast.
- Accuracy by level.
- Accuracy by tag or topic.
- Difficult words.
- Review consistency.
- Listening performance.
- Time spent.
- Streak calendar.
- English versus Chinese activity.

Charts must remain understandable with VoiceOver, increased contrast, and color-blind accessibility settings.

---

## 8. Signature macOS experiences

### 8.1 Global Quick Lookup

Quick Lookup is the highest-priority differentiating feature.

Default invocation:

```text
Option + Space
```

The panel should:

- Appear above the active application.
- Focus its search field immediately.
- Optionally detect useful clipboard text.
- Search local data first.
- Query the backend when necessary.
- Display pronunciation, concise meanings, and an example.
- Add the word without opening the main application.
- Offer Ask AI and Open Detail actions.
- Close with Escape.
- Work across multiple Spaces and displays.

Potential interaction:

```text
┌────────────────────────────────────────────────────┐
│ Search or paste a word…                            │
├────────────────────────────────────────────────────┤
│ concise                                      🔊    │
│ /kənˈsaɪs/                                         │
│ brief but comprehensive                            │
│                                                    │
│ Keep your explanation concise.                     │
│                                                    │
│ Add to Voca      Ask AI      Open Detail           │
└────────────────────────────────────────────────────┘
```

### 8.2 Menu bar companion

The menu bar experience should provide:

- Due-card count.
- Quick Lookup.
- Quick Add.
- Review five cards.
- Word of the day.
- Pronunciation.
- Reminder controls.
- Synchronization state.
- Open Voca.

The menu bar item should be optional.

### 8.3 Services and selected text

Voca should expose actions for selected text in compatible macOS applications:

- Look Up in Voca.
- Add to Voca.
- Explain with Voca.
- Extract Vocabulary with Voca.

This workflow should be evaluated against a Share Extension and App Intents to select the most reliable system integration.

### 8.4 Spotlight

Indexed vocabulary should be discoverable through Spotlight.

A Spotlight result should:

- Display the word and concise meaning.
- Identify Voca as the source.
- Open the exact word.
- Support relevant actions where the platform permits.

### 8.5 Shortcuts and App Intents

Planned actions:

- Add Word.
- Look Up Word.
- Pronounce Word.
- Show Due Count.
- Start Review.
- Review Five Cards.
- Explain Text.
- Generate Quiz.
- Open Today's Session.

These actions should reuse the same domain services as the main application.

### 8.6 Desktop widgets

Candidate widgets:

- Word of the day.
- Due-card count.
- Streak.
- Daily goal.
- Interactive flashcard.
- Today summary.
- Start Review.

### 8.7 Drag and drop

Accepted content:

- Plain text.
- Rich text.
- URLs.
- Images.
- Screenshots.
- PDFs.
- CSV.
- JSON.
- Supported vocabulary exports.

Dropped content should open an import or extraction preview instead of immediately creating uncontrolled data.

### 8.8 OCR and document extraction

Voca should support:

- Image OCR.
- Screenshot OCR.
- PDF text extraction.
- Language detection.
- Highlighting words not already in the library.
- Batch selection.
- Duplicate detection.
- AI-assisted card generation.
- Review before saving.

### 8.9 Optional clipboard assistant

Clipboard support must be opt-in.

Requirements:

- Disabled by default.
- Clear privacy explanation.
- Local filtering before any network request.
- Pause control.
- Application exclusions where feasible.
- No automatic content upload.
- No sensitive clipboard logging.

---

## 9. Command and menu model

### 9.1 Main application menu

```text
Voca
  About Voca
  Settings…
  Sign Out
  Quit Voca

File
  New Word
  New Window
  Import…
  Export…
  Close

Edit
  Undo
  Redo
  Cut
  Copy
  Paste
  Find

View
  Show Sidebar
  Show Inspector
  Table View
  List View
  Grid View
  Enter Focus Session

Study
  Start Review
  Review Five Cards
  Reveal Answer
  Again
  Hard
  Good
  Easy
  Play Pronunciation

Vocabulary
  Add Word
  Edit Word
  Add Tag
  Toggle Favorite
  Delete

Window
  Main Window
  Quick Lookup
  Activity
```

### 9.2 Keyboard shortcuts

Proposed defaults:

```text
Command + N                 Add word
Command + K                 Command Palette
Option + Space              Global Quick Lookup
Command + F                 Search current context
Shift + Command + F         Global search
Command + R                 Start review
Option + Command + I        Toggle inspector
Command + ,                 Open Settings
```

Shortcuts must avoid conflicts with common macOS and accessibility commands. Global shortcuts should be configurable.

### 9.3 Command Palette

The Command Palette provides keyboard access to:

- Navigation.
- Add Word.
- Quick Lookup.
- Start Review.
- Open Smart List.
- Switch language.
- Import.
- Export.
- Toggle layout.
- Toggle inspector.
- Ask Assistant.
- Open Settings.

---

## 10. Visual design direction

### 10.1 Visual character

The visual style should be:

- Native.
- Calm.
- Focused.
- Content-led.
- Precise.
- Warm enough for daily learning.

### 10.2 Brand use

The existing green brand should remain but function primarily as:

- Accent color.
- Primary action color.
- Positive progress indicator.
- Active learning state.

Large saturated surfaces should be avoided in productivity views.

### 10.3 Layout

Desktop layouts should favor:

- Clear hierarchy.
- Moderate information density.
- Resizable columns.
- Stable controls.
- Consistent toolbar behavior.
- Minimal unnecessary cards.

Not every section needs a rounded container.

### 10.4 Typography

- Use the system font for interface text.
- Support Dynamic Type behavior available on macOS.
- Allocate additional line height for definitions and examples.
- Use appropriate system CJK fonts for Chinese.
- Never encode meaning solely through font weight or color.

### 10.5 Motion

Motion should:

- Explain transitions.
- Preserve context.
- Be short.
- Respect Reduce Motion.
- Avoid distracting animation during review.

---

## 11. Accessibility

Accessibility is part of the foundation, not a release-end audit.

Required areas:

- Complete VoiceOver labels.
- Logical focus order.
- Keyboard access to all primary actions.
- Visible focus indicators.
- Reduced motion.
- Increased contrast.
- Color-independent state indicators.
- Scalable interface text.
- Accessible chart summaries.
- Meaningful labels for pronunciation controls.
- Correct reading order in tables and inspectors.

Automated tests should cover accessibility identifiers for critical user journeys.

---

## 12. Offline and synchronization model

### 12.1 Local availability

The local store should contain:

- Vocabulary cards.
- User-card relationships.
- Tags and topics.
- FSRS state.
- Due-card queue.
- Recent activity.
- User preferences.
- Cached audio metadata.
- Hanzi stroke data.
- Pending offline operations.

### 12.2 Synchronization behavior

The sync system should provide:

- Incremental pull.
- Incremental push.
- Offline mutation queue.
- Retry with backoff.
- Idempotent mutations.
- Conflict detection.
- Conflict-resolution policy.
- Last successful synchronization time.
- User-visible error state.

### 12.3 User experience

The UI should distinguish:

- Synced.
- Syncing.
- Offline.
- Pending changes.
- Action required.

Routine synchronization should remain quiet. Errors that require user action should be visible in an Activity view.

---

## 13. Privacy and security

### 13.1 Credentials

- Store access and refresh credentials in Keychain.
- Never store provider secrets in plain-text preferences.
- Never log tokens.
- Redact sensitive request headers from diagnostics.

### 13.2 AI content

- Explain when selected text or documents will be sent to an AI provider.
- Avoid sending content until the user starts an AI action.
- Provide a preview for large document operations.
- Allow users to disable AI features.

### 13.3 Clipboard

- Monitoring is disabled by default.
- Clipboard content is not persisted unless the user saves it.
- Clipboard content is not uploaded automatically.

### 13.4 Local data

Users should be able to:

- Clear caches.
- Remove downloaded audio.
- Delete local application data.
- Export diagnostics.
- Sign out and revoke local credentials.

---

## 14. Technical direction

### 14.1 Platform strategy

Build a native macOS application using SwiftUI.

Do not use:

- Electron for the main application.
- A permanent web view as the main UI.
- A direct enlarged copy of the iOS tab interface.

Mac Catalyst may be useful for experiments, but it should not define the final product architecture.

### 14.2 Recommended technology

- **UI:** SwiftUI
- **System interoperability:** AppKit where SwiftUI does not provide sufficient control
- **State management:** Observation-based feature state
- **Networking:** shared async API client
- **Streaming:** shared SSE client
- **Authentication:** Keychain-backed shared auth service
- **Persistence:** repository abstraction backed by SwiftData or SQLite
- **Audio:** AVFoundation
- **OCR:** Vision
- **Widgets:** WidgetKit
- **System actions:** App Intents
- **Spotlight:** Core Spotlight
- **Project generation:** XcodeGen
- **Unit tests:** Swift Testing or XCTest as appropriate
- **UI tests:** XCUITest

### 14.3 Deployment target

Initial recommendation:

```text
macOS 14 or later
```

The deployment target should be reviewed before implementation against:

- App Intents requirements.
- Widget interaction requirements.
- SwiftData behavior.
- Observation APIs.
- Supported user hardware.

### 14.4 Shared-code strategy

Share domain and infrastructure code, not platform-specific UI.

Good sharing candidates:

- Models.
- DTOs.
- API routes.
- Networking.
- Authentication.
- Keychain abstraction.
- FSRS domain behavior.
- TTS requests.
- Assistant streaming.
- Validation.
- Import parsing.
- App Intent domain actions.

Platform-specific candidates:

- Navigation.
- Window management.
- Tables.
- Inspectors.
- Menus.
- Global hotkeys.
- Menu bar UI.
- Drag and drop.
- Services.
- macOS settings.

### 14.5 Proposed repository direction

One possible target structure:

```text
apple/
├── project.yml
├── Shared/
│   ├── Core/
│   ├── Networking/
│   ├── Authentication/
│   ├── Persistence/
│   ├── Study/
│   ├── AppIntents/
│   └── DesignSystem/
├── iOS/
│   ├── App/
│   └── Features/
├── macOS/
│   ├── App/
│   ├── Features/
│   ├── Commands/
│   ├── MenuBar/
│   ├── Services/
│   └── Resources/
├── Widgets/
└── Tests/
```

This is a target direction, not an immediate requirement. Migration should be incremental to keep the iOS app buildable.

---

## 15. Reuse from the current iOS application

The current iOS application already demonstrates:

- Authentication.
- Keychain storage.
- JWT refresh rotation.
- Vocabulary management.
- Search and filtering.
- FSRS reviews.
- English and Chinese modes.
- TTS.
- AI chat streaming.
- Drills.
- Reading practice.
- Conversation.
- OCR.
- Widgets.
- API key management.
- Hanzi stroke order and writing practice.

The macOS project should first audit these components and classify them as:

1. Reusable without changes.
2. Reusable behind a protocol.
3. Reusable after platform cleanup.
4. iOS-specific and requiring a macOS implementation.
5. Better replaced by a shared implementation.

The objective is to redesign the product experience without duplicating stable domain behavior.

---

## 16. Release scope

### 16.1 Milestone 0: Discovery and architecture

Deliverables:

- Existing iOS code audit.
- Backend API audit.
- Product requirements.
- UI information architecture.
- Shared-code plan.
- Persistence decision.
- Deployment target decision.
- Project and target structure.
- Risk register.

Exit criteria:

- Architecture decisions are documented.
- The first implementation milestone has no unresolved foundational dependency.

### 16.2 Milestone 1: Native application foundation

Deliverables:

- macOS target.
- App lifecycle.
- Authentication.
- Shared API client.
- Main window.
- Sidebar.
- Toolbar.
- Settings foundation.
- Theme and accessibility foundation.

Exit criteria:

- A user can launch, sign in, sign out, and move through the native shell.

### 16.3 Milestone 2: Vocabulary workspace

Deliverables:

- Vocabulary table.
- Search.
- Filters.
- Sorting.
- Selection.
- Inspector.
- Word detail.
- Add, edit, and delete.
- TTS.
- English and Chinese support.
- Tags and favorites.

Exit criteria:

- The Mac app can perform the essential vocabulary-management workflow.

### 16.4 Milestone 3: Review and Today

Deliverables:

- Today dashboard.
- Due-card queue.
- FSRS review.
- Focus session.
- Keyboard grading.
- Session summary.
- Basic insights.

Exit criteria:

- A learner can complete the full daily study loop on macOS.

### 16.5 Milestone 4: Offline and synchronization

Deliverables:

- Local persistence.
- Offline reads.
- Mutation queue.
- Sync engine.
- Sync status.
- Conflict policy.
- Activity view.

Exit criteria:

- Core vocabulary and review workflows remain usable during a network interruption.

### 16.6 Milestone 5: Native macOS differentiation

Deliverables:

- Global Quick Lookup.
- Global shortcut.
- Menu bar companion.
- App Intents.
- Shortcuts actions.
- Spotlight indexing.
- Services or share-based text capture.
- Widgets.

Exit criteria:

- A user can capture and review vocabulary without first navigating to the main window.

### 16.7 Milestone 6: Practice and AI

Deliverables:

- Assistant workspace.
- Drills.
- Reading.
- Listening.
- Conversation.
- Vocabulary-grounded generation.
- Imported-text analysis.

Exit criteria:

- AI features are contextual, controllable, and connected to saved vocabulary.

### 16.8 Milestone 7: Import, OCR, and power-user workflows

Deliverables:

- Drag and drop.
- Image OCR.
- Screenshot extraction.
- PDF extraction.
- CSV and JSON import/export.
- Batch operations.
- Smart Lists.
- Command Palette.
- Multiple word windows.

Exit criteria:

- Power users can efficiently process and organize significant vocabulary collections.

### 16.9 Milestone 8: Production readiness

Deliverables:

- Accessibility audit.
- Performance profiling.
- Unit test coverage.
- UI test coverage.
- Localization validation.
- App sandbox review.
- Hardened Runtime.
- Code signing.
- Notarization.
- Distribution packaging.
- Release notes.
- Support and diagnostics workflow.

Exit criteria:

- The application is ready for controlled external distribution.

---

## 17. Priority model

### P0: Required foundation

- Native macOS target.
- Authentication.
- Shared API client.
- Vocabulary table.
- Word detail.
- Search and filters.
- Add, edit, and delete.
- TTS.
- FSRS review.
- Today dashboard.
- Settings.
- Accessibility fundamentals.

### P1: Complete learning product

- English and Chinese parity.
- Focus Review.
- Practice.
- Assistant.
- Offline cache.
- Synchronization.
- Import and export.
- Basic insights.

### P2: Distinctive macOS experience

- Quick Lookup.
- Menu bar.
- Services.
- Spotlight.
- Shortcuts.
- App Intents.
- Widgets.
- Drag-and-drop OCR.

### P3: Power-user experience

- Command Palette.
- Smart Lists.
- Batch editing.
- Multiple windows.
- PDF extraction.
- Clipboard assistant.
- Advanced insights.
- Advanced automation.

---

## 18. Success metrics

Metrics should be implemented with privacy-conscious analytics or derived from server-side domain events where appropriate.

### 18.1 Activation

- Percentage of signed-in users who save a first word.
- Time from first launch to first saved word.
- Percentage who complete a first review session.

### 18.2 Capture efficiency

- Median time from Quick Lookup invocation to saved word.
- Percentage of lookups converted to saved cards.
- Words added from system integrations.
- Words added from documents or OCR.

### 18.3 Learning engagement

- Daily and weekly active learners.
- Review completion rate.
- Average review sessions per week.
- Daily goal completion.
- Practice usage.

### 18.4 Learning quality

- Retention trend.
- Lapse rate.
- Difficult-card recovery.
- Listening accuracy.
- Reading exercise completion.

### 18.5 Reliability

- Crash-free sessions.
- Sync success rate.
- Offline queue failure rate.
- Quick Lookup response time.
- Cold launch time.
- Search latency.

---

## 19. Key risks

### 19.1 Shared code is too coupled to UIKit

Mitigation:

- Audit before migration.
- Introduce protocols around platform services.
- Move domain code incrementally.
- Keep platform views separate.

### 19.2 macOS scope becomes too broad

Mitigation:

- Build the vocabulary and review workspace first.
- Treat system integrations as staged milestones.
- Define explicit exit criteria.

### 19.3 Offline synchronization introduces data conflicts

Mitigation:

- Define record ownership and mutation semantics early.
- Use idempotent operations.
- Add version fields or server cursors where needed.
- Test reconnect and duplicate scenarios.

### 19.4 Global shortcut conflicts

Mitigation:

- Make the shortcut configurable.
- Detect registration failure.
- Provide a settings warning and alternative.

### 19.5 Clipboard-related privacy concerns

Mitigation:

- Keep the feature optional.
- Disable it by default.
- Process locally before network access.
- Provide visible pause controls.

### 19.6 AI features become expensive or unfocused

Mitigation:

- Reuse generated content where possible.
- Require explicit generation actions.
- Ground requests in selected vocabulary.
- Display model and provider settings.
- Track request errors and latency.

---

## 20. Documentation map

This overview is the entry point. Detailed specifications should be created as separate documents so that product, design, implementation, testing, and release decisions remain manageable.

### 20.1 Product and UX

- `docs/macos-product-requirements.md`
  - User problems.
  - Personas.
  - Use cases.
  - Functional requirements.
  - Non-functional requirements.
  - Acceptance criteria.

- `docs/macos-information-architecture.md`
  - Navigation.
  - Window model.
  - Sidebar hierarchy.
  - Route ownership.
  - Deep links.

- `docs/macos-design-system.md`
  - Color.
  - Typography.
  - Spacing.
  - Components.
  - Interaction states.
  - Dark mode.
  - Accessibility.

- `docs/macos-keyboard-and-commands.md`
  - Main menu.
  - Keyboard shortcuts.
  - Command Palette.
  - Focus behavior.

### 20.2 Core features

- `docs/macos-today.md`
  - Daily dashboard.
  - Goal.
  - Streak.
  - Recommendations.

- `docs/macos-vocabulary.md`
  - Table.
  - Search.
  - Filters.
  - Smart Lists.
  - Detail and inspector.
  - Batch operations.

- `docs/macos-review.md`
  - FSRS.
  - Session lifecycle.
  - Focus mode.
  - Keyboard controls.
  - Session result.

- `docs/macos-practice-and-ai.md`
  - Assistant.
  - Drills.
  - Reading.
  - Listening.
  - Conversation.
  - AI privacy.

- `docs/macos-chinese.md`
  - Hanzi.
  - Pinyin.
  - Mandarin TTS.
  - Stroke order.
  - Writing practice.

### 20.3 macOS integrations

- `docs/macos-quick-lookup.md`
  - Global panel.
  - Shortcut registration.
  - Clipboard behavior.
  - Multi-display behavior.

- `docs/macos-menu-bar.md`
  - Menu bar states.
  - Mini review.
  - Quick Add.
  - Due count.

- `docs/macos-system-integrations.md`
  - App Intents.
  - Shortcuts.
  - Spotlight.
  - Services.
  - Widgets.
  - Notifications.

- `docs/macos-import-and-capture.md`
  - Drag and drop.
  - OCR.
  - PDF.
  - Images.
  - Clipboard.
  - CSV and JSON.

### 20.4 Architecture and engineering

- `docs/macos-architecture.md`
  - Targets.
  - Modules.
  - Feature boundaries.
  - Dependency rules.
  - Shared code.
  - AppKit bridges.

- `docs/macos-data-and-sync.md`
  - Persistence.
  - Offline behavior.
  - Sync protocol.
  - Conflict resolution.
  - Migration.

- `docs/macos-security-and-privacy.md`
  - Keychain.
  - AI data.
  - Clipboard.
  - Logging.
  - Local deletion.

- `docs/macos-testing.md`
  - Unit tests.
  - Integration tests.
  - UI tests.
  - Accessibility tests.
  - Performance tests.

- `docs/macos-release.md`
  - Signing.
  - Sandbox.
  - Entitlements.
  - Notarization.
  - DMG.
  - App Store.
  - Update strategy.

### 20.5 Delivery management

- `docs/macos-roadmap.md`
  - Milestones.
  - Dependencies.
  - Work breakdown.
  - Definition of done.
  - Risks.

- `docs/macos-decisions.md`
  - Architecture Decision Records.
  - Product decisions.
  - Rejected alternatives.

---

## 21. Recommended documentation sequence

Detailed documents should be created in this order:

1. Product requirements.
2. Information architecture.
3. Architecture and shared-code audit.
4. Design system.
5. Vocabulary workspace.
6. Review and Today.
7. Data, offline, and synchronization.
8. Quick Lookup.
9. Menu bar.
10. System integrations.
11. Practice and AI.
12. Import and capture.
13. Security and privacy.
14. Testing.
15. Release and distribution.
16. Implementation roadmap.

This order resolves foundational product and architecture decisions before detailed implementation planning.

---

## 22. Immediate next steps

### Step 1: Audit the iOS codebase

Identify:

- Reusable domain models.
- Networking dependencies.
- UIKit or iOS-only coupling.
- Authentication dependencies.
- Shared resources.
- Widget dependencies.
- Test coverage.

### Step 2: Create product requirements

Define:

- User journeys.
- Functional requirements.
- Priority.
- Acceptance criteria.
- Out-of-scope behavior.

### Step 3: Define information architecture

Specify:

- Main window states.
- Sidebar.
- Inspector.
- Secondary windows.
- Deep links.
- Navigation restoration.

### Step 4: Decide the shared-project migration

Choose whether to:

- Extend the current `ios/project.yml`.
- Rename `ios` to an Apple-platform workspace.
- Introduce a shared Swift package.
- Create a temporary macOS project and merge after validation.

### Step 5: Build a thin vertical prototype

The first prototype should include:

- macOS app launch.
- Sign in.
- Native sidebar.
- Vocabulary table.
- Inspector detail.
- Search.
- Pronunciation.

This proves the architecture and native interaction model before implementing the full roadmap.

---

## 23. Definition of the first successful prototype

The first prototype is successful when:

- It is a native macOS application.
- It connects to the existing backend.
- A user can sign in.
- It loads the user's vocabulary.
- Vocabulary appears in a sortable table.
- Selecting a row opens native detail or inspector content.
- Search responds quickly.
- Pronunciation works.
- Keyboard navigation works.
- Light and Dark Mode work.
- Existing iOS behavior remains unaffected.

The prototype does not need complete visual polish, offline synchronization, or all system integrations. Its purpose is to validate the foundation on which the complete product will be built.

---

## 24. Summary

Voca for macOS should be built as a native, keyboard-friendly, system-integrated language-learning workspace.

The main application will provide:

- Vocabulary management.
- FSRS review.
- Today dashboard.
- Practice.
- AI assistance.
- Conversation.
- Learning insights.

The macOS-specific layer will provide:

- Global Quick Lookup.
- Menu bar review.
- Services.
- Spotlight.
- Shortcuts.
- App Intents.
- Widgets.
- Drag and drop.
- OCR and document processing.
- Multiple windows.
- Native commands and keyboard workflows.

The product should reuse stable iOS and backend domain behavior while designing the macOS experience independently. Development should begin with product requirements, information architecture, a shared-code audit, and a thin native vocabulary prototype.
