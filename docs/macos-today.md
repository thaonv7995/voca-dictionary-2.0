# Voca for macOS — Today Dashboard

> Product, UX, recommendation, state, accessibility, and acceptance specification for the daily learning dashboard on macOS.

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
- **Related review specification:** [`macos-review.md`](macos-review.md)
- **Primary requirement group:** `TODAY-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the Today dashboard for Voca on macOS.

It covers:

- Daily learning hierarchy.
- Due-card summary.
- Daily goal.
- Review entry point.
- Active-session continuation.
- Difficult words.
- Suggested practice.
- Recently added vocabulary.
- Weekly summary.
- Streak.
- English and Chinese progress.
- Recommendation rules.
- Completed-day and empty states.
- Offline behavior.
- Synchronization behavior.
- Accessibility.
- Performance.
- Privacy.
- Acceptance criteria.

Today is not a general analytics dashboard. Its primary responsibility is to answer:

> What is the most useful learning action I can take now?

---

## 2. Product intent

Today should reduce decision effort.

When a learner opens Voca, they should immediately understand:

1. Whether cards are due.
2. Whether an unfinished activity can be continued.
3. How much of today's goal is complete.
4. Which weak area deserves attention.
5. What optional practice would provide the most value.

The screen should remain useful for:

- A new user with no vocabulary.
- A returning learner with due cards.
- A learner who completed today's goal.
- A user working offline.
- A user studying only English.
- A user studying only Chinese.
- A user studying both languages.

Today should not become:

- A wall of charts.
- A marketing page.
- A list of every feature.
- A guilt-oriented streak screen.
- An AI recommendation feed.
- A duplicate of Vocabulary or Insights.

---

## 3. Product principles

### TODAY-PRN-001 — One primary action

At most one action receives the strongest visual emphasis.

Typical priority:

```text
Resume active session
→ Start due review
→ Add first word
→ Start suggested practice
```

### TODAY-PRN-002 — Required work precedes optional work

Cards due under the study schedule appear before optional AI-generated practice.

### TODAY-PRN-003 — Completion is a valid state

When the learner is caught up, Voca should acknowledge completion rather than creating artificial urgency.

### TODAY-PRN-004 — Recommendations explain themselves

Each recommendation should state why it is relevant.

Example:

```text
Practice 8 difficult work-related words
You marked these words Again multiple times this week.
```

### TODAY-PRN-005 — Daily metrics remain concise

Today shows a compact summary. Detailed trends belong in Insights.

### TODAY-PRN-006 — Streak supports consistency, not pressure

Streak should be informative and encouraging without becoming the primary measure of learning quality.

### TODAY-PRN-007 — Local content appears before remote refresh finishes

Cached Today data should render immediately when available.

### TODAY-PRN-008 — Recommendations never manipulate FSRS state

Suggested practice may use due or difficult vocabulary, but it must not change scheduling without an explicit review grade.

---

## 4. Scope

### 4.1 Included

- Daily header.
- Primary learning action.
- Due-card summary.
- Daily goal.
- Active-session continuation.
- Difficult-word summary.
- Suggested practice.
- Recently added vocabulary.
- Weekly activity summary.
- Streak.
- Language breakdown.
- Sync and offline states.
- Navigation to Review, Vocabulary, Practice, and Insights.

### 4.2 Related but specified elsewhere

- Detailed Review behavior.
- Vocabulary management.
- Practice generation.
- AI assistant.
- Full analytics.
- Notification scheduling.
- Widget design.
- Menu bar due-count behavior.
- Offline synchronization internals.

### 4.3 Excluded from the first release

- Social comparison.
- Leaderboards.
- Public streak sharing.
- Competitive daily scores.
- Advertising.
- Algorithmically generated content feed.
- A separate dashboard-customization system.
- User-authored dashboard widgets.

---

## 5. Primary layout

### 5.1 Expanded layout

Recommended structure:

```text
┌────────────────────────────────────────────────────────────────────┐
│ Today                                      Language     Quick Add  │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Daily action                                                      │
│  24 cards are due                         [Start Review]            │
│  Goal: 6 of 20 completed                                           │
│                                                                    │
├────────────────────────────────┬───────────────────────────────────┤
│ Difficult words                │ Suggested practice                │
│ 8 words need attention         │ Reading with recent vocabulary    │
│ [Open Collection]              │ [Start Practice]                  │
├────────────────────────────────┼───────────────────────────────────┤
│ Recent vocabulary              │ This week                         │
│ concise                        │ 86 reviews                         │
│ resilient                      │ 4 learning days                   │
│ 简洁                            │ 82% retention                      │
├────────────────────────────────┴───────────────────────────────────┤
│ English progress              Chinese progress                     │
└────────────────────────────────────────────────────────────────────┘
```

### 5.2 Content width

Today should use a centered maximum content width on large displays.

Suggested:

```text
Maximum content width    1100–1280 points
Standard content inset   24–32 points
```

It should not stretch small summary content across an ultrawide display.

### 5.3 Narrow-window layout

At narrower widths:

- Sections become one column.
- The primary action remains first.
- Summary tiles wrap.
- Recent vocabulary and weekly summary stack.
- Secondary metadata moves below section headings.

### 5.4 Scrolling

Today scrolls as one primary document.

Avoid nested vertical scrolling regions.

---

## 6. Daily-state model

Today can be in one of these broad states:

```text
First Run
Loading Without Cache
Loading With Cache
Action Required
Active Session
On Track
Goal Completed
No Cards Due
Offline With Local Data
Offline Without Local Data
Recoverable Error
Authentication Required
```

### 6.1 First Run

Conditions:

- User has no saved vocabulary.
- No review history exists.

Primary action:

- Add First Word.

Secondary actions:

- Import Vocabulary.
- Try Quick Lookup.
- Learn how Voca reviews work.

### 6.2 Action Required

Conditions:

- Due cards exist.
- No active session takes precedence.

Primary action:

- Start Review.

### 6.3 Active Session

Conditions:

- A recoverable review, practice, or conversation session exists.

Primary action:

- Resume Session.

Due-card information remains visible but secondary.

### 6.4 On Track

Conditions:

- Some daily progress exists.
- Goal is not complete.
- Due work may remain.

Display:

- Remaining goal.
- Next useful action.

### 6.5 Goal Completed

Conditions:

- Daily goal is met.

Display:

- Completion acknowledgment.
- Optional practice.
- Next due information.

Do not create a stronger artificial goal automatically.

### 6.6 No Cards Due

Conditions:

- No cards are currently due.

Display:

- Caught-up state.
- Next due time.
- Optional practice.
- Recent vocabulary.

### 6.7 Offline With Local Data

Display cached:

- Due estimate.
- Goal state.
- Active session.
- Recent vocabulary.
- Difficult words.

Label data freshness where relevant.

### 6.8 Offline Without Local Data

Display:

- Clear explanation.
- Retry.
- Add Word if local creation is supported.
- Nongraded practice only when required content is available.

---

## 7. Header

### 7.1 Title

Use:

```text
Today
```

A localized date may appear as secondary text:

```text
Saturday, October 24
```

### 7.2 Greeting

A greeting is optional.

If used:

- Keep it concise.
- Do not require the user's name.
- Avoid changing the layout based on greeting length.

Example:

```text
Good morning
```

The screen should remain complete without a greeting.

### 7.3 Header actions

Potential actions:

- Language scope.
- Quick Add.
- Sync status.
- More menu.

Start Review belongs in the primary daily-action section rather than being duplicated strongly in the header.

### 7.4 Date boundaries

Today uses the user's local calendar and time zone.

If the system time zone changes:

- Recalculate the daily boundary.
- Preserve already completed review events.
- Avoid creating duplicate daily-goal credit.

---

## 8. Primary daily action

### 8.1 Priority order

Recommended decision order:

```text
1. Authentication or blocking data issue
2. Resume active review
3. Resume active practice or conversation
4. Start due review
5. Complete remaining daily goal
6. Add first word
7. Start relevant optional practice
8. Explore vocabulary
```

### 8.2 Presentation

Contents:

- Clear title.
- One-sentence explanation.
- Progress or workload.
- Primary action.
- Optional secondary action.

Example:

```text
24 cards are ready for review
About 8 minutes based on your recent sessions.

