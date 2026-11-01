# Voca for macOS — Practice and AI

> Product, UX, architecture, privacy, streaming, persistence, accessibility, and acceptance specification for practice, Assistant, and conversation experiences on macOS.

## Document status

- **Status:** Draft
- **Document type:** Feature and Architecture Specification
- **Target platform:** macOS 14 or later
- **Related overview:** [`macos-overview.md`](macos-overview.md)
- **Related requirements:** [`macos-product-requirements.md`](macos-product-requirements.md)
- **Related information architecture:** [`macos-information-architecture.md`](macos-information-architecture.md)
- **Related architecture:** [`macos-architecture.md`](macos-architecture.md)
- **Related design system:** [`macos-design-system.md`](macos-design-system.md)
- **Related vocabulary specification:** [`macos-vocabulary.md`](macos-vocabulary.md)
- **Related review specification:** [`macos-review.md`](macos-review.md)
- **Related Today specification:** [`macos-today.md`](macos-today.md)
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Primary requirement group:** `AI-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines the complete practice and AI-assisted learning experience for Voca on macOS.

It covers:

- Practice information architecture.
- Practice-session configuration.
- Vocabulary grounding.
- Multiple-choice drills.
- Reading comprehension.
- Listening practice.
- Writing practice.
- Word comparison.
- Assistant workspace.
- Conversation practice.
- Context selection.
- AI request lifecycle.
- Streaming responses.
- Request cancellation.
- Provider and model settings.
- Generated-content labeling.
- Session and conversation persistence.
- Vocabulary extraction from generated content.
- Offline behavior.
- Privacy and explicit content transmission.
- Cost and rate control.
- Accessibility.
- Performance.
- Error handling.
- Testing and acceptance criteria.

The purpose of AI in Voca is to create useful learning interactions from the learner's vocabulary. AI is not the product's navigation model and must not replace deterministic study behavior such as FSRS review.

---

## 2. Product intent

Practice should help learners move beyond recognition into practical language use.

It should answer needs such as:

- Can I distinguish similar words?
- Can I understand this vocabulary in context?
- Can I recognize it by sound?
- Can I use it in a sentence?
- Can I respond naturally in a conversation?
- Can I understand why my answer is incorrect?

The Assistant should support focused language-learning tasks:

- Explain.
- Compare.
- Correct.
- Generate examples.
- Create exercises.
- Analyze text.
- Extract vocabulary.
- Simulate a conversation.

The experience should not become:

- An unstructured generic chatbot.
- A replacement for reliable dictionary content.
- An opaque system that silently sends user content.
- A mechanism that changes FSRS state without explicit review.
- A source of unlimited, uncontrolled generation cost.

---

## 3. Product principles

### AI-PRN-001 — Vocabulary grounding is visible

Users should understand which words, collections, or documents are being used.

### AI-PRN-002 — Generation is explicit

Content is sent to an AI provider only after a clear user action.

### AI-PRN-003 — Practice and review remain separate

Practice results may inform insights and recommendations, but they do not silently submit FSRS grades.

### AI-PRN-004 — Deterministic UI surrounds probabilistic content

Navigation, answer recording, progress, persistence, and permissions remain deterministic even when exercise content is generated.

### AI-PRN-005 — Generated content is labeled

Users must be able to distinguish:

- Canonical dictionary data.
- User-authored content.
- AI-generated content.

### AI-PRN-006 — Context is minimal

Only content necessary for the selected task is transmitted.

### AI-PRN-007 — Streaming remains controllable

Users can stop generation, retain completed content, and recover from partial failure.

### AI-PRN-008 — AI failure does not block core learning

Vocabulary browsing, pronunciation, Today, and FSRS review must remain usable without AI.

### AI-PRN-009 — Feedback is instructional

Practice feedback should explain relevant language differences rather than merely display Correct or Incorrect.

### AI-PRN-010 — Generated content is not assumed correct

Users should be able to report, regenerate, or edit unsuitable generated material.

---

## 4. Scope

### 4.1 Included

- Practice home.
- Practice-type selection.
- Vocabulary source selection.
- Difficulty and language configuration.
- Multiple-choice drills.
- Reading comprehension.
- Listening practice.
- Sentence completion.
- Word comparison.
- Error correction.
- Assistant workspace.
- Conversation practice.
- Streaming.
- Cancellation.
- Session progress.
- Feedback.
- Generated-content labeling.
- Save useful vocabulary.
- Local session summaries.
- Provider settings.
- Privacy controls.

### 4.2 Related but specified elsewhere

- FSRS reviews.
- Today recommendations.
- Vocabulary management.
- Document import and OCR.
- TTS and speech settings.
- General synchronization.
- Security and privacy foundation.
- Notifications.
- System integrations.

### 4.3 Excluded from the initial release

- Fully local large-language-model inference.
- Fully automated pronunciation scoring.
- Unmoderated public prompt sharing.
- Social leaderboards.
- Teacher classroom management.
- Collaborative real-time practice.
- Automatic AI decisions that modify card scheduling.
- Unlimited background generation.
- Automatic upload of imported documents.

---

## 5. Practice information architecture

Primary route:

```text
/practice
```

Practice routes:

```text
/practice/drills
/practice/reading
/practice/listening
/practice/writing
/practice/compare
/practice/correction
/practice/session/{sessionID}
/practice/summary/{sessionID}
```

Assistant routes:

```text
/assistant
/assistant/conversation/{conversationID}
```

Conversation routes:

```text
/conversation
/conversation/setup
/conversation/session/{sessionID}
/conversation/summary/{sessionID}
```

### 5.1 Practice home

Practice home contains:

- Recommended activity.
- Practice types.
- Vocabulary-source selector.
- Recent sessions.
- Continue active session.
- Language scope.

### 5.2 Practice configuration

Configuration owns:

- Practice type.
- Language.
- Vocabulary source.
- Difficulty.
- Number of questions.
- Audio behavior.
- Optional topic.

### 5.3 Active practice

Active practice owns:

- Generated exercise.
- Current item.
- Answer state.
- Feedback.
- Progress.
- Pause and resume.

### 5.4 Summary

Summary owns:

- Completion count.
- Accuracy.
- Difficult items.
- Useful feedback.
- Suggested next action.

---

## 6. Practice home

Recommended layout:

```text
┌──────────────────────────────────────────────────────────────┐
│ Practice                           Language      New Practice │
├──────────────────────────────────────────────────────────────┤
│ Recommended                                                   │
│ Reading with 12 recently added words       [Start]            │
├──────────────────────────┬───────────────────────────────────┤
│ Drills                   │ Reading                           │
│ Quick multiple choice    │ Vocabulary in context            │
├──────────────────────────┼───────────────────────────────────┤
│ Listening                │ Conversation                      │
│ Recognize spoken words   │ Practice a real scenario         │
├──────────────────────────┴───────────────────────────────────┤
│ Recent sessions                                               │
└──────────────────────────────────────────────────────────────┘
```

### 6.1 Activity cards

Each activity displays:

- Practice type.
- Short purpose.
- Supported language.
- Estimated scope.
- Start action.

### 6.2 Recommended activity

The source and reason must be visible.

Example:

```text
Practice your difficult work vocabulary
These 8 words were graded Again several times this week.
```

### 6.3 Recent sessions

Show:

- Type.
- Date.
- Vocabulary source.
- Completion state.
- Accuracy where meaningful.
- Resume or View Summary.

### 6.4 Empty state

If no vocabulary exists:

- Add Word.
- Import Vocabulary.
- Try a sample practice set only after explicit selection.

---

## 7. Vocabulary grounding

### 7.1 Vocabulary sources

Supported sources:

```text
Due cards
Difficult words
Recently added
Favorites
Smart List
Selected vocabulary
Tag
Topic
Imported text candidates
Manual word selection
```

### 7.2 Source summary

Before generation, show:

- Source name.
- Number of words.
- Language.
- Sample words.

### 7.3 Context limit

If the source contains too many words:

- Select a bounded subset.
- Explain the selection rule.
- Let the user adjust the count.

### 7.4 Selection rule

Potential selection order:

1. Target difficult words.
2. Recently due words.
3. Recently added words.
4. Randomized supporting words.

### 7.5 Source stability

Once a session starts:

- Persist selected word IDs.
- Do not silently replace them during synchronization.

### 7.6 Personal notes

Personal notes are excluded from AI context by default.

If included:

- The user must explicitly enable them.
- A context preview must identify this.

### 7.7 Missing words

If a source word is deleted or unavailable:

- Remove it before generation.
- Update the visible count.
- Avoid failing the whole request when enough valid content remains.

---

## 8. Practice configuration

### 8.1 Required fields

- Practice type.
- Language.
- Vocabulary source.

### 8.2 Optional fields

- Difficulty.
- Question count.
- Topic.
- Tone.
- Include audio.
- Include explanations.
- Include translations.

### 8.3 Difficulty

Suggested levels:

```text
Easy
Balanced
Challenging
```

If mapped to CEFR or HSK:

- Show the actual scale.
- Avoid pretending exact equivalence between systems.

### 8.4 Question-count presets

```text
5
10
15
Custom
```

### 8.5 Estimated cost

If provider cost is user-controlled or material:

- Show a concise estimate or request size.
- Do not claim exact price unless the provider contract supports it.

### 8.6 Generate action

Before generation:

- Validate source.
- Show what context will be used.
- Require explicit start.

---

## 9. Practice session lifecycle

State model:

```text
Configuring
Preparing Context
Generating
Ready
Presenting Item
Showing Feedback
Paused
Completing
Completed
Cancelled
Recoverable Error
```

### 9.1 Configuring

The user selects source and options.

### 9.2 Preparing Context

Voca:

- Resolves word entities.
- Removes invalid items.
- Minimizes context.
- Builds a user-visible summary.

### 9.3 Generating

Voca:

- Starts one explicit request.
- Streams progress where supported.
- Allows cancellation.

### 9.4 Ready

The generated exercise has passed structural validation.

### 9.5 Presenting Item

The user answers one exercise item.

### 9.6 Showing Feedback

Voca presents:

- Correctness.
- Correct answer.
- Concise explanation.
- Relevant target vocabulary.

### 9.7 Paused

Session remains recoverable when content has been generated and saved locally.

### 9.8 Completed

Summary is generated locally from recorded answers.

---

## 10. Generated exercise validation

AI output must be validated before becoming an interactive exercise.

### 10.1 Structural validation

Check:

- Required fields exist.
- Question count is within limits.
- Answer IDs are valid.
- Correct answer refers to an available choice.
- Target vocabulary exists.
- Language matches request.
- Content length is reasonable.

### 10.2 Semantic sanity checks

Where deterministic checks are possible:

- No duplicate answer IDs.
- No identical answer choices.
- Target word appears as intended.
- Listening item has playable text or audio source.
- Cloze item contains one clear blank.

### 10.3 Invalid generation

If invalid:

- Attempt bounded repair once where supported.
- Otherwise show Regenerate.
- Preserve configuration.
- Do not present broken controls.

### 10.4 Partial generation

If some items are valid:

- Product decision may allow a shorter exercise.
- Clearly show actual item count.

Do not silently claim the requested count was produced.

---

## 11. Multiple-choice drills

### 11.1 Purpose

Drills provide quick distinction and recall practice.

### 11.2 Question types

```text
Word → Meaning
Meaning → Word
Example → Missing Word
Audio → Word
Hanzi → Meaning
Meaning → Hanzi
Pinyin → Hanzi
Similar Word Distinction
```

### 11.3 Question anatomy

- Progress.
- Prompt.
- Optional audio.
- Answer choices.
- Submit.
- Feedback.
- Next.

### 11.4 Choice count

Recommended:

```text
4 choices
```

Fewer may be used when valid distractors are unavailable.

### 11.5 Distractors

Distractors should:

- Match language.
- Be plausible.
- Avoid obvious formatting clues.
- Not duplicate the correct answer.
- Prefer vocabulary near the learner's level.

### 11.6 Keyboard

```text
1–4       Select option
Return    Submit
N         Next, when feedback is visible
Option+P  Play audio
```

Letter shortcuts must not trigger while text input has focus.

### 11.7 Feedback

Correct:

- Confirm.
- Explain briefly where useful.

Incorrect:

- Show correct answer.
- Explain the distinction.
- Link target word detail.

### 11.8 FSRS relationship

Drill answers do not submit FSRS grades.

The summary may offer:

```text
Review these difficult words
```

which starts an explicit review or practice flow.

---

## 12. Reading comprehension

### 12.1 Purpose

Use target vocabulary in coherent context.

### 12.2 Configuration

- Vocabulary source.
- Language.
- Difficulty.
- Passage length.
- Topic.
- Question count.
- Include translation.

### 12.3 Passage structure

The reading view contains:

- Title.
- Passage.
- Target-word highlights.
- Pronunciation actions where useful.
- Questions.
- Vocabulary panel.

### 12.4 Reading width

Use a centered reading column:

```text
55–80 characters per line
```

### 12.5 Target-word highlighting

Highlight:

- Subtly.
- Without relying only on color.
- With hover or focus detail.

Selecting a target word:

- Shows concise definition.
- Plays pronunciation.
- Opens full detail.

### 12.6 Questions

Types:

- Main idea.
- Detail.
- Vocabulary in context.
- Inference.
- True or false.

### 12.7 Answer timing

Users may:

- Answer after reading.
- Refer back to the passage.

Do not hide the passage to create artificial memory difficulty unless a dedicated mode is selected.

### 12.8 Translation

Translation:

- Is hidden by default at appropriate levels.
- Can be revealed explicitly.
- Is labeled as generated when AI-produced.

### 12.9 Chinese reading

Optional supports:

- Pinyin on demand.
- Sentence audio.
- Character lookup.
- Vietnamese translation.

Pinyin should not be forced on advanced learners.

---

## 13. Listening practice

### 13.1 Purpose

Train recognition of spoken vocabulary and connected speech.

### 13.2 Activity types

```text
Audio → Choose Word
Audio → Choose Meaning
Dictation
Dialogue Comprehension
Sentence Completion
```

### 13.3 Audio generation

Audio may come from:

- Existing cached card audio.
- Configured TTS.
- Generated dialogue TTS.

### 13.4 Playback controls

- Play.
- Pause.
- Replay.
- Speed.
- Optional sentence repeat.

### 13.5 Speed

Suggested:

```text
0.75×
1.0×
1.25×
```

Avoid speech distortion where provider or playback engine handles rate poorly.

### 13.6 Transcript

Transcript:

- Hidden before answer when appropriate.
- Revealed with feedback.
- Accessible to VoiceOver after reveal.

### 13.7 Audio failure

- Retry.
- Use system voice fallback if approved.
- Switch to text mode.
- Preserve progress.

### 13.8 Offline

Available only when:

- Required audio is cached.
- System speech fallback is approved.
- Exercise content is saved locally.

---

## 14. Writing and sentence practice

### 14.1 Purpose

Practice active vocabulary production.

### 14.2 Activity types

```text
Write a sentence using the target word
Complete a sentence
Rewrite for clarity
Correct an error
Translate a short sentence
Chinese character writing entry point
```

### 14.3 User response

The response editor:

- Uses native text editing.
- Supports undo and redo.
- Preserves drafts locally.
- Does not submit on every keystroke.

### 14.4 AI feedback

Feedback may cover:

- Correctness.
- Naturalness.
- Grammar.
- Word choice.
- Register.
- Suggested revision.

### 14.5 Feedback presentation

Show:

- Original response.
- Suggested revision.
- Explanation.
- Target vocabulary usage.

Do not replace the user's text silently.

### 14.6 Accepting revision

The user may:

- Copy revision.
- Save as personal example.
- Try again.

Saving as a personal example requires explicit action.

### 14.7 Privacy

User responses are sent only after Submit.

Draft text remains local before submission.

---

## 15. Word comparison

### 15.1 Purpose

Help distinguish similar or commonly confused words.

### 15.2 Input

- Two or more selected words.
- Suggested related words.
- Manual word entry.

### 15.3 Output

- Concise distinction.
- Register.
- Typical collocations.
- Example pairs.
- Common mistakes.
- Mini quiz.

### 15.4 Layout

Use a comparison table or aligned sections rather than long chat bubbles.

Example:

```text
Word        Meaning        Typical use       Example
```

### 15.5 Saved state

Unsaved compared words may be added individually.

Do not save all automatically.

---

## 16. Error correction practice

### 16.1 Purpose

Teach common grammar and word-choice errors.

### 16.2 Prompt

Show:

- Sentence containing an error.
- Optional target word.

### 16.3 Response

Users may:

- Choose corrected version.
- Edit sentence directly.
- Explain the error at advanced levels.

### 16.4 Feedback

Show:

- Corrected sentence.
- Error location.
- Explanation.
- Related vocabulary.

### 16.5 Generated-content validation

The exercise must identify a coherent intended correction.

If ambiguity exists:

- Explain alternatives.
- Do not mark one valid form strictly incorrect.

---

## 17. Assistant workspace

### 17.1 Purpose

Assistant is a contextual language-learning workspace.

### 17.2 Layout

Recommended:

```text
┌──────────────────┬──────────────────────────────┬──────────────────┐
│ Conversations    │ Conversation                 │ Context Inspector│
│                  │                              │                  │
│ Recent           │ Messages                     │ Selected words   │
│ Pinned           │                              │ Smart List       │
│                  │ Composer                     │ Language         │
└──────────────────┴──────────────────────────────┴──────────────────┘
```

### 17.3 Conversation list

Shows:

- Title.
- Updated time.
- Language.
- Context summary.
- Pinned state.

### 17.4 Context inspector

Shows removable context:

- Current word.
- Selected words.
- Smart List.
- Imported passage.
- Language.
- Learner level.
- Task preset.

### 17.5 Composer

Supports:

- Text input.
- Task preset.
- Add Context.
- Send.
- Stop.

### 17.6 Presets

Suggested:

```text
Explain
Compare
Give Examples
Correct My Sentence
Create a Quiz
Create a Reading
Analyze Text
```

Presets define structured task intent, not hidden irreversible behavior.

---

## 18. Assistant message presentation

### 18.1 User message

Display as authored content.

### 18.2 Assistant message

Use readable document-style formatting:

- Paragraphs.
- Lists.
- Examples.
- Comparison blocks.
- Vocabulary links.

Avoid narrow mobile chat bubbles for long educational content.

### 18.3 Generated label

Assistant responses are identified as generated.

### 18.4 Markdown

Support a safe Markdown subset:

- Headings.
- Emphasis.
- Lists.
- Code formatting where relevant.
- Tables only when accessible and useful.

Sanitize unsupported HTML and unsafe links.

### 18.5 Vocabulary entities

Recognized target words should be interactive:

- View definition.
- Play pronunciation.
- Add to Voca.
- Open detail.

### 18.6 Copy and export

Users may:

- Copy response.
- Copy selected section.
- Save useful example.
- Export conversation where supported.

---

## 19. AI context model

### 19.1 Context types

```text
Vocabulary card
Vocabulary selection
Smart List
Imported text
Current sentence
Practice session
Conversation scenario
Language and level settings
```

### 19.2 Context preview

Before sending a document or large selection, show:

- Source type.
- Approximate amount of text.
- Vocabulary count.
- Whether personal notes are included.
- Provider.

### 19.3 Context removal

Users can remove any optional context before sending.

### 19.4 Context minimization

The context builder should:

- Include only required fields.
- Prefer concise meanings.
- Bound example count.
- Exclude review history unless task requires it.
- Exclude notes by default.
- Exclude unrelated recent activity.

### 19.5 Context snapshot

Each request records a safe structural snapshot:

- Referenced entity IDs.
- Context categories.
- Language.
- Task type.

Do not store secret-provider credentials in the snapshot.

---

## 20. AI request lifecycle

State model:

```text
Draft
Validating
Preparing Context
Awaiting Consent
Sending
Streaming
Completed
Cancelled
Failed
Recoverable Partial
```

### 20.1 Draft

User edits message or configuration locally.

### 20.2 Validating

Check:

- Nonempty task.
- Available account.
- Valid provider configuration.
- Context size.
- Supported language.

### 20.3 Preparing Context

Resolve:

- Vocabulary entities.
- Local text.
- Task preset.
- Minimal prompt structure.

### 20.4 Awaiting Consent

Required when:

- Sending imported document text.
- Sending personal notes.
- Changing provider.
- Content volume exceeds normal expectations.

### 20.5 Sending

Create stable request identity and start remote operation.

### 20.6 Streaming

Parse and display partial content.

### 20.7 Completed

Persist according to conversation policy.

### 20.8 Cancelled

Retain:

- User draft.
- Completed prior messages.

Partial generated content follows the selected retention policy.

### 20.9 Failed

Show:

- Safe error.
- Retry.
- Edit and Retry.
- Change Provider where appropriate.

---

## 21. Streaming

### 21.1 Transport

Use the shared event-stream abstraction.

### 21.2 Stream events

Potential event types:

```text
Started
Text Delta
Structured Item
Audio Reference
Usage
Completed
Error
```

### 21.3 Buffering

Update UI at a bounded frequency rather than on every tiny token if that creates excessive rendering.

### 21.4 Scrolling

While streaming:

- Auto-follow when the user remains near the bottom.
- Stop auto-follow when the user scrolls upward.
- Offer Jump to Latest.

### 21.5 Stop

Stop action:

- Cancels the local task.
- Notifies backend where supported.
- Preserves completed text according to policy.

### 21.6 Partial response

Label:

```text
Generation stopped
```

Allow:

- Keep.
- Retry.
- Continue, if provider supports continuation.
- Delete.

### 21.7 Duplicate stream prevention

One Send action creates one request ID.

Retry creates:

- A new request linked to the failed request.

It must not append two concurrent responses to one assistant message.

---

## 22. Cancellation

### 22.1 User cancellation

Available during:

- Context preparation.
- Exercise generation.
- Assistant streaming.
- Conversation response.
- TTS generation.

### 22.2 Cancellation effects

Cancellation should:

- Stop unnecessary local work.
- Stop network request where supported.
- Release temporary resources.
- Preserve configuration.
- Avoid recording a completed exercise.

### 22.3 Provider billing

Cancellation may not reverse provider usage already incurred.

The product should not imply otherwise.

### 22.4 Window closure

If a generation is active:

- Continue only when explicitly supported as a background job.
- Otherwise ask whether to Stop Generation or Keep Window Open.

Short message generation should generally stop on conversation deletion, sign out, or account switch.

---

## 23. Conversation practice

### 23.1 Purpose

Practice realistic language use through guided scenarios.

### 23.2 Setup

Fields:

- Scenario.
- User role.
- Assistant role.
- Language.
- Difficulty.
- Target vocabulary.
- Correction timing.
- Text or speech mode.

### 23.3 Scenario examples

```text
Work meeting
Job interview
Travel check-in
Restaurant
Technical discussion
Presentation practice
Everyday conversation
Chinese shopping dialogue
```

### 23.4 Correction timing

Options:

```text
After every response
Only for important errors
At the end
```

### 23.5 Conversation layout

Show:

- Scenario and roles.
- Conversation history.
- Composer.
- Audio controls.
- Correction panel.
- Target-vocabulary progress.

### 23.6 Speech input

Potential later support:

- Microphone permission.
- Speech transcription.
- Editable transcript before send.

The first release may use text input and TTS responses.

### 23.7 TTS

Assistant responses may be spoken automatically according to user settings.

### 23.8 Corrections

Corrections should distinguish:

- Grammar.
- Vocabulary choice.
- Naturalness.
- Register.

### 23.9 Session summary

Show:

- Completed turns.
- Target words used.
- Corrections.
- Useful new words.
- Suggested next practice.

### 23.10 Save vocabulary

Suggested new words require individual or reviewed batch confirmation.

---

## 24. Practice feedback and scoring

### 24.1 Accuracy

For deterministically scored exercises:

- Correct count.
- Total count.
- Per-word result.

### 24.2 AI-evaluated answers

When evaluation is probabilistic:

- Label feedback as guidance.
- Avoid false precision.
- Provide reasoning.
- Allow user disagreement.

### 24.3 No global intelligence score

Do not reduce practice into an opaque overall language score in the first release.

### 24.4 Difficult-word signal

Practice errors may contribute to a local difficult-word recommendation.

They must not directly alter FSRS scheduling.

### 24.5 Summary

Show:

- Completion.
- Accuracy where valid.
- Words needing attention.
- Strong words.
- Recommended next action.

---

## 25. Practice persistence

### 25.1 Persisted session data

Potentially store:

- Session ID.
- Practice type.
- Vocabulary-source IDs.
- Generated exercise structure.
- User answers.
- Completion state.
- Summary.
- Created and updated timestamps.

### 25.2 Conversation persistence

Product decision:

```text
Local only
Synchronized
Not retained by default
```

Recommended initial approach:

- Persist locally.
- Provide Clear History.
- Do not synchronize until a cross-device contract is defined.

### 25.3 Generated content retention

Retain:

- Active and recent practice sessions.
- User-saved examples.

Prune:

- Abandoned generated drafts.
- Temporary repair responses.
- Old incomplete sessions according to policy.

### 25.4 User deletion

Users can delete:

- Individual conversation.
- Practice-session history.
- All AI history.

Deleting history does not delete vocabulary cards.

---

## 26. Offline behavior

### 26.1 Available offline

- Open completed saved practice.
- Resume fully generated local practice.
- Complete deterministic exercise items.
- Read cached Assistant history.
- Play cached audio.
- Use local writing drafts.

### 26.2 Unavailable offline

- Generate a new AI exercise.
- Stream Assistant response.
- Generate remote TTS.
- Create a new AI conversation response.

### 26.3 Offline completion

Completing a cached exercise:

- Saves answers locally.
- Updates local summary.
- Queues optional aggregate activity sync.

### 26.4 Reconnection

Do not automatically regenerate a failed AI request merely because connectivity returned.

Offer:

- Retry.

This avoids unexpected cost.

---

## 27. Provider and model settings

### 27.1 Settings

Users may configure:

- Provider.
- Base URL.
- Model.
- API key.
- Default language behavior.
- Generation limits.

### 27.2 Secret storage

API keys belong in Keychain.

They must not appear in:

- UserDefaults.
- Local conversation records.
- Logs.
- Widgets.
- Spotlight.
- Diagnostics.

### 27.3 Saved key display

After save:

- Show configured state.
- Do not reveal the full key.
- Allow replace or delete.

### 27.4 Validation

Provider validation:

- Happens through explicit Test Connection or first request.
- Distinguishes invalid credentials from network failure.
- Does not log response secrets.

### 27.5 Default provider

The backend may supply a server-managed default.

The UI must distinguish:

```text
Voca default
Your provider
```

### 27.6 Model capability

Before enabling features, determine whether the selected model supports:

- Streaming.
- Structured output.
- Required context size.
- Supported language quality.

### 27.7 Provider switch

Switching provider does not silently resend prior content.

New requests use the new provider after save.

---

## 28. Cost and usage control

### 28.1 Explicit actions

Every generation request comes from:

- Send.
- Generate.
- Regenerate.
- Continue.

Background dashboard rendering does not generate AI content.

### 28.2 Request bounds

Set limits for:

- Vocabulary count.
- Document size.
- Question count.
- Conversation context.
- Response length.

### 28.3 Context trimming

Use deterministic trimming:

1. Preserve current task.
2. Preserve selected vocabulary.
3. Preserve recent relevant turns.
4. Summarize or remove older history.

### 28.4 Usage display

If provider usage metadata is available:

- Show it in diagnostics or advanced settings.
- Avoid cluttering every response.

### 28.5 Regeneration

Regenerate:

- Requires explicit action.
- Creates a new request.
- Does not overwrite the prior response until the new response succeeds, unless the user requests replacement.

### 28.6 Rate limits

On rate limit:

- Explain retry timing.
- Preserve user input.
- Avoid automatic tight retry loops.

---

## 29. Generated-content labeling

### 29.1 Required labels

Label:

- Assistant responses.
- Generated examples.
- Generated exercises.
- Generated corrections.
- Generated translations where applicable.

### 29.2 Canonical content distinction

Canonical dictionary content and generated content must not merge visually without provenance.

### 29.3 Saved generated examples

When a user saves generated content:

- Preserve source metadata.
- Allow editing.
- Mark it as user-saved generated content.

### 29.4 Correction and reporting

Users may:

- Regenerate.
- Report unsuitable content.
- Edit before saving.

---

## 30. Privacy and explicit transmission

### 30.1 Sent only by explicit action

The following are never sent passively:

- Personal notes.
- Imported document text.
- Clipboard content.
- User writing drafts.
- Conversation audio.
- Unrelated vocabulary.

### 30.2 Context preview

Required before sending:

- Long imported text.
- Personal notes.
- Large Smart List.
- Sensitive-looking content where detectable.

### 30.3 Personal notes

Default:

- Excluded.

If included:

- Show a clear context token.
- Allow removal.

### 30.4 Imported documents

The user chooses:

- Selected excerpt.
- Extracted vocabulary only.
- Full supported text.

No document is uploaded merely because it was dropped into Voca.

### 30.5 Conversation audio

Microphone content:

- Requires permission.
- Is captured only during explicit recording.
- Shows recording state.
- Is discarded or retained according to clear policy.

### 30.6 Logs and analytics

Never log or collect:

- Prompt text.
- Response text.
- User sentence.
- Imported text.
- Conversation transcript.
- Personal notes.
- API keys.

Safe analytics:

- Feature type.
- Technical latency.
- Cancellation.
- Error category.
- Question count.
- Context category without content.

---

## 31. Safety and content quality

### 31.1 Educational scope

The Assistant should stay focused on language-learning tasks.

### 31.2 Unsupported requests

Requests outside supported behavior should:

- Be declined or redirected safely.
- Avoid presenting unsupported expertise as authoritative.

### 31.3 User reporting

Provide:

- Report Incorrect Content.
- Regenerate.
- Remove from session.

### 31.4 Stored reports

Reports should include:

- Request ID.
- Feature type.
- Model metadata.
- Optional user category.

Do not include full private content without explicit consent.

### 31.5 Prompt injection from documents

Imported text is untrusted content.

The context builder should:

- Treat document text as data.
- Separate system task instructions from imported text.
- Avoid executing instructions embedded in documents.

### 31.6 External links

Generated links:

- Are visually identifiable.
- Open through safe system behavior.
- Are not treated as verified sources merely because the model produced them.

---

## 32. Error behavior

### 32.1 Provider not configured

Show:

```text
Configure an AI provider to use this feature.
[Open AI Settings]
```

If a Voca default provider exists, offer it explicitly.

### 32.2 Authentication error

Preserve:

- Draft.
- Configuration.
- Context selection.

Offer:

- Sign In.

### 32.3 Network error

Preserve:

- Prompt.
- Context.
- Generated partial content.

Offer:

- Retry.
- Edit and Retry.

### 32.4 Rate limit

Show:

- Provider message in safe terms.
- Retry availability.
- Model or provider change where useful.

### 32.5 Invalid structured content

- Attempt one bounded repair.
- Otherwise offer Regenerate.
- Never present malformed quiz controls.

### 32.6 Context too large

Offer:

- Reduce vocabulary.
- Use selected excerpt.
- Start a new conversation.
- Summarize older context.

### 32.7 Stream interruption

Mark partial content.

Offer:

- Keep.
- Retry.
- Continue.
- Delete.

### 32.8 TTS error

- Preserve text.
- Offer retry.
- Offer system-voice fallback if approved.

---

## 33. Accessibility

### 33.1 Practice navigation

Every practice mode must support:

- Keyboard answer selection.
- Submit.
- Next.
- Replay audio.
- Pause.
- Exit.

### 33.2 Drill choices

VoiceOver labels include:

- Choice position.
- Choice content.
- Selected state.

Example:

```text
Choice 2 of 4, brief but comprehensive
```

### 33.3 Feedback

Announce:

- Correct.
- Incorrect.
- Correct answer.

Do not rely only on green and red.

### 33.4 Reading

Provide:

- Logical heading structure.
- Readable passage order.
- Accessible target-word links.
- Text alternative for highlights.

### 33.5 Listening

Controls require:

- Play or pause state.
- Replay.
- Speed.
- Transcript after reveal.

### 33.6 Assistant streaming

Do not announce every token.

Announce:

- Generation started.
- Response ready.
- Generation stopped.
- Error.

### 33.7 Context inspector

Context items must have:

- Type.
- Name.
- Remove action.

### 33.8 Larger text

- Long Assistant content reflows.
- Practice choices stack.
- Comparison views switch from table to sections when needed.
- Composer remains reachable.

### 33.9 Reduced Motion

- Minimal exercise transitions.
- No decorative typing animation.
- Progress changes remain clear.

### 33.10 Voice Control

Actions use distinct names:

- Submit Answer.
- Next Question.
- Play Audio.
- Stop Generation.
- Add to Vocabulary.
- Remove Context.

---

## 34. Performance

### 34.1 Initial view

Practice home and Assistant history load from local state without waiting for AI services.

### 34.2 Generation start

The UI should acknowledge the request immediately.

### 34.3 Streaming render

Coalesce text updates to avoid excessive layout work.

### 34.4 Large conversations

Use:

- Lazy rendering.
- Bounded loaded history.
- Conversation pagination.
- Context summarization.

### 34.5 Audio

- Cache generated audio according to storage policy.
- Avoid regenerating unchanged speech.
- Release decoded audio after playback.

### 34.6 Practice sessions

Load:

- Current item.
- Next item.

Avoid rendering all complex question views simultaneously.

### 34.7 Cancellation

Cancellation should stop expensive local and remote work promptly where supported.

---

## 35. State models

### 35.1 Practice feature

```swift
@MainActor
@Observable
final class PracticeFeature {
    enum Phase {
        case configuring
        case preparingContext
        case generating
        case active
        case feedback
        case paused
        case completed(PracticeSummary)
        case failed(PracticeError)
    }

