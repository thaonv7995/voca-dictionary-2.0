# Voca for macOS — Design System

> Visual language, semantic tokens, component patterns, interaction states, accessibility rules, and platform-specific UI guidance for the native Voca macOS application.

## Document status

- **Status:** Draft
- **Document type:** Design System Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the visual and interaction foundation for Voca on macOS.

It specifies:

- Product visual character.
- Brand application.
- Semantic colors.
- Typography.
- Spacing.
- Shape and border rules.
- Window and column dimensions.
- Sidebar, toolbar, table, detail, and inspector patterns.
- Buttons, controls, fields, badges, and tags.
- Loading, empty, error, offline, and synchronization states.
- English and Chinese content presentation.
- Review and AI presentation.
- Light Mode and Dark Mode.
- Accessibility.
- Motion and animation.
- Shared versus platform-specific design tokens.
- Component governance.

The system should help Voca feel recognizable while preserving native macOS behavior.

---

## 2. Design principles

### DS-PRN-001 — Native behavior comes first

Voca should use standard macOS controls and interaction conventions unless a custom component produces a measurable improvement that cannot be achieved natively.

Prefer:

- Native sidebar.
- Native toolbar.
- Native table.
- Native inspector.
- Native menus.
- Native popovers.
- Native sheets.
- Standard focus and selection behavior.

Avoid recreating system controls only to change their appearance.

### DS-PRN-002 — Content has greater visual weight than containers

Words, meanings, examples, progress, and study actions are the most important elements.

Avoid:

- Wrapping every section in a rounded card.
- Excessive outlines.
- Decorative gradients behind dense content.
- Large empty hero areas in productivity views.

### DS-PRN-003 — Calm does not mean empty

The interface should feel focused and comfortable while retaining useful desktop information density.

The design must support:

- Large vocabulary collections.
- Multi-column comparison.
- Fast scanning.
- Batch actions.
- Keyboard workflows.

### DS-PRN-004 — Green is an accent, not a background strategy

Voca's green identity should identify:

- Primary actions.
- Active learning progress.
- Successful completion.
- Selected brand moments.

It should not dominate all surfaces.

### DS-PRN-005 — Hierarchy must survive without color

Size, spacing, weight, labels, icons, and shape must communicate structure independently from color.

### DS-PRN-006 — Learning states remain consistent

The same learning concepts must use consistent labels and visual semantics across:

- Vocabulary.
- Review.
- Today.
- Menu bar.
- Widgets.
- Insights.

### DS-PRN-007 — Motion explains change

Animation should communicate:

- A view transition.
- A completed action.
- A revealed answer.
- A changed state.

Motion should never delay repetitive study actions.

### DS-PRN-008 — Accessibility is encoded in components

Reusable components should include:

- Accessible labels.
- Focus behavior.
- Contrast behavior.
- Reduced-motion behavior.
- Keyboard support.

Accessibility must not depend on individual feature teams remembering to add it later.

---

## 3. Product visual character

Voca for macOS should feel:

- Native.
- Calm.
- Intelligent.
- Precise.
- Approachable.
- Focused.
- Reliable.

It should not feel:

- Childish.
- Game-like by default.
- Visually noisy.
- Like a mobile interface enlarged for desktop.
- Like a generic administration dashboard.
- Like a generic AI chat client.

### 3.1 Visual balance

The product balances three modes:

#### Productivity

Used by:

- Vocabulary table.
- Import.
- Settings.
- Smart Lists.
- Batch actions.

Characteristics:

- High clarity.
- Moderate density.
- Stable alignment.
- Compact controls.

#### Learning

Used by:

- Review.
- Practice.
- Today.
- Word detail.

Characteristics:

- Strong content focus.
- Comfortable reading width.
- Reduced distraction.
- Clear progression.

#### Ambient

Used by:

- Quick Lookup.
- Menu bar.
- Widgets.
- Notifications.

Characteristics:

- Concise information.
- Immediate action.
- Minimal navigation.
- Fast dismissal.

---

## 4. Token architecture

Design values should be represented as semantic tokens rather than arbitrary values inside views.

Token groups:

```text
Color
Typography
Spacing
Radius
Stroke
Shadow
Layout
Motion
Iconography
```

### 4.1 Token naming

Use semantic names:

```text
Color.textPrimary
Color.textSecondary
Color.surfacePrimary
Color.surfaceElevated
Color.actionPrimary
Color.statusWarning
Spacing.content
Radius.panel
Layout.inspectorWidth
Motion.quick
```

Avoid component-specific raw names:

```text
green500
gray3
cardPadding17
cornerRadius11
```

Raw palette values may exist internally, but feature code should consume semantic tokens.

### 4.2 Platform adaptation

Shared semantic intent does not require identical rendering on iOS and macOS.

Example:

```text
actionPrimary
```

May map to the same brand family on both platforms, while:

- Button height differs.
- Hover behavior exists only on macOS.
- Focus ring treatment differs.
- Toolbar placement differs.

---

## 5. Color system

### 5.1 Color source

Use dynamic asset-catalog colors or system semantic colors.

Do not define interface colors through fixed RGB values directly in feature views.

### 5.2 Brand colors

The existing Voca green remains the primary brand family.

Proposed raw palette for design exploration:

```text
Brand Green 50     #ECFDF3
Brand Green 100    #D1FAE0
Brand Green 200    #A7F3C6
Brand Green 300    #6EE7A0
Brand Green 400    #34D37A
Brand Green 500    #16B663
Brand Green 600    #0E9650
Brand Green 700    #0C7642
Brand Green 800    #0D5D38
Brand Green 900    #0B4C30
```