[Start Review]
```

### 8.3 Active-session presentation

Example:

```text
Continue your review
12 of 24 cards completed
Started at 09:20

[Resume Review]   [End Session…]
```

### 8.4 No due cards

Example:

```text
You're caught up
Your next card is due tomorrow at 09:30.

[Practice Difficult Words]
```

### 8.5 Action stability

The primary action must not change unexpectedly while the user is about to click it.

Background synchronization may update counts, but action replacement should:

- Preserve focus.
- Avoid sudden layout movement.
- Wait until the user is not actively interacting where practical.

---

## 9. Due-card summary

### 9.1 Required data

- Total due count.
- English due count where relevant.
- Chinese due count where relevant.
- Overdue count where useful.
- Estimated review duration where reliable.

### 9.2 Presentation

Combined-language example:

```text
24 due
18 English · 6 Chinese
```

Single-language example:

```text
18 English cards due
```

### 9.3 Count semantics

The displayed count must match the Review session source.

Avoid:

- Showing one locally estimated count while Start Review loads a materially different server count without explanation.

### 9.4 Refresh

If synchronization changes the due count:

- Update the summary.
- Preserve an active session.
- Do not inject newly due cards into an existing stable queue.

### 9.5 Navigation

Selecting the due summary may:

- Open Review overview.
- Open Due Today collection.

The action label must clarify the result:

```text
Start Review
View Due Cards
```

---

## 10. Daily goal

### 10.1 Goal model

The daily goal should measure one clearly defined quantity.

Recommended initial measure:

```text
Number of completed review events
```

Potential later goal types:

- Study minutes.
- New words.
- Practice sessions.

Do not combine different quantities into one unexplained score.

### 10.2 Presentation

Show:

- Current value.
- Goal value.
- Progress.
- Completion state.

Example:

```text
Daily goal
12 of 20 reviews
```

### 10.3 Goal configuration

The user configures the goal in Study Settings.

Suggested review-count presets:

```text
5
10
20
30
Custom
```

### 10.4 Goal contribution

Count:

- Accepted FSRS review events.

Do not count:

- Merely opening a card.
- AI-generated practice without a review event.
- Replaying pronunciation.
- Repeated duplicate submissions.

### 10.5 Offline progress

Durably recorded local review events contribute immediately.

The UI may label:

```text
Goal completed · 4 reviews waiting to sync
```

### 10.6 Goal completion

Completion may use:

- Brief visual acknowledgment.
- Updated status.
- Optional summary.

It must respect Reduce Motion.

### 10.7 Goal changes during the day

If the user changes the goal:

- Preserve completed count.
- Recalculate progress.
- Do not rewrite review history.

---

## 11. Streak

### 11.1 Purpose

Streak communicates consistency, not mastery.

### 11.2 Definition

A streak day should have one documented completion rule.

Recommended:

```text
Meet the configured daily review goal.
```

Alternative:

```text
Complete at least one meaningful learning activity.
```

The selected rule must remain consistent across:

- Today.
- Widgets.
- Notifications.
- Insights.
- iOS.

### 11.3 Presentation

Show:

- Current streak.
- Best streak where useful.
- Calendar context in Insights.

Example:

```text
5-day streak
```

### 11.4 Tone

Use neutral, supportive language.

Avoid:

- “Don't lose your streak!”
- Red warnings late in the day.
- Shame-oriented copy.

### 11.5 Time-zone handling

Streak calculation should use:

- User-local date at event time.
- Server-backed or deterministic reconciliation.

Travel and time-zone changes must not generate duplicate days or erase valid history.

### 11.6 Offline streak

Offline events may show a provisional streak.

After synchronization:

- Reconcile authoritatively.
- Avoid disruptive messaging unless a correction is necessary.

---

## 12. Continue session

### 12.1 Supported sessions

- Review.
- Practice.
- Conversation.
- Import where appropriate.

### 12.2 Session priority

Priority:

```text
Active review
→ Active conversation
→ Active structured practice
→ Recoverable import
```

Only one item receives the primary Continue treatment.

Other recoverable jobs may appear in Activity.

### 12.3 Session card

Show:

- Activity type.
- Progress.
- Last activity time.
- Resume.
- End or dismiss where valid.

### 12.4 Stale session

Before resume:

- Validate account.
- Validate local snapshot.
- Reconcile server state.

If invalid:

- Preserve durable completed work.
- Explain recovery.
- Remove stale continuation state.

---

## 13. Difficult words

### 13.1 Purpose

Highlight a manageable set of vocabulary requiring additional attention.

### 13.2 Candidate signals

- Repeated Again grades.
- High lapse count.
- Low recent success.
- High FSRS difficulty.
- Repeated failure in listening or type-in practice.

### 13.3 Rule transparency

The UI should explain:

```text
These words were graded Again at least twice this week.
```

Avoid:

```text
AI thinks these are difficult.
```

unless an AI-derived rule is explicitly implemented and explained.

### 13.4 Content

Show:

- Count.
- Up to several word previews.
- Reason.
- Open Collection.
- Start Practice.

### 13.5 Empty state

If no words qualify:

- Omit the section or show a low-emphasis positive state.
- Do not manufacture weak words.

### 13.6 Navigation

Open Collection:

```text
/vocabulary/difficult
```

Start Practice:

- Opens configured Practice with difficult-word context.

---

## 14. Suggested practice

### 14.1 Purpose

Recommend one useful optional practice activity.

### 14.2 Candidate practice types

- Vocabulary drill.
- Reading comprehension.
- Listening practice.
- Word comparison.
- Conversation scenario.
- Chinese character practice.

### 14.3 Recommendation inputs

Allowed inputs:

- Due-card composition.
- Difficult words.
- Recently added vocabulary.
- Language.
- User preferences.
- Recent practice activity.
- Content availability.

### 14.4 Recommendation rules

Initial recommendations should be deterministic and explainable.

Examples:

```text
If 5 or more difficult cards share a topic
→ Suggest a topic-based drill.