    var configuration: PracticeConfiguration
    private(set) var phase: Phase = .configuring
    private(set) var session: PracticeSession?
    private(set) var currentIndex = 0

    func generate() async
    func submit(_ answer: PracticeAnswer) async
    func next()
    func pause()
    func resume()
    func cancelGeneration()
}
```

### 35.2 Assistant feature

```swift
@MainActor
@Observable
final class AssistantFeature {
    enum GenerationState {
        case idle
        case preparing
        case streaming
        case cancelling
        case failed(AssistantError)
    }

    var draft = ""
    var context = AssistantContextSelection()
    private(set) var conversation: AssistantConversation
    private(set) var generationState: GenerationState = .idle

    func send() async
    func stop()
    func retry(messageID: AssistantMessageID) async
    func removeContext(_ item: AssistantContextItem)
}
```

### 35.3 Conversation feature

```swift
@MainActor
@Observable
final class ConversationPracticeFeature {
    enum Phase {
        case setup
        case active
        case generating
        case paused
        case completed(ConversationSummary)
        case failed(ConversationError)
    }

    var setup: ConversationSetup
    var draft = ""
    private(set) var phase: Phase = .setup
    private(set) var turns: [ConversationTurn] = []

    func start() async
    func send() async
    func playResponse(_ turnID: ConversationTurnID) async
    func complete() async
}
```

---

## 36. Service boundaries

Required application services:

```text
PracticeContextBuilder
PracticeGenerationUseCase
PracticeValidationService
PracticeSessionRepository
AssistantContextBuilder
AssistantCompletionUseCase
ConversationPracticeUseCase
GeneratedAudioService
AIProviderConfigurationRepository
AIUsagePolicy
```

### 36.1 Context builder

Owns:

- Minimal context selection.
- Entity resolution.
- Size limits.
- Personal-note exclusion.
- User-visible context summary.

### 36.2 Generation use case

Owns:

- Request creation.
- Stable request identity.
- Provider invocation.
- Stream decoding.
- Cancellation.
- Error mapping.

### 36.3 Validation service

Owns:

- Structured exercise validation.
- Repair eligibility.
- Safe fallback.

### 36.4 Repositories

Own:

- Local session persistence.
- Conversation persistence.
- History deletion.

---

## 37. Prompt and schema strategy

### 37.1 Structured output

Practice generation should request a structured schema.

Conceptual drill shape:

```swift
struct GeneratedDrill: Codable, Sendable {
    let title: String
    let language: CardLanguage
    let questions: [GeneratedQuestion]
}
```

Question:

```swift
struct GeneratedQuestion: Codable, Sendable {
    let id: String
    let prompt: String
    let choices: [GeneratedChoice]
    let correctChoiceID: String
    let explanation: String?
    let targetCardIDs: [UserCardID]
}
```

### 37.2 Prompt ownership

Prompt templates belong in shared application services, not SwiftUI views.

### 37.3 Prompt versioning

Store:

- Prompt-template version.
- Output-schema version.
- Model identifier.

This supports diagnostics and safe migration without storing secret instructions in UI records.

### 37.4 Dynamic user input

Escape and delimit imported text and user responses as data.

### 37.5 Schema evolution

Generated saved sessions include schema version.

Older sessions should remain readable or migrate safely.

---

## 38. Testing strategy

### 38.1 Context tests

- Selected words only.
- Smart List bounds.
- Personal notes excluded.
- Invalid cards removed.
- Long document requires preview.
- Cross-account entity rejected.

### 38.2 Generation tests

- Successful structured response.
- Streaming text.
- Malformed JSON.
- Missing correct answer.
- Duplicate choices.
- Wrong language.
- Partial stream.
- Cancellation.

### 38.3 Drill tests

- Keyboard selection.
- Submit.
- Correct feedback.
- Incorrect feedback.
- Next item.
- Summary.
- No FSRS mutation.

### 38.4 Reading tests

- Target highlighting.
- Word detail.
- Pinyin on demand.
- Translation reveal.
- Question answers.

### 38.5 Listening tests

- Audio playback.
- Replay.
- Speed.
- Transcript reveal.
- Audio failure.
- Offline cached session.

### 38.6 Writing tests

- Draft persistence.
- Explicit submission.
- Streaming feedback.
- Save personal example.
- Cancellation.

### 38.7 Assistant tests

- New conversation.
- Add and remove context.
- Stream response.
- Stop.
- Retry.
- Scroll behavior.
- Delete conversation.
- Provider switch.

### 38.8 Conversation tests

- Setup.
- Send turn.
- Correction modes.
- TTS.
- Complete.
- Save suggested word with confirmation.

### 38.9 Privacy tests

- Notes not included by default.
- Clipboard not included.
- Imported text not sent before confirmation.
- Prompt content absent from logs.
- Sign out cancels requests.
- Account switch isolates history.

### 38.10 Accessibility tests

- VoiceOver question navigation.
- Keyboard-only drill.
- Reading headings.
- Listening controls.
- Streaming announcement frequency.
- Larger text.
- Increased Contrast.
- Reduce Motion.

### 38.11 Performance tests

- Long conversation.
- High-frequency stream deltas.
- Large vocabulary source.
- Cached session load.
- Generated audio cache.
- Cancellation latency.

---

## 39. Requirement traceability

### `AI-001` — Contextual assistant

Covered by:

- Assistant workspace.
- Context inspector.
- Context selection.
- Context preview and removal.

### `AI-002` — Streaming responses

Covered by:

- Request lifecycle.
- Streaming events.
- Buffering.
- Scrolling.
- Stop and partial response.

### `AI-003` — Explain word

Covered by:

- Assistant presets.
- Vocabulary grounding.
- Generated-content labeling.

### `AI-004` — Compare words

Covered by:

- Word comparison input.
- Aligned output.
- Examples and mini quiz.

### `AI-005` — Drills

Covered by:

- Question types.
- Distractors.
- Keyboard behavior.
- Feedback and summary.

### `AI-006` — Reading practice

Covered by:

- Passage.
- Target vocabulary.
- Questions.
- Chinese support.
- Translation.

### `AI-007` — Conversation practice

Covered by:

- Scenario setup.
- Roles.
- Turns.
- Corrections.
- TTS.
- Summary.

### `AI-008` — AI privacy

Covered by:

- Explicit transmission.
- Context preview.
- Notes exclusion.
- Imported-document policy.
- Log and analytics restrictions.

---

## 40. Acceptance scenarios

### Scenario A — Generate drill from difficult words

1. Open Practice.
2. Select Difficult Words.
3. Select 10 questions.
4. Generate.
5. Complete drill.

Expected:

- Context shows selected vocabulary source.
- Generated structure validates.
- Feedback appears after each answer.
- FSRS state does not change.

### Scenario B — Cancel generation

1. Start reading generation.
2. Select Stop.

Expected:

- Request is cancelled where supported.
- Configuration remains.
- No complete session is recorded.
- Partial content is clearly labeled if retained.

### Scenario C — Malformed drill response

1. Receive output with invalid answer IDs.

Expected:

- Broken quiz is not shown.
- One bounded repair may occur.
- Regenerate is available.

### Scenario D — Reading with recent vocabulary

1. Select Recently Added.
2. Generate reading.
3. Select a highlighted word.

Expected:

- Target words are visible.
- Word preview and pronunciation work.
- Full detail route opens correctly.

### Scenario E — Chinese reading

1. Generate Chinese passage.
2. Reveal pinyin for one sentence.
3. Play Mandarin audio.
4. Answer questions.

Expected:

- Hanzi remains primary.
- Pinyin is optional.
- Mandarin voice is used.

### Scenario F — Listening audio failure

1. Start listening practice.
2. Simulate remote TTS failure.

Expected:

- Existing text remains.
- Retry or text fallback appears.
- Session progress is preserved.

### Scenario G — Writing feedback

1. Enter a sentence.
2. Submit.
3. Receive correction.
4. Save revised sentence as a personal example.

Expected:

- Draft is not sent before Submit.
- Original and revision remain distinguishable.
- Saving requires explicit action.

### Scenario H — Assistant context

1. Open Assistant from a word.
2. Add a Smart List.
3. Remove the original word.
4. Send.

Expected:

- Context inspector reflects final selection.
- Only visible context is sent.

### Scenario I — Personal-note privacy

1. Select a card with a private note.
2. Ask Assistant for examples.

Expected:

- Note is excluded by default.
- UI does not imply it was included.

### Scenario J — Long document

1. Add a long imported passage as context.
2. Select Explain.

Expected:

- Context preview appears.
- Text amount and provider are visible.
- No request starts before confirmation.

### Scenario K — Stream interruption

1. Start Assistant response.
2. Lose network midway.

Expected:

- Partial response is labeled.
- Prompt and context remain.
- Retry and Edit and Retry are available.

### Scenario L — Offline completed practice

1. Generate a drill online.
2. Disconnect.
3. Complete it.

Expected:

- Answers and summary save locally.
- No automatic regeneration occurs.
- Optional activity sync waits.

### Scenario M — Provider error

1. Configure invalid credentials.
2. Generate practice.

Expected:

- Invalid credential is distinguishable from network failure.
- Draft and configuration remain.
- Full key is never displayed.

### Scenario N — Conversation correction timing

1. Start a scenario with corrections at session end.
2. Complete several turns.
3. Finish.

Expected:

- Conversation remains uninterrupted.
- Corrections appear in summary.
- Suggested words require confirmation to save.

### Scenario O — VoiceOver drill

1. Enable VoiceOver.
2. Complete a multiple-choice drill with keyboard.

Expected:

- Prompt and choices are read logically.
- Selected state is announced.
- Correctness is announced without color dependency.

---

## 41. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Practice does not silently modify FSRS scheduling.
2. Practice sessions persist selected vocabulary IDs when generation starts.
3. AI generation always follows explicit user action.
4. Personal notes are excluded from context by default.
5. Long or sensitive context receives a transmission preview.
6. The first recommendation engine remains deterministic; AI generates content only after Start.
7. Generated exercises require structural validation.
8. Invalid structured output is never rendered as interactive controls.
9. Recognition drills use four choices when valid distractors exist.
10. Assistant uses document-style responses rather than narrow mobile chat bubbles.
11. Conversation and practice history are local-only initially unless a synchronization contract is approved.
12. Generated content is labeled and may be reported or regenerated.
13. User drafts remain local until explicit submission.
14. Regeneration creates a new request without deleting the prior result first.
15. The first release does not perform automatic pronunciation scoring.
16. AI request content and responses are excluded from analytics and ordinary logs.

---

## 42. Open questions

1. Which practice types must ship in the first public release?
2. Do existing backend practice endpoints return structured output reliably?
3. Does the Assistant endpoint support typed streaming events or only text deltas?
4. Which prompt templates already exist in `ClientPrompts`?
5. Should practice history synchronize across devices?
6. Should Assistant conversations synchronize?
7. How long should generated practice content remain locally?
8. Which provider and model capabilities can the client discover?
9. Should users see token or cost estimates?
10. What vocabulary limit should each practice type accept?
11. Should drill errors contribute to Difficult Words?
12. Should practice completion contribute to the daily goal?
13. Can users select more than one Smart List as context?
14. Should AI-generated examples be editable before saving?
15. Which correction modes ship with Conversation?
16. Does the first release include microphone input?
17. Should system speech be the default TTS fallback?
18. Should reading passages support inline translation by sentence?
19. How should Chinese pinyin display preferences synchronize?
20. What content-reporting workflow is available on the backend?

---

## 43. Backend and data dependencies

The complete feature may require:

- Streaming Assistant endpoint.
- Structured drill generation.
- Structured reading generation.
- Conversation endpoint.
- Cancellation support.
- Request IDs.
- Provider configuration.
- Usage metadata.
- TTS generation.
- Stable vocabulary IDs.
- Practice-session storage or activity endpoint.
- Content-report endpoint.

Recommended generation response metadata:

```text
requestID
model
provider
schemaVersion
promptVersion
createdAt
usageSummary
finishReason
```

Structured exercise responses should include stable IDs for:

- Session.
- Question.
- Choice.
- Target vocabulary.

---

## 44. Security review checklist

- [ ] AI starts only after explicit action.
- [ ] Context preview exists for large content.
- [ ] Personal notes are excluded by default.
- [ ] Imported text is treated as untrusted data.
- [ ] Prompt injection from documents is mitigated structurally.
- [ ] API keys remain in Keychain.
- [ ] Full keys are never redisplayed.
- [ ] Prompt and response content are excluded from logs.
- [ ] Conversation transcripts are excluded from analytics.
- [ ] Account switch cancels active generation.
- [ ] Sign out cancels account-scoped streams.
- [ ] Generated links are not treated as verified.
- [ ] Request and context size limits exist.
- [ ] Rate limits use bounded retries.
- [ ] User drafts remain local until Submit.
- [ ] Deleted history removes local retained content.

---

## 45. Definition of done

Practice and AI are complete for the first public release when:

- Practice home clearly distinguishes available activity types.
- Users can choose visible vocabulary context.
- Drills, reading, and at least one productive practice mode work.
- Generated exercise structures are validated.
- Practice answers do not silently alter FSRS state.
- Assistant context is visible and removable.
- Streaming can be stopped and retried.
- Partial failures preserve user drafts and valid content.
- English and Chinese experiences are supported.
- Conversation sessions provide corrections and summaries.
- AI provider settings store secrets securely.
- Personal notes and document text follow explicit-transmission rules.
- Generated content is labeled.
- Offline saved sessions remain readable and completable where supported.
- VoiceOver, keyboard, larger text, Increased Contrast, and Reduce Motion pass.
- Request size, rate, cost, and cancellation controls are implemented.
- Critical generation, validation, privacy, and persistence tests pass.

---

## 46. Next document

The next document should be:

```text
docs/macos-import-and-capture.md
```

It should define:

- Drag and drop.
- Plain-text capture.
- Image and screenshot OCR.
- PDF extraction.
- CSV and JSON import.
- Export.
- Import-job lifecycle.
- Candidate-word detection.
- Language detection.
- Duplicate classification.
- Column mapping.
- Batch enrichment.
- AI transmission preview.
- Temporary-file retention.
- Security-scoped file access.
- Offline behavior.
- Progress and cancellation.
- Accessibility.
- Testing and acceptance criteria mapped to `CAP-*`.