These values are starting points, not final accessibility approval.

### 5.3 Semantic color tokens

#### Text

```text
textPrimary
textSecondary
textTertiary
textPlaceholder
textInverse
textLink
textOnAccent
```

Prefer system semantic text colors for primary hierarchy.

#### Surfaces

```text
surfacePrimary
surfaceSecondary
surfaceTertiary
surfaceElevated
surfaceSidebar
surfaceInspector
surfaceSelection
surfaceHover
surfacePressed
```

#### Borders and separators

```text
borderSubtle
borderStandard
borderStrong
separator
focusRing
```

#### Actions

```text
actionPrimary
actionPrimaryHover
actionPrimaryPressed
actionSecondary
actionDestructive
actionDisabled
```

#### Status

```text
statusSuccess
statusWarning
statusError
statusInfo
statusOffline
statusSyncing
statusPending
```

#### Learning

```text
reviewAgain
reviewHard
reviewGood
reviewEasy
levelBeginner
levelIntermediate
levelAdvanced
dueNow
dueSoon
dueLater
```

### 5.4 System-color strategy

Prefer system colors for:

- Primary and secondary text.
- Window background.
- Sidebar background.
- Selection.
- Disabled state.
- Separators.
- Focus ring.

Use Voca semantic colors for:

- Primary brand actions.
- Learning-state emphasis.
- Charts when system colors are insufficient.
- Branded empty states and onboarding.

### 5.5 Review colors

Review grades must not be distinguished only by color.

Each grade includes:

- Label.
- Keyboard number.
- Optional icon.
- Color.

Example:

```text
1  Again
2  Hard
3  Good
4  Easy
```

Recommended semantics:

- Again: destructive or red family.
- Hard: orange family.
- Good: brand green family.
- Easy: blue or teal family.

Final colors must be tested in:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Color-filter accessibility settings.

### 5.6 Dark Mode

Dark Mode is not created by simply inverting raw colors.

Rules:

- Use system surfaces.
- Reduce very bright brand saturation on large areas.
- Preserve distinguishable elevated surfaces.
- Avoid pure black backgrounds for large reading areas unless inherited from system behavior.
- Recheck examples, code, pinyin, and Hanzi contrast.
- Test selected table rows in active and inactive windows.

---

## 6. Typography

### 6.1 Font family

Use the macOS system font for interface text.

Use appropriate system language fallback for:

- Hanzi.
- Pinyin diacritics.
- Vietnamese diacritics.
- Phonetic transcription.

Do not bundle a custom interface font unless a documented branding need outweighs:

- Native appearance.
- Font-loading cost.
- Localization complexity.
- Accessibility behavior.

### 6.2 Semantic text styles

#### Interface

```text
windowTitle
sectionTitle
body
callout
caption
captionEmphasized
controlLabel
tablePrimary
tableSecondary
```

#### Vocabulary content

```text
wordHero
wordTitle
wordTable
pronunciation
meaningPrimary
meaningSecondary
example
exampleTranslation
hanziHero
pinyin
```

#### Learning

```text
reviewPrompt
reviewAnswer
reviewMetadata
statisticValue
statisticLabel
```

### 6.3 Suggested scale

Initial design targets:

```text
Word hero              32–40 pt, semibold
Hanzi hero             40–52 pt, medium or semibold
Review prompt          28–36 pt, medium
Window section title   20–24 pt, semibold
Word title             20–24 pt, semibold
Primary meaning        15–17 pt, regular
Body                    system body
Table primary           system body
Table secondary         system callout
Caption                 system caption
```

These values must remain adaptable to accessibility settings.

### 6.4 Line length

Recommended reading widths:

- Definitions: 45–75 characters.
- Examples: 50–90 characters.
- Long AI explanations: 60–85 characters.
- Reading-practice passage: 55–80 characters.

Do not stretch long textual content across an entire wide display.

### 6.5 Emphasis

Use in order:

1. Position.
2. Size.
3. Weight.
4. Color.

Avoid using multiple emphasis methods simultaneously unless the content is genuinely primary.

### 6.6 Truncation

May truncate:

- Secondary table content.
- Long tag lists.
- Nonessential path labels.

Should wrap:

- Meanings.
- Examples.
- Error messages.
- AI content.
- Review answers.
- Account-action explanations.

---

## 7. Spacing system

Use a four-point base grid with selected intermediate values.

```text
spacing2     2
spacing4     4
spacing6     6
spacing8     8
spacing12   12
spacing16   16
spacing20   20
spacing24   24
spacing32   32
spacing40   40
spacing48   48
spacing64   64
```

### 7.1 Semantic spacing

```text
controlInlineGap       6–8
controlGroupGap       12
compactContentInset    8–12
standardContentInset  16
comfortableInset      20–24
sectionGap            24–32
heroGap               32–48
```

### 7.2 Dense layouts

Tables and inspectors use compact spacing, but text must remain scannable.

Avoid:

- Less than four points between icon and label.
- Touch-oriented oversized controls in dense desktop tables.
- Excessive 24-point gaps in metadata panels.

### 7.3 Reading layouts

Review, reading practice, and long word detail may use more generous spacing:

- 20–32 point content insets.
- 24–40 point section separation.
- Comfortable line spacing.

---

## 8. Radius and shape

### 8.1 Radius tokens

```text
radiusControl     5–6
radiusTag         capsule
radiusPanel       8–10
radiusCard        10–12
radiusHero        14–16
```

### 8.2 Usage

Use small radii for:

- Text fields.
- Compact controls.
- Filter tokens.
- Metadata panels.

Use medium radii for:

- Quick Lookup result panel content.
- Today summary sections.
- Review answer panels.

Avoid:

- Large rounded rectangles around every content section.
- Mobile-style floating cards inside native split views.
- Excessively pill-shaped primary buttons.

### 8.3 Continuous corners

Use continuous corner style where consistent with SwiftUI and macOS rendering.

---

## 9. Borders, separators, and shadows

### 9.1 Borders

Use borders to:

- Define editable fields.
- Distinguish an elevated temporary panel.
- Show keyboard focus when system focus is insufficient.
- Separate content with similar backgrounds.

Avoid borders around:

- Every dashboard statistic.
- Every table cell.
- Every inspector section.

### 9.2 Separators

Use native separators for:

- Sidebar groups.
- Inspector sections.
- Table headers.
- Toolbar and content boundaries.

### 9.3 Shadows

Shadows are reserved for elevated transient surfaces:

- Quick Lookup panel.
- Popover.
- Floating command palette.
- Drag preview.

Do not add custom shadows to:

- Native toolbar.
- Every content card.
- Table rows.
- Sidebar items.

---

## 10. Layout dimensions

### 10.1 Main window

Initial constraints:

```text
Minimum width       900
Preferred width     1200–1440
Minimum height      620
Preferred height    760–960
```

### 10.2 Sidebar

```text
Minimum width       190
Ideal width         220–250
Maximum width       300
```

The sidebar must support:

- Localized labels.
- Optional due badge.
- User Smart List names.

### 10.3 Vocabulary content

```text
Minimum width       440
Ideal width         620–820
```

### 10.4 Detail column

```text
Minimum width       320
Ideal width         380–480
Maximum width       560
```

### 10.5 Inspector

```text
Minimum width       280
Ideal width         300–340
Maximum width       400
```

If the window cannot support content, detail, and inspector simultaneously:

1. Preserve primary content.
2. Convert inspector to an overlay.
3. Collapse or navigate detail.
4. Never compress all regions below usability.

### 10.6 Reading content

Long-form reading content should use a centered maximum width rather than filling all available horizontal space.

---

## 11. Sidebar

### 11.1 Structure

Sidebar groups:

```text
Learn
Library
Smart Lists
Progress
```

Utility content:

```text
Sync status
Account
Settings
```

### 11.2 Sidebar row anatomy

```text
[Icon] [Label]                         [Badge]
```

Rules:

- Use SF Symbols.
- Keep one icon style and weight.
- Avoid custom multicolor icons for ordinary destinations.
- Badges must remain concise.
- User-created Smart Lists may use a generic icon or selected symbol.

### 11.3 Selection

Use native sidebar selection.

Do not replace native selection with a large custom green capsule.

### 11.4 Secondary status

Sync problems may appear:

- Near account/status utility area.
- As a small warning icon.
- With an accessible text label.

Routine synchronization should not animate continuously in the sidebar.

---

## 12. Toolbar

### 12.1 Rules

Toolbar controls must:

- Reflect the active destination.
- Remain stable while content refreshes.
- Use native toolbar placement.
- Expose tooltips.
- Expose keyboard shortcuts in menus.

### 12.2 Priority

At reduced width:

1. Navigation controls.
2. Destination-defining search.
3. Primary action.
4. Active-state controls.
5. Secondary controls.
6. Overflow.

### 12.3 Vocabulary toolbar

Recommended structure:

```text
[Sidebar] [Back/Forward] [Language]
[Search………………………………]
[Filter] [Sort] [View] [Inspector] [+]
```

Search may move below or into the content header if toolbar width becomes insufficient.

### 12.4 Labels

Icon-only toolbar buttons require:

- Tooltip.
- Accessibility label.
- Menu equivalent where important.

Use a text label when an icon is ambiguous.

---

## 13. Table system

### 13.1 Default vocabulary table

Recommended default columns:

```text
Favorite
Word
Meaning
Level
Next Review
Tags
```

Optional columns:

```text
Pronunciation
Language
Created
Last Reviewed
Review Count
Difficulty
Topic
```

### 13.2 Row density

Provide at least:

- Compact.
- Comfortable.

Suggested targets:

```text
Compact row          26–30
Comfortable row      34–40
```

Hanzi rows may require additional height if pinyin is displayed beneath the word.

### 13.3 Row anatomy

English:

```text
concise
```

Chinese:

```text
简洁
jiǎnjié
```

Avoid forcing pronunciation into a separate visible column when a compact secondary line is more readable.

### 13.4 Selection

Support native:

- Single selection.
- Command-click multi-selection.
- Shift-click range selection.
- Keyboard movement.
- Type selection where appropriate.

### 13.5 Hover

Hover may reveal low-priority row actions, but essential actions must also exist in:

- Context menu.
- Toolbar.
- Inspector.
- Keyboard command.

### 13.6 Empty cells

Use:

- Em dash for unavailable display-only values.
- Explicit “Not scheduled” where semantically important.
- No placeholder text that resembles actual data.

### 13.7 Column resizing

Column widths should:

- Follow user adjustment.
- Persist per window or device.
- Have sensible minimums.
- Avoid hiding the primary word column.

---

## 14. Vocabulary detail

### 14.1 Header

The header contains:

- Word or Hanzi.
- Pronunciation or pinyin.
- Audio.
- Favorite.
- Language.
- More menu.

### 14.2 Content order

```text
Identity
Primary meaning
Primary example
Learning state
Additional meanings
Examples
Collocations and related words
Personal notes
History
AI actions
```

### 14.3 Action hierarchy

Primary contextual action:

- Play pronunciation.

Secondary actions:

- Edit.
- Favorite.
- Ask AI.
- Practice.

Tertiary or destructive actions:

- Export.
- Delete.
- Advanced metadata.

### 14.4 Sections

Use:

- Section title.
- Whitespace.
- Optional separator.

Do not use a separate rounded card for every definition or example.

### 14.5 Long content

Word detail should scroll as one document unless a specialized subview, such as writing practice, requires independent interaction.

---

## 15. Inspector

### 15.1 Purpose

Inspector contains secondary contextual controls and metadata.

It should not duplicate the complete detail view.

### 15.2 Vocabulary inspector

Sections:

```text
Learning
Organization
Personal Notes
History
Actions
```

### 15.3 Control layout

Use form-like alignment for:

- Level.
- Next review.
- Tags.
- Topic.
- Created date.

Use a larger text area for notes.

### 15.4 Multi-selection

Show:

- Selected count.
- Common tags.
- Mixed-value status.
- Batch actions.

Mixed values must be explicit rather than showing one arbitrary row's data.

### 15.5 Inspector transition

Showing and hiding the inspector should use native behavior and respect Reduce Motion.

---

## 16. Buttons

### 16.1 Button hierarchy

#### Primary

Used once per local decision area:

- Start Review.
- Save.
- Confirm Import.
- Send.

#### Secondary

Used for alternatives:

- Cancel.
- Preview.
- Configure.
- Ask AI.

#### Tertiary

Used for low-emphasis actions:

- Show More.
- Clear.
- Open Detail.

#### Destructive

Used for:

- Delete.
- Sign Out where data consequences exist.
- Remove local data.

### 16.2 Button labels

Use verbs:

- Add Word.
- Start Review.
- Save Changes.
- Clear Filters.

Avoid:

- Submit.
- Yes.
- OK.

unless the meaning is unambiguous in a standard system dialog.

### 16.3 Icon buttons

Icon-only buttons require:

- Standard symbol.
- Tooltip.
- Accessibility label.
- Adequate target size.

### 16.4 Loading buttons

While executing:

- Prevent duplicate submission.
- Preserve width.
- Show concise progress.
- Keep cancellation available where meaningful.

---

## 17. Fields and forms

### 17.1 Search

Search fields should:

- Use native search behavior.
- Support clear action.
- Display scope where multiple scopes exist.
- Preserve keyboard flow.

### 17.2 Text fields

Labels should remain visible when useful. Do not rely exclusively on placeholder text.

### 17.3 Validation

Show validation:

- Near the field.
- In specific language.
- Without clearing input.

Examples:

```text
Enter a word before saving.
This word is already in your vocabulary.
The server address must begin with https:// or http://.
```

### 17.4 Secure fields

API keys and passwords:

- Use secure input.
- May allow temporary reveal.
- Must not become readable after being saved and reloaded.

### 17.5 Long forms

Use Settings or inspector-style grouping.

Do not put a long form inside a narrow alert.

---

## 18. Tags, chips, and badges

### 18.1 Tag

Represents user organization.

Properties:

- Text label.
- Optional color.
- Optional remove action in editing context.

### 18.2 Filter token

Represents an active filter.

Properties:

- Filter category.
- Value.
- Clear action.

### 18.3 Status badge

Represents:

- Due state.
- Offline.
- Pending.
- Error.
- AI generation.

Badges should not be used as decoration.

### 18.4 Count badge

Used for:

- Due count.
- Selected item count.
- Import issue count.

Large counts may use compact formatting only where exact value is not essential.

### 18.5 Color

User-defined tag colors must retain:

- Readable text.
- Dark Mode adaptation.
- Non-color identification through label.

---

## 19. Icons

### 19.1 Source

Use SF Symbols where possible.

Custom icons are acceptable for:

- Voca application icon.
- Unique brand concepts without an appropriate symbol.
- Specialized Hanzi practice representation.

### 19.2 Style

Keep icon rendering consistent:

- Monochrome in navigation and toolbar.
- Hierarchical only when it improves comprehension.
- Multicolor only for deliberate branded illustrations.

### 19.3 Icon semantics

Common examples:

```text
Today             calendar
Vocabulary        text.book.closed
Review            rectangle.stack
Practice          graduationcap
Assistant         sparkles
Conversation      bubble.left.and.bubble.right
Insights          chart.xyaxis.line
Favorite          star
Quick Lookup      magnifyingglass
Pronunciation     speaker.wave.2
Sync              arrow.triangle.2.circlepath
Offline           wifi.slash
```

Final symbol names must be verified against the deployment target.

### 19.4 Accessibility

Decorative icons should be hidden from accessibility.

Functional icons must expose their action, not their visual name.

Use:

```text
Play pronunciation
```

Not:

```text
Speaker wave two icon
```

---

## 20. Today components

### 20.1 Daily action header

Contains:

- Greeting or neutral daily title.
- Due-card summary.
- Daily-goal progress.
- Start Review.

Avoid oversized marketing-style hero sections.

### 20.2 Summary tiles

Use limited tiles for:

- Due cards.
- Goal.
- Streak.
- Weekly activity.

Tiles should:

- Have consistent alignment.
- Show one primary value.
- Show one concise label.
- Support keyboard navigation when actionable.

### 20.3 Recommendation

A recommended practice item includes:

- What is recommended.
- Why it is recommended.
- Expected duration or scope where useful.
- Start action.
- Dismiss or replace action.

Do not present AI recommendations as mandatory.

---

## 21. Review components

### 21.1 Review canvas

The review canvas prioritizes:

- Prompt.
- Reveal.
- Answer.
- Pronunciation.
- Grade controls.
- Minimal progress.