If 8 or more words were added in the past 7 days
→ Suggest a reading passage using recent words.

If Chinese words lack recent writing practice
→ Suggest character practice.

If listening accuracy is lower than recognition accuracy
→ Suggest listening practice.
```

### 14.5 AI use

AI may generate the practice content after the user starts it.

AI should not be required to choose the recommendation.

### 14.6 Recommendation presentation

Show:

- Activity.
- Source vocabulary.
- Reason.
- Estimated length where reliable.
- Start.
- Replace or dismiss.

### 14.7 Dismissal

Dismiss:

- Applies for the current day or recommendation cycle.
- Does not delete vocabulary.
- Does not penalize the user.

### 14.8 No recommendation

If insufficient data exists:

- Show a general Explore Practice action.
- Do not invent a personalized claim.

---

## 15. Recent vocabulary

### 15.1 Purpose

Provide quick access to recently added words.

### 15.2 Content

Show up to:

```text
5–8 recent items
```

Each item may include:

- Word or Hanzi.
- Pronunciation or pinyin.
- Concise meaning.
- Added time.
- Favorite.

### 15.3 Interaction

Selecting an item:

- Opens exact Vocabulary detail.

Context menu may offer:

- Play Pronunciation.
- Favorite.
- Start Practice.

### 15.4 Empty state

If no recent vocabulary:

- Offer Add Word.
- Offer Import.
- Offer Quick Lookup.

### 15.5 Language behavior

Respect selected language scope.

Combined view must visibly identify each item's language.

---

## 16. Weekly summary

### 16.1 Purpose

Give a compact sense of recent consistency.

Detailed exploration belongs in Insights.

### 16.2 Candidate metrics

- Cards reviewed.
- Learning days.
- Added vocabulary.
- Goal-completion days.
- Retention estimate.
- Study time when measured reliably.

### 16.3 Initial recommendation

Show no more than three primary values:

```text
86 reviews
4 learning days
82% retention
```

### 16.4 Date window

Use a clearly defined interval:

```text
Past 7 days
```

or:

```text
This calendar week
```

The label must clarify which is used.

### 16.5 Navigation

Open Insights:

```text
/insights/activity
```

### 16.6 Insufficient data

Show:

- What is available.
- A simple explanation that more activity is needed.

Do not show misleading percentages from tiny samples.

---

## 17. Language progress

### 17.1 Purpose

Help learners studying both English and Chinese understand workload and activity by language.

### 17.2 Data

Potential summary:

- Active vocabulary count.
- Due count.
- Reviews this week.
- Recent additions.
- Daily-goal contribution.

### 17.3 Presentation

For combined-language users:

```text
English
1,240 words · 18 due