### 21.2 Prompt

Use large, centered content with a readable maximum width.

Metadata should remain visually secondary.

### 21.3 Reveal

Before reveal:

- Hide answer content fully.
- Keep action clear.

After reveal:

- Preserve prompt position where possible.
- Add answer below or transition predictably.
- Move keyboard focus only when necessary.

### 21.4 Grade controls

Each control displays:

- Number.
- Label.
- Optional next-interval preview.

Example:

```text
[1 Again] [2 Hard] [3 Good] [4 Easy]
```

Avoid moving button positions from card to card.

### 21.5 Progress

Show:

- Remaining count or progress fraction.

Avoid:

- Large celebratory animation after every answer.
- Competitive scoring that conflicts with honest grading.

### 21.6 Completion

Completion screen may show:

- Reviewed count.
- Grade distribution.
- Difficult words.
- Time spent.
- Next action.

Celebration should be brief and reduced when Reduce Motion is active.

---

## 22. Quick Lookup design

### 22.1 Window character

Quick Lookup should resemble a polished system utility:

- Compact.
- Centered on active display.
- Keyboard-first.
- Elevated.
- Easy to dismiss.

### 22.2 Suggested size

```text
Width             520–640
Initial height    64–88
Result height     240–420
```

Height may adapt to content within a maximum.

### 22.3 Structure

```text
┌──────────────────────────────────────────────────┐
│ Search or paste a word…                          │
├──────────────────────────────────────────────────┤
│ Word                                      Audio  │
│ Pronunciation                                    │
│ Meaning                                          │
│ Example                                          │
│                                                  │
│ Add to Voca      Ask AI      Open Detail         │
└──────────────────────────────────────────────────┘
```

### 22.4 Interaction states

```text
Empty
Typing
Searching locally
Searching remotely
Result not saved
Result already saved
Saving
Saved
No result
Offline
Error
```

### 22.5 Visual behavior

- Open with search field focused.
- Avoid a large logo.
- Do not display navigation chrome.
- Keep one primary result initially.
- Secondary meanings may expand.
- Use concise error treatment.

---

## 23. Menu bar design

### 23.1 Scope

The menu bar panel is not a miniature main window.

It should contain:

- Due status.
- Word of the day.
- Quick actions.
- Optional mini review.

### 23.2 Width

Suggested:

```text
320–380 points
```

### 23.3 Compact review

Show:

- Prompt.
- Reveal.
- Four compact grading actions.

Do not show:

- Full editing.
- Long AI responses.
- Complex session configuration.

### 23.4 Status

Routine synced state should remain subtle.

Action-required state may use:

- Warning icon.
- Concise explanation.
- Open Activity action.

---

## 24. Assistant and AI presentation

### 24.1 Identity

AI content should be visually distinguishable without creating an excessively branded chat bubble interface.

Use:

- Role label.
- Subtle surface difference.
- Generation status.
- Source context.

### 24.2 Message layout

Long answers should use document-like readable content.

Avoid narrow mobile chat bubbles for long educational explanations.

### 24.3 Context inspector

Display active context as removable items:

- Selected word.
- Smart List.
- Imported passage.
- Language.
- Level.

The user must be able to understand what will be sent.

### 24.4 Streaming

During streaming:

- Show progressive text.
- Keep Stop visible.
- Avoid animated typing indicators after content begins.
- Preserve scroll control if the user scrolls upward.

### 24.5 Generated content label

Generated definitions, examples, and exercises should be identified as generated when they are not canonical stored content.

### 24.6 Citations and sources

If the backend later supports external sources, present them in a dedicated source section rather than mixing raw URLs throughout the explanation.

---

## 25. Chinese-content design

### 25.1 Hanzi hierarchy

In full detail:

- Hanzi has highest visual priority.
- Pinyin appears immediately below.
- Vietnamese meaning follows.
- Audio remains adjacent to identity.

### 25.2 Hanzi table row

Recommended:

```text
简洁
jiǎnjié
```

The second line uses secondary text styling.

### 25.3 Character separation

For multi-character words, users may select an individual character for:

- Stroke order.
- Writing practice.
- Character details.

Selection must remain clear without relying only on color.

### 25.4 Stroke-order canvas

Provide:

- Play.
- Pause.
- Restart.
- Previous stroke.
- Next stroke.
- Speed.
- Character selector.

The canvas should use a traditional practice-grid option without making it mandatory.

### 25.5 Writing practice

Writing surface states:

- Empty.
- Drawing.
- Reference visible.
- Cleared.

Use pointer and trackpad input appropriately.

Avoid claiming handwriting correctness unless a reliable evaluation model is implemented.

---

## 26. Charts and insights

### 26.1 Chart rules

Every chart must include:

- Clear title.
- Time range.
- Unit.
- Text summary.
- Accessible description.

### 26.2 Color

Do not communicate series identity by color alone.

Add:

- Label.
- Pattern where supported.
- Marker shape.
- Direct annotation.

### 26.3 Tooltips

Hover tooltips may supplement but must not contain the only available data.

Keyboard and VoiceOver access must be considered.

### 26.4 No-data state

Explain:

- Why data is unavailable.
- How much activity is needed.
- What action the user can take.

Avoid rendering an empty chart frame without explanation.

---

## 27. Loading states

### 27.1 Initial load

If no local content exists:

- Show a structured loading state.
- Preserve window structure.
- Avoid a blank full-window spinner where possible.

### 27.2 Refresh

When local content exists:

- Keep content visible.
- Show subtle synchronization progress.
- Avoid clearing selection.

### 27.3 Long-running operations