Chinese
320 words · 6 due
```

### 17.4 Single-language user

Do not show an empty comparison.

Use the space for:

- Recent progress.
- Suggested practice.
- Next due information.

### 17.5 Navigation

Selecting a language summary:

- Opens Vocabulary filtered to that language.

---

## 18. Daily completion state

### 18.1 Conditions

Daily completion may mean:

- Goal completed.
- No cards due.
- Active session completed.

These states are related but not identical.

### 18.2 Copy examples

Goal completed with future due cards:

```text
Daily goal complete
You reviewed 20 cards today. 8 more cards are available if you want to continue.
```

No cards due:

```text
You're caught up
Your next review is tomorrow.
```

Both:

```text
All done for today
Your goal is complete and no cards are currently due.
```

### 18.3 Optional activity

Offer:

- Practice Difficult Words.
- Read with Recent Vocabulary.
- Explore Vocabulary.

These remain secondary.

### 18.4 Celebration

Use:

- Brief state transition.
- Small brand accent.
- Optional subtle animation.

Respect Reduce Motion and avoid repetitive confetti.

---

## 19. First-run state

### 19.1 Goals

Teach the core loop:

```text
Add → Review → Practice
```

### 19.2 Primary action

```text
Add Your First Word
```

### 19.3 Secondary actions

- Import Vocabulary.
- Open Quick Lookup.
- View Example.

### 19.4 Education

Use concise copy:

```text
Save words you encounter, then Voca schedules them for review.
```

Do not present a long multi-step onboarding wizard unless user research shows it is necessary.

### 19.5 Sample data

If sample vocabulary is offered:

- Clearly label it.
- Require deliberate addition.
- Do not mix sample cards into user data silently.

---

## 20. Recommendation engine

### 20.1 Architecture

Today recommendations should be produced by an application-level service:

```text
TodayRecommendationService
```

Inputs:

- Today snapshot.
- Due state.
- Difficult words.
- Recent vocabulary.
- Practice history.
- User settings.
- Language scope.
- Available capabilities.

Output:

```swift
struct TodayRecommendation: Sendable {
    let kind: RecommendationKind
    let title: String
    let reason: RecommendationReason
    let vocabularySource: VocabularySource?
    let estimatedDuration: Duration?
    let route: AppRoute
}
```

### 20.2 Deterministic first release

The first implementation should use a rule engine rather than opaque AI ranking.

Benefits:

- Predictability.
- Testability.
- Low latency.
- No generation cost before user action.
- Clear explanations.
- Offline capability.

### 20.3 Priority scoring

Illustrative priority:

```text
Blocking session recovery       100
Due review                       90
Remaining daily goal             80
Difficult-word practice          60
Recent-vocabulary reading        50
Listening weakness               45
General practice                 20
```

The exact score belongs in implementation tests, not user-facing UI.

### 20.4 Recommendation frequency

One primary recommendation per Today load.

Avoid changing it during minor background refreshes unless:

- The recommended task was completed.
- Its source became invalid.
- The user requested another recommendation.

### 20.5 Feedback

Optional user feedback:

- Not Relevant.
- Show Another.

Feedback should adjust future deterministic preferences without requiring content-level analytics.

---

## 21. Data model

Illustrative snapshot:

```swift
struct TodaySnapshot: Sendable {
    let localDate: Date
    let generatedAt: Date
    let dueSummary: DueSummary
    let dailyGoal: DailyGoalProgress
    let streak: StreakSummary
    let activeSession: RecoverableSession?
    let difficultWords: [VocabularySummary]
    let recentWords: [VocabularySummary]
    let weeklySummary: WeeklyLearningSummary
    let languageSummaries: [LanguageLearningSummary]
    let synchronization: SynchronizationSummary
}
```

### 21.1 Snapshot source

Compose from local repositories first:

```text
Vocabulary repository
Review repository
Activity repository
Session repository
Settings repository
```

Then refresh from synchronized server state.

### 21.2 Snapshot consistency

The displayed values should represent one coherent local generation point where practical.

Avoid independently loading every tile in a way that causes persistent count disagreement.

---

## 22. State model

Illustrative feature state:

```swift
@MainActor
@Observable
final class TodayFeature {
    enum Phase {
        case idle
        case loading
        case loaded
        case refreshing
        case failed(AppError)
    }