Imports, OCR, and document analysis show:

- Current phase.
- Progress when measurable.
- Cancel action.
- Background continuation behavior.

### 27.4 Button operations

Prevent duplicate submission while preserving the button's position.

---

## 28. Empty states

### 28.1 Structure

An empty state may contain:

- Simple icon or illustration.
- Concise title.
- One paragraph.
- Primary action.
- Optional secondary action.

### 28.2 Empty vocabulary

Suggested actions:

- Add Word.
- Import.
- Try Quick Lookup.

### 28.3 Empty search

Suggested actions:

- Clear search.
- Clear filters.

Do not show first-run education in a filtered empty state.

### 28.4 No due cards

Show:

- Completion acknowledgment.
- Next due information where available.
- Optional practice action.

Do not pressure the user to generate unnecessary work.

---

## 29. Error states

### 29.1 Inline errors

Use for:

- Validation.
- One failed field.
- One failed table action.

### 29.2 Content errors

Use for:

- Failed destination load.
- Missing entity.
- Offline data unavailable.

### 29.3 Global errors

Reserve for:

- Authentication expiry.
- Local database failure.
- Required upgrade.

### 29.4 Error copy

Error messages should explain:

1. What happened.
2. What remains safe.
3. What the user can do.

Example:

```text
Voca couldn't save this word because the Mac is offline.
Your changes are still on this Mac and will be retried when the connection returns.
```

Avoid exposing:

- Stack traces.
- Raw HTTP bodies.
- Internal error codes without a human explanation.

---

## 30. Offline and synchronization states

### 30.1 Visual levels

#### Synced

Usually no persistent strong indicator.

#### Syncing

Subtle progress icon or status.

#### Offline

Visible but non-blocking indicator.

#### Pending

Communicate that local changes are safe and waiting.

#### Action required

Warning state with Activity action.

### 30.2 Table-row state

Only show row-level sync status when:

- The row failed.
- A conflict requires action.
- The item is pending deletion.

Do not put a sync icon on every normally synchronized row.

### 30.3 Activity

Activity items show:

- Operation.
- Current status.
- Time.
- Retry action where supported.
- Safe diagnostic summary.

---

## 31. Focus and keyboard states

### 31.1 System focus

Preserve native focus rings.

Do not remove focus indicators for aesthetic reasons.

### 31.2 Custom components

Custom controls must define:

- Focused state.
- Hover state.
- Pressed state.
- Disabled state.
- Selected state.

### 31.3 Keyboard selection

Table and list selection should remain visible when focus moves to the inspector.

Use active and inactive selection styling consistent with macOS.

### 31.4 Shortcut hints

Shortcut hints may appear in:

- Menus.
- Tooltips.
- Review controls.
- Command Palette.
- Onboarding.

Avoid permanently labeling every ordinary control with a shortcut.

---

## 32. Motion

### 32.1 Motion tokens

Conceptual durations:

```text
instant       0–80 ms
quick         120–180 ms
standard      180–260 ms
deliberate    280–400 ms
```

Use system animations where appropriate rather than hard-coding all timing.

### 32.2 Allowed motion

- Inspector reveal.
- Quick Lookup expansion.
- Answer reveal.
- Completion acknowledgment.
- Drag-and-drop feedback.
- Progress changes.

### 32.3 Avoided motion

- Constant pulsing.
- Decorative background effects.
- Bouncing controls.
- Large card flips during rapid review.
- Animated gradients.
- Continuous sync rotation when no useful progress is visible.

### 32.4 Reduce Motion

When Reduce Motion is active:

- Replace spatial movement with opacity or immediate changes.
- Disable decorative celebration.
- Keep stroke-order animation user-triggered.
- Preserve progress and state feedback.

---

## 33. Accessibility

### 33.1 Keyboard

All primary workflows must support:

- Tab navigation.
- Arrow-key navigation.
- Menu commands.
- Context menus.
- Review shortcuts.
- Escape dismissal.

### 33.2 VoiceOver

Components must expose:

- Clear labels.
- Values.
- Selected state.
- Expanded state.
- Progress.
- Validation.

### 33.3 Target size

Pointer target sizing may follow desktop conventions, but:

- Tiny unlabeled icons are not acceptable.
- High-frequency controls need comfortable targets.
- Review controls should remain easy to acquire.

### 33.4 Contrast

Test:

- Normal contrast.
- Increased Contrast.
- Light Mode.
- Dark Mode.
- Active window.
- Inactive window.
- Selected table row.

### 33.5 Color filters

Test learning grades and charts under common macOS color filters.

### 33.6 Text resizing

Verify:

- Inspector labels.
- Toolbar overflow.
- Table rows.
- Quick Lookup.
- Review.
- Settings.

### 33.7 Accessible language

Pronunciation buttons should include the word:

```text
Play pronunciation for concise
```

Review grading should include the keyboard mapping:

```text
Good, keyboard shortcut 3
```

---

## 34. Localization and language behavior

### 34.1 Interface versus learning language

The interface language is independent from:

- English vocabulary mode.
- Chinese vocabulary mode.

### 34.2 Layout expansion

Allow for labels at least 30–40 percent longer than initial English or Vietnamese copy.

### 34.3 Vietnamese

Ensure:

- Full diacritic support.
- No aggressive uppercase transformation.
- Adequate line height.

### 34.4 Chinese

Ensure:

- Hanzi is not letter-spaced.
- Pinyin tone marks render correctly.
- Font fallback is stable.
- Text selection preserves characters.

### 34.5 Dates and numbers

Use locale-aware formatting for:

- Dates.
- Relative time.
- Review counts.
- Percentages.
- Durations.

---

## 35. Responsive component behavior

### 35.1 Narrow main window

At minimum width:

- Collapse sidebar.
- Prioritize primary content.
- Move inspector into an overlay.
- Keep Add Word reachable.
- Move secondary toolbar items into overflow.

### 35.2 Wide main window

At wide width:

- Do not stretch prose indefinitely.
- Give useful width to tables.
- Preserve inspector maximum width.
- Center reading-focused content.

### 35.3 Quick Lookup

Quick Lookup width should remain stable rather than expanding to available screen width.

### 35.4 Menu bar

Menu bar panel must not depend on the main-window width.

---

## 36. Design-system component inventory

### Foundations

- Semantic color.
- Typography.
- Spacing.
- Radius.
- Layout metrics.
- Motion.
- Icons.

### Navigation

- Sidebar row.
- Sidebar section.
- Toolbar action.
- Breadcrumb where needed.
- Command Palette.

### Data

- Vocabulary table.
- Column header.
- Sort indicator.
- Empty cell.
- Status cell.
- Selection summary.

### Vocabulary

- Word identity.
- Pronunciation control.
- Meaning block.
- Example block.
- Level indicator.
- Due indicator.
- Tag.
- Related-word link.
- Hanzi identity.
- Stroke-order canvas.

### Learning

- Review prompt.
- Reveal control.
- Review grade control.
- Session progress.
- Session summary.
- Daily-goal progress.
- Streak summary.

### AI

- Context token.
- Message content.
- Streaming state.
- Generated-content label.
- Stop-generation control.

### Feedback

- Loading state.
- Empty state.
- Inline error.
- Content error.
- Offline banner.
- Sync indicator.
- Toast or transient confirmation.

### Input

- Search field.
- Filter token.
- Tag editor.
- Notes editor.
- Language picker.
- Level picker.
- File-drop zone.

### Ambient

- Quick Lookup panel.
- Menu bar summary.
- Mini-review card.
- Widget snapshot views.

---

## 37. Shared versus macOS-specific design components

### 37.1 Shareable foundations

Potentially shared between iOS and macOS:

- Brand palette.
- Semantic learning colors.
- Typography intent names.
- Language-content components at the model level.
- Review labels.
- Icons for product concepts.
- Empty-state copy.
- Accessibility wording.

### 37.2 macOS-specific components

- Main sidebar.
- Desktop toolbar.
- Vocabulary table.
- Inspector.
- Menu commands.
- Table context menu.
- Quick Lookup panel.
- Menu bar panel.
- Desktop Settings layout.
- Hover behavior.
- Multi-selection presentation.

### 37.3 Shared code rule

Share a SwiftUI visual component only if:

- Its layout is naturally appropriate on both platforms.
- Its interaction behavior is equivalent.
- Sharing does not introduce many platform branches.

Otherwise share:

- Tokens.
- Models.
- Content formatting.
- Accessibility labels.

and implement separate platform views.

---

## 38. Component implementation guidance

### 38.1 Token access

Design tokens should be available through typed APIs rather than string keys.

Illustrative direction:

```swift
enum VocaSpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let section: CGFloat = 24
}
```

Color should primarily come from asset catalogs and semantic SwiftUI accessors.

### 38.2 Modifiers

Use modifiers for genuinely repeatable behavior:

- Content width.
- Section spacing.
- Error presentation.
- Focus treatment.

Avoid one large modifier that imposes a full component style with hidden behavior.

### 38.3 Preview catalog

Create previews for:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Larger text.
- English content.
- Chinese content.
- Loading.
- Empty.
- Error.
- Offline.
- Long localized copy.

### 38.4 Snapshot review

If snapshot testing is adopted, prioritize:

- Quick Lookup states.
- Review states.
- Word detail.
- Table row variants.
- Empty and error states.
- Chinese content.

Snapshot tests supplement but do not replace accessibility and behavior tests.

---

## 39. Copy and terminology

### 39.1 Preferred terms

Use consistent product terms:

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

### 39.2 Action copy

Prefer direct actions:

```text
Add Word
Start Review
Play Pronunciation
Ask Assistant
Import Vocabulary
Clear Filters
Retry Sync
```

### 39.3 State copy

Be precise:

```text
Saved on this Mac
Waiting to sync
No cards are due
Sign in to continue
This word is already in your vocabulary
```

### 39.4 Avoid

- Vague success messages such as “Done”.
- Technical backend terms.
- Artificial urgency.
- Shame-oriented streak language.
- Overly conversational text in dense productivity areas.

---

## 40. Design QA checklist

### Native behavior

- [ ] Standard controls are used where appropriate.
- [ ] Sidebar selection behaves natively.
- [ ] Menus and context menus exist.
- [ ] Window resizing does not break content.
- [ ] Focus rings remain visible.

### Visual hierarchy

- [ ] Primary action is identifiable.
- [ ] Content is stronger than decoration.
- [ ] Secondary metadata is visually quieter.
- [ ] Sections do not rely on excessive cards.

### States

- [ ] Loading state exists.
- [ ] Empty state exists.
- [ ] Error state exists.
- [ ] Offline state exists.
- [ ] Disabled state is clear.
- [ ] Hover and focus states are defined.

### Accessibility

- [ ] Keyboard-only workflow succeeds.
- [ ] VoiceOver labels are meaningful.
- [ ] Increased Contrast works.
- [ ] Reduce Motion works.
- [ ] Color is not the only state indicator.
- [ ] Larger text remains usable.

### Languages