    private(set) var phase: Phase = .idle
    private(set) var snapshot: TodaySnapshot?
    private(set) var recommendation: TodayRecommendation?

    var languageScope: LanguageScope = .all

    func load() async
    func refresh() async
    func performPrimaryAction()
    func dismissRecommendation()
    func requestAnotherRecommendation()
}
```

### 22.1 State ownership

Today owns:

- Dashboard presentation.
- Language scope.
- Recommendation presentation.
- Refresh state.

Today does not own:

- Review-session internals.
- Vocabulary canonical entities.
- Practice-session internals.
- Synchronization engine.

---

## 23. Loading and refresh

### 23.1 Cached load

When a local snapshot exists:

1. Render immediately.
2. Mark refreshing subtly.
3. Synchronize in background.
4. Recompose snapshot.
5. Update only changed sections.

### 23.2 First load

Without local data:

- Preserve main window structure.
- Show section placeholders.
- Avoid displaying invented zero values.

### 23.3 Manual refresh

Refresh action:

- Synchronizes account data.
- Rebuilds Today snapshot.
- Preserves focus.
- Does not duplicate active sessions.

### 23.4 Refresh failure

When cache exists:

- Keep cached content.
- Show last-updated information.
- Offer Retry.

Without cache:

- Show scoped error state.

---

## 24. Offline behavior

### 24.1 Available offline

When cached:

- Due summary.
- Daily goal.
- Streak estimate.
- Recent vocabulary.
- Difficult words.
- Weekly summary.
- Active-session state.

### 24.2 Offline primary action

If a valid local review queue can be built:

- Allow Start Review.

If not:

- Offer cached nongraded practice.
- Explain that due status needs synchronization.

### 24.3 Offline goal

Completed local review events update the daily goal immediately.

Display pending synchronization separately.

### 24.4 Offline recommendation

Only recommend an activity that:

- Has necessary local content.
- Does not require unavailable AI generation.
- Can start safely offline.

### 24.5 Data freshness

Example:

```text
Offline · Updated 2 hours ago
```

Avoid repeating this label on every section.

---

## 25. Synchronization behavior

### 25.1 Successful refresh

Update:

- Due counts.
- Goal progress.
- Recent words.
- Difficult words.
- Weekly metrics.
- Streak.

### 25.2 Active session protection

Synchronization must not:

- Replace an active review queue.
- Reset progress.
- Remove locally durable completed grades.

### 25.3 Count disagreement

If local and server due counts differ materially:

- Use server-authoritative count after successful reconciliation.
- Keep active-session count independent.
- Avoid alarming copy unless user action is required.

### 25.4 Pending changes

Today may show one compact status:

```text
4 changes waiting to sync
```

Detailed operations belong in Activity.

### 25.5 Action-required sync failure

Show:

- Concise warning.
- Open Activity.
- Retry if appropriate.

Do not block Today if local content remains usable.

---

## 26. Navigation behavior

### 26.1 Start Review

Route:

```text
/review
```

or directly to session setup according to current preference.

### 26.2 Resume Review

Route:

```text
/review/session/{sessionID}
```

### 26.3 Difficult Words

Route:

```text
/vocabulary/difficult
```

### 26.4 Recent word

Route:

```text
/vocabulary/word/{userCardID}
```

### 26.5 Suggested practice

Route:

```text
/practice/{type}
```

with an explicit vocabulary source.

### 26.6 Weekly summary

Route:

```text
/insights/activity
```

### 26.7 Language summary

Route:

```text
/vocabulary/all
```

with selected language scope.

---

## 27. Keyboard behavior

### 27.1 Primary action

The primary action should participate naturally in tab order.

Potential shortcut:

```text
Command + R    Start or resume review
```

### 27.2 Section navigation

Users should be able to:

- Tab through actionable sections.
- Open with Return.
- Use context menus where relevant.

### 27.3 Global shortcuts

```text
Command + N         Add Word
Command + R         Start Review
Command + K         Command Palette
Option + Space      Quick Lookup
```

### 27.4 Focus restoration

Returning from:

- Word detail restores focus to the recent word.
- Practice restores focus to the recommendation.
- Review completion returns focus to an updated primary-action section.

---

## 28. Accessibility

### 28.1 Reading order

Recommended:

1. Today title and date.
2. Primary daily action.
3. Goal.
4. Due summary.
5. Difficult words.
6. Suggested practice.
7. Recent vocabulary.
8. Weekly summary.
9. Language summaries.
10. Synchronization status.

Visual layout may use two columns, but accessibility order must remain logical.

### 28.2 Section labels

Each section exposes:

- Heading.
- Summary.
- Action.

### 28.3 Progress

Example accessible value:

```text
Daily goal, 12 of 20 reviews completed, 60 percent
```

### 28.4 Streak

Example:

```text
Current streak, 5 days
```

Do not rely on a flame icon alone.

### 28.5 Due count

Example:

```text
24 cards due, 18 English and 6 Chinese
```

### 28.6 Recommendation

VoiceOver should receive both:

- Recommended activity.
- Reason.

### 28.7 Color

Goal state, sync state, and language state require text or icon labels in addition to color.

### 28.8 Larger text

At larger sizes:

- Summary values wrap.
- Primary action remains visible.
- Two-column sections stack.
- Cards expand vertically.

### 28.9 Reduced Motion

- Completion animation becomes a simple state change.
- Tile reordering does not animate spatially.
- Progress changes remain understandable.

---

## 29. Visual hierarchy

### 29.1 Level 1

Primary daily action.

### 29.2 Level 2

- Daily goal.
- Due summary.
- Active session progress.

### 29.3 Level 3

- Difficult words.
- Suggested practice.
- Recent vocabulary.

### 29.4 Level 4

- Weekly summary.
- Streak.
- Language breakdown.
- Sync metadata.

### 29.5 Container use

Use:

- One prominent daily-action surface.
- A limited number of summary sections.
- Whitespace and alignment.

Avoid:

- A dozen equally weighted rounded cards.
- Large decorative banners.
- Duplicate review counts in several locations.

---

## 30. Performance

### 30.1 Initial render

Today should render cached content without waiting for:

- Full remote synchronization.
- AI recommendation generation.
- Complete review history.
- Full Insights aggregation.

### 30.2 Aggregation

Weekly summaries should be:

- Pre-aggregated locally.
- Retrieved from an aggregate endpoint.
- Computed efficiently from indexed events.

Do not scan the full review history on the main thread during every appearance.

### 30.3 Section loading

Heavy optional sections may load after the primary action.

Priority:

```text
Active session
Due summary
Daily goal
Recent words
Difficult words
Recommendation
Weekly summary
```

### 30.4 Recommendation

Deterministic recommendation selection should complete locally and quickly.

AI content generation starts only after the user chooses the activity.

---

## 31. Privacy and analytics

### 31.1 Allowed analytics

- Today opened.
- Primary action type shown.
- Primary action invoked.
- Recommendation type shown.
- Recommendation dismissed.
- Section navigation.
- Technical load duration.

### 31.2 Disallowed analytics

- Word text.
- Meaning.
- Personal notes.
- Tag names.
- Recommendation source vocabulary content.
- AI prompt content.

### 31.3 Local inference

Recommendation selection should occur locally where practical.

The dashboard should not send the complete learning library to an external recommendation service.

---

## 32. Error behavior

### 32.1 Due-summary error

If cached data exists:

- Show cached count.
- Mark refresh failure.

If no cached data exists:

- Explain that due cards cannot currently be calculated.
- Offer Retry.

### 32.2 Goal error

If completed reviews exist locally:

- Show local progress.
- Mark pending reconciliation.

### 32.3 Recommendation error

- Omit the recommendation or show Explore Practice.
- Do not turn the whole dashboard into an error state.

### 32.4 Recent-vocabulary error

- Keep other sections available.
- Offer section-level retry if useful.

### 32.5 Authentication expiry

- Preserve safe route.
- Request sign-in.
- Restore Today after authentication.

### 32.6 Local database failure

This is a global blocking state:

- Explain the issue.
- Offer safe recovery or diagnostics.
- Avoid showing invented zero values.

---

## 33. Empty and edge states

### 33.1 No vocabulary

- Add First Word.
- Import.
- Quick Lookup.

### 33.2 Vocabulary exists but never reviewed

- Explain Review.
- Show eligible new-card behavior according to backend policy.
- Start First Review.

### 33.3 Goal absent

If daily goal is optional and unset:

- Show Set Daily Goal.
- Do not display `0 of 0`.

### 33.4 Streak absent

Show:

```text
Start a learning streak
```

only if supportive and useful.

Otherwise omit.

### 33.5 No difficult words

- Omit or show a subtle positive state.

### 33.6 No recent words

- Add Word.
- Import.

### 33.7 Future clock anomaly

If local date appears invalid relative to server reconciliation:

- Avoid awarding duplicate day progress.
- Show safe current state.
- Log a diagnostic without exposing internals.

---

## 34. Testing strategy

### 34.1 Recommendation tests

- Active session outranks due review.
- Due review outranks optional practice.
- Difficult-word recommendation has a valid source.
- Dismissed recommendation does not immediately return.
- Offline recommendation uses only available capability.

### 34.2 Daily-goal tests

- One accepted review contributes once.
- Duplicate event does not increase progress.
- Offline event contributes provisionally.
- Goal change recalculates correctly.
- Local date boundary is correct.

### 34.3 Streak tests

- Consecutive qualifying days.
- Missed day.
- Time-zone change.
- Offline event reconciliation.
- Duplicate event.

### 34.4 State tests

- First run.
- Due work.
- Active session.
- Goal complete.
- No cards due.
- Offline with cache.
- Offline without cache.
- Partial section failure.

### 34.5 Navigation tests

- Start Review.
- Resume Review.
- Open Difficult Words.
- Open recent word.
- Start recommendation.
- Open Insights.

### 34.6 UI tests

- Cached dashboard appears.
- Refresh updates count.
- Primary action remains stable.
- Narrow window stacks sections.
- Larger text remains usable.

### 34.7 Accessibility tests

- Logical VoiceOver order.
- Action labels.
- Goal progress value.
- Keyboard-only navigation.
- Increased Contrast.
- Reduce Motion.

---

## 35. Requirement traceability

### `TODAY-001` — Daily summary

Covered by:

- Daily-state model.
- Due-card summary.
- Daily goal.
- Primary action.
- Empty and completed states.

### `TODAY-002` — Continue learning

Covered by:

- Continue-session section.
- Session priority.
- Resume validation.
- Stale-session recovery.

### `TODAY-003` — Difficult cards

Covered by:

- Candidate signals.
- Rule transparency.
- Open Collection.
- Start Practice.

### `TODAY-004` — Suggested practice

Covered by:

- Recommendation inputs.
- Deterministic rules.
- User-facing reason.
- Dismiss and replace.

### `TODAY-005` — Weekly summary

Covered by:

- Compact metrics.
- Defined date window.
- Insights navigation.
- Insufficient-data state.

---

## 36. Acceptance scenarios

### Scenario A — User with due cards

1. Open Today.
2. Verify due count.
3. Verify Start Review is primary.
4. Start Review.
5. Complete several cards.
6. Return to Today.

Expected:

- Due and goal counts update.
- Completed reviews contribute once.
- Primary action reflects current state.

### Scenario B — Active review

1. Start Review.
2. Complete part of the queue.
3. Pause.
4. Open Today.

Expected:

- Resume Review is primary.
- Progress is correct.
- Starting a second conflicting session is not encouraged.

### Scenario C — Goal complete

1. Complete the configured goal.
2. Return to Today.

Expected:

- Goal completion is acknowledged.
- Optional activities remain secondary.
- No pressure-oriented warning appears.

### Scenario D — No cards due

1. Synchronize an account with no due cards.
2. Open Today.

Expected:

- Caught-up state appears.
- Next due information appears when available.
- Practice is optional.

### Scenario E — First-time user

1. Sign in with no vocabulary.
2. Open Today.

Expected:

- Add First Word is primary.
- Import and Quick Lookup are available.
- No empty charts or `0 of 0` metrics appear.

### Scenario F — Offline with cache

1. Load Today online.
2. Disconnect.
3. Relaunch.

Expected:

- Cached content appears.
- Data freshness is visible.
- Valid local review can start if supported.

### Scenario G — Offline review updates goal

1. Review cached cards offline.
2. Return to Today.

Expected:

- Daily goal updates immediately.
- Pending-sync count is separate.
- Reconnection does not double progress.

### Scenario H — Recommendation

1. Add enough recent words to qualify for reading practice.
2. Open Today.
3. Inspect recommendation.

Expected:

- Reason references recent vocabulary.
- Starting practice passes the correct vocabulary source.
- AI generation begins only after user action.

### Scenario I — Chinese learner

1. Use Chinese-only language scope.
2. Open Today.

Expected:

- Chinese due count and recent Hanzi appear.
- Mandarin-specific practice may be recommended.
- Empty English comparison is not shown.

### Scenario J — Accessibility

1. Enable VoiceOver and larger text.
2. Open Today.
3. Navigate all sections.
4. Start Review using keyboard.

Expected:

- Reading order is logical.
- Goal and due summaries are understandable.
- Layout stacks without clipping.

---

## 37. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Today presents one primary daily action.
2. Resume active review outranks starting a new activity.
3. Due review outranks optional generated practice.
4. Review count is the initial daily-goal measure.
5. Goal progress includes durable offline review events.
6. Recommendations are deterministic and explainable in the first release.
7. AI generates practice content only after user action.
8. Weekly summary contains no more than three primary metrics.
9. Streak remains secondary to due work and goal progress.
10. Completed-day state does not create artificial study pressure.
11. Cached Today content renders before remote refresh completes.
12. Detailed analytics remain in Insights.

---

## 38. Open questions

1. Is Today or Vocabulary the default destination after sign-in?
2. Is the daily goal review count, study time, or user-selectable?
3. What exactly qualifies a streak day?
4. Is the weekly summary based on the past seven days or calendar week?
5. Does the backend expose aggregate daily and weekly metrics?
6. Can due counts be calculated reliably from cached study state?
7. How fresh must cached data be for offline Start Review?
8. Which session types are recoverable and shown on Today?
9. How are difficult words classified?
10. Should Today support `All Languages` in the first release?
11. Should the primary recommendation be dismissible for one day or permanently by type?
12. Should estimated review duration be displayed?
13. Should Recently Added show five, six, or eight words?
14. Should Today remember collapsed sections?
15. Should daily goal completion trigger a notification or only in-app feedback?
16. How does iOS calculate streak and daily-goal progress today?
17. Should optional practice contribute to another visible progress measure?
18. How should time-zone travel affect streak and daily goal?

---

## 39. Backend and data dependencies

The complete Today experience may require:

- Due summary by language.
- Stable daily review-event history.
- Daily-goal setting.
- Streak calculation or reconcilable activity events.
- Difficult-word criteria.
- Recent vocabulary query.
- Weekly aggregate metrics.
- Active-session persistence.
- Synchronization status.
- Next due timestamp.
- Language-specific activity summaries.

If aggregate endpoints do not exist, the client may derive values from local synchronized events, provided:

- Rules match other clients.
- Large histories are indexed.
- Time-zone behavior is deterministic.
- Server reconciliation remains possible.

---

## 40. Definition of done

Today is complete for the first public release when:

- It presents the correct primary action for all major account states.
- Due count matches Review.
- Daily-goal progress is deterministic.
- Active sessions can be resumed safely.
- Difficult words have an explainable rule.
- Suggested practice identifies its reason and source.
- Recent vocabulary navigates to exact word detail.
- Weekly summary uses reliable aggregate data.
- English and Chinese scopes work.
- Cached content renders offline.
- Pending synchronization is understandable.
- Goal completion does not duplicate after event retry.
- VoiceOver, keyboard, larger text, Increased Contrast, and Reduce Motion pass.
- Critical state, recommendation, navigation, and synchronization tests pass.

---

## 41. Next document

The next document should be:

```text
docs/macos-data-and-sync.md
```

It should define:

- Local database requirements.
- Account partitioning.
- Record schemas.
- Sync cursors.
- Pull and push cycles.
- Mutation queue.
- Review-event idempotency.
- Conflict handling.
- Tombstones.
- Offline capability by feature.
- Background synchronization.
- Activity states.
- Migration.
- Recovery.
- Security.
- Performance.
- Test matrix.