- [ ] Vietnamese diacritics render correctly.
- [ ] English pronunciation content is readable.
- [ ] Hanzi and pinyin hierarchy is correct.
- [ ] Long localized labels fit or overflow properly.

### Dark Mode

- [ ] Text contrast is sufficient.
- [ ] Selection remains clear.
- [ ] Brand green remains balanced.
- [ ] Elevated surfaces remain distinguishable.

### Performance

- [ ] Large tables scroll smoothly.
- [ ] Hover effects do not cause expensive redraws.
- [ ] Streaming AI content remains responsive.
- [ ] Preview and image assets are appropriately sized.

---

## 41. Requirement traceability

This design system supports:

- `APP-*`: native windows, menus, toolbar, and platform behavior.
- `TODAY-*`: daily actions and summaries.
- `VOC-*`: table, search, filter, detail, inspector, and batch selection.
- `LANG-*`: English, Hanzi, pinyin, pronunciation, and writing practice.
- `REV-*`: review canvas, grading, focus mode, progress, and summary.
- `QUICK-*`: Quick Lookup form, result, state, and actions.
- `MENU-*`: menu bar panel and compact review.
- `AI-*`: context, streaming, generated content, and privacy cues.
- `CAP-*`: drop zones, import previews, progress, and validation.
- `SYS-*`: widgets, notification routing, and native system surfaces.
- `INS-*`: accessible reports and visualizations.
- `SET-*`: Settings controls and secure fields.
- `SYNC-*`: offline, pending, synchronization, and Activity states.
- `A11Y-*`: keyboard, VoiceOver, contrast, reduced motion, and text size.

---

## 42. Decisions proposed by this document

The following should be reviewed and recorded in `macos-decisions.md`:

1. Use the existing green brand primarily as a semantic accent.
2. Use system semantic surfaces and text colors by default.
3. Use a four-point spacing foundation.
4. Use the native table as the default Vocabulary layout.
5. Avoid card-heavy dashboard and inspector styling.
6. Keep review-grade labels and numbers visible in addition to color.
7. Use SF Symbols for ordinary application controls.
8. Use a centered floating utility design for Quick Lookup.
9. Keep long AI content document-like rather than mobile chat-bubble-like.
10. Share design intent and tokens across Apple platforms, but keep desktop components platform-specific.

---

## 43. Open design questions

1. What exact Voca green values should pass final Light and Dark Mode contrast testing?
2. Should the main window use the system tint or a fixed Voca accent independent of the user's accent setting?
3. Should Today use compact summary tiles or a more continuous document layout?
4. Should word detail and inspector coexist at wide widths?
5. Should pinyin appear in the primary Word column by default?
6. Should review interval previews always be shown?
7. Should review-grade colors align exactly with the existing iOS app?
8. How much visual distinction should generated AI content receive?
9. Should Quick Lookup use a borderless panel or standard utility-window controls?
10. Which vocabulary table density should be the default?
11. Should tags allow user-selected colors in the first release?
12. Should streak receive brand emphasis or remain a secondary measure?
13. Which charts are necessary for the first Insights release?
14. Should writing practice imitate paper styling or remain system-neutral?
15. What illustration style, if any, should be used for first-run empty states?

---

## 44. Validation exercises

### Exercise A — Vocabulary at different widths

Validate at:

- 900-point width.
- 1200-point width.
- 1440-point width.
- Full-screen ultrawide.

Check:

- Table readability.
- Detail width.
- Inspector behavior.
- Toolbar overflow.

### Exercise B — Accessibility matrix

For Vocabulary, Review, and Quick Lookup, test:

- Light Mode.
- Dark Mode.
- Increased Contrast.
- Reduce Motion.
- Larger text.
- VoiceOver.
- Keyboard only.

### Exercise C — Language stress test

Use:

- Long English words.
- Long Vietnamese meanings.
- Multi-character Chinese entries.
- Pinyin with tone marks.
- Multiple tags.
- Missing pronunciation.

### Exercise D — State matrix

For every primary destination, review:

- Loading.
- Loaded.
- Empty.
- Filtered empty.
- Offline.
- Recoverable error.
- Authentication expired.

### Exercise E — Power-user flow

Complete entirely by keyboard:

1. Open Vocabulary.
2. Focus search.
3. Search.
4. Select a result.
5. Play pronunciation.
6. Add a tag.
7. Start Review.
8. Grade cards.
9. Return to Vocabulary.

---

## 45. Definition of done

The initial design system is ready for implementation when:

- Semantic tokens are represented in code.
- Light and Dark Mode foundations exist.
- Sidebar, toolbar, table, detail, inspector, and Settings patterns are approved.
- Review controls are keyboard and VoiceOver accessible.
- Quick Lookup has approved core states.
- English and Chinese content have approved hierarchy.
- Loading, empty, offline, and error patterns exist.
- A preview catalog demonstrates component variants.
- Large-text and Increased Contrast checks pass for foundational components.
- Features can be designed without introducing arbitrary colors, spacing, or control styles.

---

## 46. Next document

The next document should be:

```text
docs/macos-vocabulary.md
```

It should define:

- Vocabulary domain terminology.
- Table columns and default layouts.
- Search and ranking.
- Filters and sorting.
- Collection behavior.
- Word detail.
- Inspector.
- Add and edit flows.
- Duplicate handling.
- Tags, topics, and favorites.
- Multi-selection.
- Batch operations.
- Context menus.
- Drag and drop.
- Smart Lists.
- Trash and restoration.
- English and Chinese variants.
- Loading, offline, and synchronization behavior.
- Keyboard shortcuts.
- Accessibility.
- Acceptance criteria mapped to `VOC-*` and `LANG-*`.
