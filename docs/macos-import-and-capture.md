# Voca for macOS — Import and Capture

> Product, UX, parsing, OCR, document processing, privacy, security, accessibility, and acceptance specification for importing and extracting vocabulary on macOS.

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
- **Related data specification:** [`macos-data-and-sync.md`](macos-data-and-sync.md)
- **Related AI specification:** [`macos-practice-and-ai.md`](macos-practice-and-ai.md)
- **Primary requirement group:** `CAP-*`
- **Last updated:** 2026-10-24

---

## 1. Purpose

This document defines how Voca captures vocabulary from external content and imports structured vocabulary collections.

It covers:

- Drag and drop.
- Paste and plain-text capture.
- Selected-text capture.
- Image and screenshot OCR.
- PDF extraction.
- CSV import.
- JSON import.
- Vocabulary export.
- Import-job lifecycle.
- Security-scoped file access.
- Language detection.
- Candidate-word extraction.
- Duplicate classification.
- Column mapping.
- Validation.
- Batch enrichment.
- AI transmission boundaries.
- Progress.
- Cancellation.
- Temporary-file retention.
- Offline behavior.
- Accessibility.
- Performance.
- Error recovery.
- Testing and acceptance criteria.

The core rule is:

> Imported material must remain a preview until the user explicitly confirms which vocabulary should be saved.

---

## 2. Product intent

Import and Capture should transform content the learner already encounters into a clean, reviewable set of vocabulary candidates.

Typical sources include:

- A word copied from a browser.
- A paragraph from technical documentation.
- A screenshot.
- A photograph.
- A PDF.
- A CSV export.
- A JSON backup.
- Text selected in another macOS application.

The workflow should:

- Recognize the input type automatically.
- Process locally where possible.
- Make extracted text visible.
- Identify likely vocabulary candidates.
- Detect existing saved words.
- Let the user correct extraction errors.
- Require confirmation before creating cards.
- Preserve progress during long operations.
- Avoid sending document content to AI without explicit consent.

The workflow should not:

- Create hundreds of cards immediately after a file is dropped.
- Treat every token as useful vocabulary.
- Upload local files automatically.
- Hide duplicate resolution.
- Claim an import succeeded when only some rows were saved.
- Retain source documents indefinitely without purpose.

---

## 3. Product principles

### CAP-PRN-001 — Preview before commit

Every multi-item capture workflow must show a reviewed candidate set before saving.

### CAP-PRN-002 — Local extraction first

Use local parsing, text extraction, and OCR before considering remote processing.

### CAP-PRN-003 — Source content is untrusted

Imported text may contain malformed data, prompt injection, scripts, unexpected encodings, or oversized content.

### CAP-PRN-004 — Duplicates are classified, not hidden

Users should understand which entries are:

- New.
- Already saved.
- Possible duplicates.
- Invalid.

### CAP-PRN-005 — Long operations are durable

An import job should survive ordinary window changes and provide recoverable progress where practical.

### CAP-PRN-006 — AI is optional enrichment

AI may improve meanings, examples, or candidate selection, but ordinary parsing and preview must not require it.

### CAP-PRN-007 — File access is temporary

Voca should retain access to source files only as long as the active workflow needs it.

### CAP-PRN-008 — Partial results are explicit

If only part of an import succeeds, the completion report must identify successes, failures, and skipped entries.

### CAP-PRN-009 — Export is understandable

Users must know which fields and records an export includes.

---

## 4. Scope

### 4.1 Included

- Drag and drop into Voca.
- Paste and direct-text input.
- Image OCR.
- Screenshot OCR.
- PDF text extraction.
- Scanned-PDF OCR where practical.
- CSV column mapping.
- JSON schema validation.
- Candidate detection.
- Duplicate detection.
- Candidate selection.
- Candidate editing.
- Batch save.
- Import summary.
- CSV and JSON export.
- Progress and cancellation.
- Local temporary files.
- Offline parsing.

### 4.2 Related but specified elsewhere

- Quick Lookup.
- macOS Services.
- Complete vocabulary-edit flow.
- AI Assistant.
- Synchronization queue.
- Security and privacy foundation.
- Full review behavior.

### 4.3 Excluded from the initial release

- Proprietary Anki package import unless separately specified.
- EPUB parsing.
- Video subtitle extraction.
- Browser-extension capture.
- Continuous clipboard history.
- Cloud-drive folder monitoring.
- Automatic import from email.
- Background watching of arbitrary folders.
- Automatic card creation without confirmation.

---

## 5. Entry points

Users may start Capture or Import from:

- File → Import.
- Vocabulary toolbar → Import.
- Drag and drop.
- Paste into Vocabulary.
- Add Word flow.
- macOS Service.
- Share Extension if later required.
- Command Palette.
- First-run state.
- Empty Vocabulary state.

### 5.1 Import command

```text
File
└── Import…
```

Shortcut candidate:

```text
Shift + Command + I
```

The final shortcut must avoid conflict with inspector commands.

### 5.2 Export command

```text
File
└── Export…
```

### 5.3 Drag and drop

Drop targets:

- Vocabulary content area.
- Empty Vocabulary state.
- Dedicated Import window.

### 5.4 Paste

When Vocabulary has focus and pasted content is not appropriate for a text editor:

- A short word may open Add Word.
- A passage may open Extract Vocabulary.
- Structured tabular text may open import preview.

Paste must respect normal text-field behavior when a field is focused.

---

## 6. Input types

### 6.1 Plain text

Supported:

- Word.
- Short phrase.
- Sentence.
- Passage.
- Tabular text.

### 6.2 Rich text

Extract:

- Plain textual content.

Optionally preserve:

- Paragraph boundaries.

Do not import:

- Embedded scripts.
- Hidden formatting metadata.

### 6.3 URL

Initial behavior:

- Treat pasted URL as a URL.
- Offer Open in Browser or supported article capture later.

Do not fetch arbitrary web pages automatically in the initial release.

### 6.4 Image

Supported formats should include common macOS image types accepted by the selected recognition framework.

Use:

- Local Vision OCR.
- User-selected recognition languages.

### 6.5 Screenshot

Treat as image input.

Potential entry:

- Drop a screenshot.
- Paste from screenshot clipboard.

### 6.6 PDF

Support:

- Text PDFs.
- Mixed text and image PDFs.
- Scanned PDFs where OCR is enabled.

### 6.7 CSV

Support:

- Delimited vocabulary records.
- Header mapping.
- Common encodings after validation.

### 6.8 JSON

Support:

- Documented Voca export schema.
- Versioned schema migrations.

Potential later support:

- Mapped third-party JSON.

### 6.9 Unsupported files

Show:

- File type.
- Why it is unsupported.
- Alternative action where useful.

---

## 7. Import window

Complex capture workflows use a dedicated window.

Recommended phases:

```text
Source
→ Extract
→ Configure
→ Candidates
→ Review
→ Import
→ Summary
```

### 7.1 Suggested layout

```text
┌────────────────────────────────────────────────────────────────────┐
│ Import Vocabulary                                    Cancel       │
├──────────────────┬─────────────────────────────────────────────────┤
│ Steps            │ Current step                                    │
│                  │                                                 │
│ 1 Source         │ Source preview                                  │
│ 2 Extract        │ Mapping or recognition controls                 │
│ 3 Candidates     │ Candidate table                                 │
│ 4 Review         │ Validation and duplicates                       │
│ 5 Import         │ Progress                                        │
└──────────────────┴─────────────────────────────────────────────────┘
```

### 7.2 Window behavior

- Resizable.
- Independent from main-window selection.
- Supports cancellation.
- Preserves active job while the main workspace changes.
- May be reopened from Activity when a job is recoverable.

### 7.3 Sheets

Use a sheet only for:

- One-word capture.
- Small CSV configuration.
- Simple export options.

Use a dedicated window for:

- Long documents.
- OCR.
- Large imports.
- Complex mapping.

---

## 8. Import-job lifecycle

State model:

```text
Created
Inspecting Source
Extracting
Recognizing Text
Normalizing
Detecting Language
Generating Candidates
Classifying Duplicates
Awaiting Review
Enriching
Ready to Import
Importing
Completed
Completed with Issues
Cancelled
Failed
```

### 8.1 Created

Voca records:

- Job ID.
- Account ID.
- Source type.
- Safe display name.
- Creation time.

### 8.2 Inspecting Source

Validate:

- File access.
- File size.
- Type.
- Encoding.
- Page count.
- Schema.

### 8.3 Extracting

Read text or structured records locally.

### 8.4 Recognizing Text

OCR image-based content.

### 8.5 Normalizing

Normalize:

- Unicode.
- Whitespace.
- Line endings.
- Punctuation.

Preserve original extracted text for review.

### 8.6 Detecting Language

Detect:

- English.
- Chinese.
- Mixed content.
- Unknown.

### 8.7 Generating Candidates

Identify candidate words or phrases.

### 8.8 Classifying Duplicates

Compare against:

- Saved user cards.
- Pending local cards.
- Duplicate rows in the current job.
- Shared dictionary entries.

### 8.9 Awaiting Review

No vocabulary is created yet.

### 8.10 Enriching

Optional:

- Dictionary lookup.
- AI generation.
- Pronunciation lookup.

### 8.11 Importing

Persist confirmed items in bounded transactions.

### 8.12 Completed

Show summary and navigation actions.

---

## 9. Source inspection

### 9.1 File metadata

Display:

- File name.
- Type.
- Size.
- Page or row count where available.
- Detected encoding.

### 9.2 Limits

Define limits for:

- Maximum file size.
- Maximum page count.
- Maximum extracted characters.
- Maximum CSV rows.
- Maximum candidate count.

Large content may require:

- Partial selection.
- Page range.
- Row range.
- Explicit confirmation.

### 9.3 Unsupported encryption

Password-protected PDF:

- Request password through secure input if supported.
- Do not persist the password.

If unsupported:

- Explain that the PDF must be unlocked before import.

### 9.4 Malformed source

Preserve:

- Source reference as long as required.
- Safe diagnostics.

Offer:

- Retry.
- Choose Another File.
- Adjust encoding.

---

## 10. Security-scoped file access

### 10.1 Open panel

Use the native open panel with supported content types.

### 10.2 Access lifetime

Start security-scoped access only for the duration required to:

- Inspect.
- Extract.
- Create approved temporary copies.

Stop access promptly.

### 10.3 Persistent bookmarks

Do not create persistent security-scoped bookmarks by default.

Use them only when:

- A user explicitly chooses ongoing folder monitoring in a future feature.
- A recoverable long-running import genuinely requires it.

### 10.4 Temporary copy

When needed:

- Copy into the account's temporary import directory.
- Record retention.
- Protect with account isolation.
- Delete after completion, cancellation, or expiry.

### 10.5 File mutation

Voca must not modify the original source file.

---

## 11. Drag and drop

### 11.1 Drag states

```text
Idle
Accepted
Rejected
Multiple Inputs
Processing
```

### 11.2 Visual feedback

Show:

- Accepted content type.
- Intended action.
- Number of files.

Examples:

```text
Drop to extract vocabulary from this PDF
```

```text
Drop to import 3 vocabulary files
```

### 11.3 Multiple files

Initial recommendation:

- Accept multiple files into one import job only when they share a compatible workflow.
- Otherwise create a job group or request one file at a time.

### 11.4 Dropped text

One word:

- Open Add Word preview.

Sentence or passage:

- Open candidate extraction.

### 11.5 Dropped URL

Do not fetch automatically.

Offer:

- Open URL.
- Paste Article Text.
- Future supported article import.

### 11.6 Rejected drop

Use:

- Clear cursor feedback.
- Concise reason.

Do not create a silent no-op.

---

## 12. Plain-text capture

### 12.1 Short word

Flow:

```text
Text input
→ Normalize
→ Detect language
→ Lookup
→ Duplicate check
→ Preview
→ Save
```

### 12.2 Passage

Flow:

```text
Passage
→ Detect language
→ Tokenize
→ Identify candidate terms
→ Match saved vocabulary
→ Rank candidates
→ User review
```

### 12.3 Mixed language

For mixed English and Chinese:

- Identify candidate language per term.
- Provide language filter.
- Avoid applying one language to the whole passage blindly.

### 12.4 Source preview

Show:

- Original text.
- Candidate highlights.
- Detected language.
- Edit action.

### 12.5 Editing extracted text

Corrections trigger candidate recomputation.

Preserve deliberate candidate selections where terms still exist.

---

## 13. OCR

### 13.1 OCR engine

Use local Vision text recognition as the default.

### 13.2 Recognition configuration

Users may choose:

- Automatic language.
- English.
- Chinese.
- English and Chinese.

### 13.3 Image preprocessing

Use framework-supported processing.

Potential steps:

- Orientation correction.
- Appropriate recognition level.
- Region selection.

Avoid retaining unnecessary transformed image copies.

### 13.4 OCR progress

For one image:

- Show recognizing state.

For multiple pages or images:

- Show progress count.
- Show current item.
- Allow cancellation.

### 13.5 OCR result review

Display:

- Source image.
- Recognized text.
- Confidence or uncertain regions where useful.
- Editable text.

### 13.6 Low-confidence text

Mark low-confidence segments for review.

Do not reject the entire result automatically.

### 13.7 Region selection

Potential later enhancement:

- Let user select a portion of an image before OCR.

### 13.8 Screenshot privacy

Screenshots may include sensitive information.

They must:

- Be processed locally.
- Not be uploaded without explicit AI action.
- Follow temporary-file retention policy.

---

## 14. PDF extraction

### 14.1 Classification

Determine:

```text
Text PDF
Scanned PDF
Mixed PDF
Encrypted PDF
Unsupported or malformed PDF
```

### 14.2 Text PDF

Extract:

- Page text.
- Paragraph boundaries where reliable.

### 14.3 Scanned PDF

Offer OCR:

- All pages.
- Selected page range.

### 14.4 Mixed PDF

Use:

- Embedded text where available.
- OCR only for image-only pages.

Avoid duplicating text by processing the same page through both paths without reconciliation.

### 14.5 Page selection

For large PDFs:

- Select page range.
- Preview estimated text volume.
- Allow cancellation.

### 14.6 Page references

Candidate records may retain:

- Source page number.

The source page reference helps review but does not require retaining the PDF permanently.

### 14.7 Layout limitations

Multi-column, tables, headers, and footers may extract imperfectly.

Provide:

- Editable text.
- Header and footer removal options where useful.

### 14.8 PDF preview

Use a native preview where practical.

Do not execute embedded scripts or active content.

---

## 15. CSV import

### 15.1 File detection

Detect:

- Delimiter.
- Header row.
- Encoding.
- Quoting.
- Newline style.

Allow manual override.

### 15.2 Supported delimiters

Initial:

```text
Comma
Tab
Semicolon
```

### 15.3 Column mapping

Target fields:

```text
Word or Hanzi
Language
Pronunciation or Pinyin
Meaning
Example
Level
Tags
Topic
Personal Note
Favorite
```

Only Word or Hanzi is strictly required for lookup-assisted import.

### 15.4 Mapping UI

Display:

- Source-column name.
- Sample values.
- Target field.
- Ignore option.

### 15.5 Language

Language may come from:

- Mapped column.
- One import-wide choice.
- Per-row detection.

### 15.6 Tags

Support:

- One tags column.
- Configurable separator.

Examples:

```text
work;technical
```

### 15.7 Level mapping

Unknown levels:

- Map manually.
- Leave unset.
- Reject only when the backend requires a value.

### 15.8 Preview

Classify rows:

```text
Valid
Invalid
Already Saved
Possible Duplicate
Missing Required Field
```

### 15.9 Large CSV

- Parse incrementally.
- Avoid loading every raw field into UI simultaneously.
- Paginate preview.
- Support filtering by row status.

---

## 16. JSON import

### 16.1 Voca schema

Use a versioned export envelope:

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-10-24T00:00:00Z",
  "items": []
}
```

### 16.2 Validation

Validate:

- Schema version.
- Required fields.
- Identifier format.
- Language values.
- Field lengths.
- Nested-array limits.

### 16.3 Unknown fields

Ignore unknown optional fields where safe.

Preserve forward compatibility.

### 16.4 Unsupported future schema

Show:

```text
This export was created by a newer version of Voca.
Update Voca to import it.
```

### 16.5 Existing IDs

Imported IDs must not overwrite unrelated account data.

Backup restore behavior must be separately defined from generic JSON import.

### 16.6 Third-party JSON

Do not infer arbitrary third-party schemas in the first release.

Use CSV mapping or a dedicated supported adapter.

---

## 17. Candidate generation

### 17.1 Candidate unit

A candidate may be:

- One English word.
- One English phrase.
- One Chinese word.
- One Chinese phrase.
- One Hanzi character where appropriate.

### 17.2 Tokenization

English:

- Word boundaries.
- Hyphen and apostrophe handling.
- Phrase extraction.
- Inflection normalization.

Chinese:

- Word segmentation.
- Multi-character phrase detection.
- Character-level fallback.

### 17.3 Stop terms

Exclude likely low-value items:

- Punctuation.
- Pure numeric tokens.
- Common function words according to configurable rules.
- URLs.
- Email addresses.
- File paths.
- Code symbols where irrelevant.

Users must still be able to manually add excluded terms.

### 17.4 Ranking signals

- Frequency in source.
- Not already saved.
- Dictionary availability.
- Learning-level relevance.
- Term length.
- Domain relevance where deterministically known.
- User-selected source region.

### 17.5 Known vocabulary

Mark:

```text
Already in Vocabulary
```

Allow:

- Hide known.
- Show known.
- Open existing detail.

### 17.6 Candidate phrases

Avoid producing both:

```text
take
into
account
take into account
```

without grouping or a clear reason.

### 17.7 Candidate provenance

Retain:

- Source page or row.
- Source occurrence count.
- Original text span.

This supports review and debugging.

---

## 18. Language detection

### 18.1 Document-level detection

Identify:

- Primarily English.
- Primarily Chinese.
- Mixed.
- Unknown.

### 18.2 Candidate-level detection

Each candidate receives a language classification.

### 18.3 Manual correction

Users can change:

- Whole-source language.
- Individual candidate language.

### 18.4 Ambiguous Latin input

Pinyin may resemble English.

Use:

- Surrounding Hanzi.
- Explicit user choice.
- Dictionary match.
- Current learning-language preference.

### 18.5 Detection confidence

Low-confidence classification should be visible during review.

---

## 19. Duplicate classification

### 19.1 Categories

```text
New
Already Saved
Pending Save
Same Import Duplicate
Possible Variant
Shared Dictionary Match
Invalid
```

### 19.2 Exact duplicate

Match:

- Same account.
- Same normalized canonical form.
- Same language.

Action:

- Skip by default.
- Open existing.
- Merge metadata.

### 19.3 Same-import duplicate

Group identical normalized candidates.

Aggregate:

- Occurrence count.
- Source references.

### 19.4 Possible variant

Examples:

- English case variant.
- Inflected form.
- Pinyin normalization.
- Traditional and simplified Chinese relationship where supported.

Require review.

### 19.5 Pending local save

Treat as already saved for duplicate prevention.

### 19.6 Metadata merge

Allow explicit merge for:

- Tags.
- Topic.
- Personal note.
- Favorite.

Do not overwrite existing notes silently.

---

## 20. Candidate-review table

Suggested columns:

```text
Include
Status
Word or Hanzi
Language
Meaning
Occurrences
Source
Tags
Issues
```

### 20.1 Selection

Support:

- Select valid new candidates.
- Deselect.
- Select All New.
- Select by status.
- Multi-selection.

### 20.2 Filtering

Filters:

```text
All
New
Already Saved
Possible Duplicate
Invalid
Selected
English
Chinese
```

### 20.3 Editing

Editable fields:

- Word or Hanzi.
- Language.
- Meaning.
- Pronunciation or pinyin.
- Tags.
- Topic.
- Level.

Changing identity triggers duplicate reclassification.

### 20.4 Detail preview

Selecting a row shows:

- Full candidate.
- Original source context.
- Dictionary match.
- Existing-card match.
- Generated content source.
- Validation issues.

### 20.5 Bulk actions

- Include.
- Exclude.
- Add tags.
- Set topic.
- Set level.
- Enrich.
- Skip duplicates.

---

## 21. Dictionary enrichment

### 21.1 Purpose

Resolve a candidate into reusable dictionary content.

### 21.2 Pipeline

```text
Candidate
→ local dictionary match
→ cached remote content
→ backend lookup
→ optional AI generation
```

### 21.3 Automatic enrichment

May automatically use:

- Local dictionary.
- Existing shared backend content.

Must not automatically invoke:

- User-paid AI provider.
- Large remote generation.

### 21.4 Missing result

Offer:

- Edit spelling.
- Add manually.
- Generate with AI.
- Skip.

### 21.5 Batch limits

Remote enrichment should:

- Use bounded batches.
- Respect rate limits.
- Preserve job progress.
- Permit cancellation.

---

## 22. AI enrichment

### 22.1 Explicit action

The user chooses:

```text
Generate Missing Details
```

### 22.2 Transmission preview

Show:

- Number of candidates.
- Fields sent.
- Provider.
- Whether source sentences are included.
- Approximate request scope.

### 22.3 Default payload

Include only:

- Candidate term.
- Language.
- Limited source context where approved.
- Requested fields.

Exclude:

- Whole document.
- Personal notes.
- Unrelated candidates.

### 22.4 Source context

Users may choose:

```text
No source sentence
Include one source sentence per word
```

### 22.5 Prompt injection

Treat imported text as data.

Do not allow source text to redefine the enrichment task.

### 22.6 Generated-content labeling

Generated:

- Meaning.
- Example.
- Pronunciation guidance.

must remain identifiable during preview and after save where provenance is retained.

### 22.7 Failure

Partial enrichment:

- Preserves successful candidates.
- Classifies failed candidates.
- Allows targeted retry.

---

## 23. Import validation

### 23.1 Required validation

- Nonempty word or Hanzi.
- Supported language.
- Field-length limits.
- Valid tag count.
- Valid level.
- Valid encoding.
- No forbidden control characters.

### 23.2 Warning versus error

Error:

- Cannot save.

Warning:

- Can save after review.

Example warning:

```text
No meaning was found.
```

Example error:

```text
Word is empty.
```

### 23.3 Validation timing

Run:

- After parsing.
- After identity edits.
- Before import.

### 23.4 Batch readiness

The summary shows:

```text
312 ready
24 already saved
7 need review
3 invalid
```

---

## 24. Import commit

### 24.1 Confirmation

Before commit, show:

- Number to create.
- Number to update or merge.
- Number skipped.
- Tags and topic applied.
- AI-generated field count where relevant.

### 24.2 Transaction strategy

Small import:

- One transaction where safe.

Large import:

- Bounded chunks.
- Stable per-item operation IDs.
- Durable job progress.

### 24.3 Operation identity

Each created card receives:

- Stable client operation ID.
- Import job ID.

Retry must not duplicate successful cards.

### 24.4 Synchronization

Local-first behavior:

```text
Persist cards locally
→ create mutation entries
→ update Vocabulary
→ synchronize
```

### 24.5 Partial failure

Do not roll back hundreds of successful cards solely because one later row fails, unless the user explicitly selected atomic import and the backend supports it.

Report:

- Created.
- Merged.
- Skipped.
- Failed.
- Pending synchronization.

---

## 25. Completion summary

### 25.1 Required information

```text
Created
Merged
Skipped
Failed
Waiting to Sync
```

### 25.2 Actions

- View Imported Vocabulary.
- Review Failures.
- Export Failure Report.
- Start Practice.
- Close.

### 25.3 Imported collection

The job may create a temporary system collection:

```text
Imported on October 24
```

This is a query by import-job ID, not duplicated cards.

### 25.4 Failure report

May include:

- Source row or page.
- Safe candidate identity.
- Error category.
- Suggested correction.

It must not include credentials or full source documents unnecessarily.

---

## 26. Cancellation

### 26.1 Before import commit

Cancel:

- Stops extraction or enrichment where supported.
- Deletes unneeded temporary files.
- Creates no user cards.

### 26.2 During import commit

Cancellation:

- Stops scheduling new chunks.
- Preserves completed chunks.
- Produces partial summary.
- Keeps operation IDs for retry.

### 26.3 During AI enrichment

Cancel:

- Stops request where supported.
- Preserves candidate edits.
- Preserves successfully completed enrichment.

### 26.4 Window close

For a long-running job:

- Offer Continue in Background.
- Stop and Keep Progress.
- Cancel Job.

Only offer Continue in Background when the job architecture genuinely supports it.

### 26.5 Delete job

Deleting a completed job record:

- Removes job history and temporary data.
- Does not delete imported vocabulary.

---

## 27. Recovery

### 27.1 Recoverable phases

Potentially recover:

- Candidate review.
- Column mapping.
- Completed extraction.
- Partial enrichment.
- Partial commit.

### 27.2 Nonrecoverable transient phases

An in-memory OCR operation may need to restart after process termination unless intermediate page results are persisted.

### 27.3 Relaunch

Activity may show:

```text
Import interrupted
[Resume] [Restart] [Delete]
```

### 27.4 Source unavailable

If original file access is gone:

- Use approved temporary copy if retained.
- Otherwise request the source again.
- Preserve mapping and prior progress where possible.

### 27.5 Version change

Persisted import-job schema must be versioned and migratable.

---

## 28. Temporary-file retention

### 28.1 Temporary content

May include:

- Source copy.
- Rendered PDF pages.
- OCR intermediate images.
- Parsed row cache.
- Export staging.

### 28.2 Default retention

Delete:

- After successful completion and summary retention period.
- Immediately after cancellation when no recovery is requested.
- On explicit Clear Temporary Files.
- After expiry.

### 28.3 Recoverable jobs

Retain only what is necessary to resume.

### 28.4 Account isolation

Temporary files belong to the active account partition.

### 28.5 Secure deletion claims

Do not claim cryptographic secure deletion unless the underlying storage behavior guarantees it.

Use accurate wording:

```text
Remove local temporary files
```

---

## 29. Export

### 29.1 Export scopes

- Selected vocabulary.
- Current collection.
- Current filtered results.
- All vocabulary.
- Smart List.
- Imported batch.

### 29.2 Formats

Initial:

```text
CSV
Voca JSON
```

### 29.3 Export fields

Selectable:

- Word or Hanzi.
- Language.
- Pronunciation or pinyin.
- Meaning.
- Examples.
- Level.
- Tags.
- Topic.
- Favorite.
- Personal notes.
- Review metadata.

### 29.4 Privacy defaults

Personal notes:

- Excluded by default or clearly highlighted.

Review history:

- Excluded by default.

Credentials:

- Never included.

### 29.5 CSV export

Configuration:

- Delimiter.
- Selected fields.
- Encoding.
- Include header.
- Tag separator.

### 29.6 JSON export

Uses:

- Versioned Voca schema.
- UTC timestamps.
- Stable field names.

### 29.7 Save panel

Use native save panel.

The export writes only to the user-selected location.

### 29.8 Large export

- Show progress.
- Permit cancellation before final replacement.
- Write temporary file and atomically move where feasible.

---

## 30. Offline behavior

### 30.1 Available offline

- Plain-text parsing.
- CSV parsing.
- JSON validation.
- Image OCR.
- PDF text extraction.
- PDF OCR.
- Local duplicate detection.
- Candidate review.
- Export from local data.
- Import commit to local mutation queue.

### 30.2 Conditional offline behavior

Dictionary enrichment:

- Local and cached results only.

TTS:

- Cached or approved system fallback.

### 30.3 Unavailable offline

- Remote dictionary lookup for unknown words.
- AI enrichment.
- Remote TTS.

### 30.4 Deferred enrichment

Candidates may be saved with missing optional fields and enriched later only when:

- Product data model supports incomplete cards.
- User understands the state.

Otherwise keep candidates in the job until enrichment is possible.

### 30.5 Pending synchronization

Locally imported cards:

- Appear in Vocabulary.
- Show pending only where needed.
- Synchronize with stable operation IDs.

---

## 31. Privacy

### 31.1 Default local processing

Process locally:

- File inspection.
- Text extraction.
- OCR.
- Parsing.
- Candidate generation.
- Duplicate detection.

### 31.2 Remote transmission

Send only after explicit action:

- Candidate lookup.
- AI enrichment.
- Imported-text analysis.

### 31.3 Transmission preview

For AI:

- Provider.
- Candidate count.
- Source-context inclusion.
- Approximate content amount.

### 31.4 Clipboard

Pasted content:

- Is processed as explicit user input.
- Is not retained after cancellation unless job recovery is selected.

### 31.5 Logs

Allowed:

- Source type.
- File size category.
- Page or row count.
- Duration.
- Candidate count.
- Error category.

Disallowed:

- Full file path where unnecessary.
- Source content.
- Candidate words.
- Extracted text.
- Personal notes.
- AI payload.

### 31.6 Analytics

Allowed:

- Import started.
- Source type.
- Import completed.
- Created, skipped, and failed counts.
- OCR duration.
- Parsing error category.

Do not collect imported vocabulary content.

---

## 32. Security

### 32.1 Untrusted files

Treat every file as untrusted.

Validate:

- Declared type.
- Actual readable type.
- Size.
- Schema.
- Record count.
- Field lengths.

### 32.2 PDF content

Do not execute:

- Scripts.
- Embedded actions.
- External links.
- Attachments.

unless explicitly and safely opened by the user.

### 32.3 CSV injection

When exporting CSV, fields beginning with spreadsheet formula prefixes require mitigation or explicit safe encoding policy.

Potential prefixes:

```text
=
+
-
@
```

The policy must preserve legitimate language content while preventing unintended formula execution in spreadsheet applications.

### 32.4 Archive bombs

If compressed formats are later supported:

- Enforce expanded-size and file-count limits.

### 32.5 Path handling

Never trust imported relative paths.

Do not write outside approved temporary or user-selected export locations.

### 32.6 Prompt injection

Imported text included in AI context remains data, not instructions.

### 32.7 Secrets

Detecting secret-like content may trigger a warning before AI transmission.

Detection is advisory, not a guarantee.

---

## 33. Accessibility

### 33.1 Import steps

Expose:

- Current step.
- Completed steps.
- Progress.
- Errors.

### 33.2 Candidate table

VoiceOver should identify:

- Include state.
- Candidate.
- Language.
- Status.
- Issue.
- Source reference.

### 33.3 Mapping

Column-mapping controls require labels such as:

```text
Map source column “Term” to Voca field
```

### 33.4 OCR review

Provide:

- Source-image description.
- Recognized text editor.
- Low-confidence issue list.

The workflow must not require visual bounding-box interaction.

### 33.5 Progress

Examples:

```text
Recognizing page 12 of 40
```

```text
Importing 220 of 312 selected entries
```

### 33.6 Keyboard

Users must be able to:

- Choose source.
- Configure mapping.
- Navigate candidates.
- Include or exclude.
- Correct fields.
- Confirm import.
- Cancel.

### 33.7 Larger text

- Mapping rows expand.
- Candidate detail remains readable.
- Progress labels wrap.
- Actions remain reachable.

### 33.8 Reduced Motion

Step changes use minimal transitions.

Progress remains textual and does not rely on animation.

---

## 34. Performance

### 34.1 Streaming parsing

Large CSV and JSON files should be parsed incrementally where practical.

### 34.2 PDF pages

Process with bounded concurrency.

Do not render every page at full resolution simultaneously.

### 34.3 OCR

- Limit concurrent recognition jobs.
- Release page images after required data is saved.
- Respect cancellation.

### 34.4 Candidate table

Use:

- Pagination or lazy loading.
- Stable IDs.
- Indexed status filters.

### 34.5 Duplicate detection

Batch query local normalized identities.

Avoid one database query per candidate.

### 34.6 Enrichment

Use bounded batches and respect provider limits.

### 34.7 Import commit

Use transactional chunks.

Avoid publishing one full-table refresh for every inserted card.

### 34.8 Benchmarks

Validate:

```text
10,000-row CSV
50,000-row stress CSV
100-page text PDF
50-page scanned PDF
100 images
10,000 candidates against 50,000 existing cards
```

---

## 35. Error behavior

### 35.1 File access denied

Show:

```text
Voca no longer has access to this file.
[Choose File Again]
```

### 35.2 Encoding error

Offer:

- Encoding selection.
- File preview.
- Replace invalid characters only after confirmation.

### 35.3 PDF extraction failure

Offer:

- OCR selected pages.
- Choose page range.
- Open another file.

### 35.4 OCR failure

- Preserve successfully recognized pages.
- Retry failed pages.
- Allow manual text correction.

### 35.5 Mapping error

Highlight:

- Missing required Word field.
- Duplicate target mapping.
- Invalid tag separator.

### 35.6 Enrichment failure

- Preserve candidates.
- Show failed subset.
- Retry selected.
- Skip enrichment where allowed.

### 35.7 Local persistence failure

Stop commit safely.

Preserve:

- Job.
- Candidate selections.
- Completed transaction chunks.

### 35.8 Synchronization failure

If local import succeeded:

- Report Created on This Mac.
- Show pending sync count.
- Do not mark the import failed.

---

## 36. State model

Illustrative feature state:

```swift
@MainActor
@Observable
final class ImportFeature {
    enum Phase {
        case selectingSource
        case inspecting
        case extracting(ImportProgress)
        case configuring
        case reviewing
        case enriching(ImportProgress)
        case ready
        case importing(ImportProgress)
        case completed(ImportSummary)
        case cancelled
        case failed(ImportError)
    }

    private(set) var phase: Phase = .selectingSource
    private(set) var job: ImportJob?
    private(set) var candidates: [ImportCandidate] = []
    var selection: Set<ImportCandidateID> = []
    var filters = ImportCandidateFilters()

    func chooseSource(_ source: ImportSource) async
    func extract() async
    func updateMapping(_ mapping: ImportMapping)
    func enrichSelection() async
    func commit() async
    func cancel()
}
```

### 36.1 State invariants

- No user cards before commit.
- A candidate has stable identity inside the job.
- Editing identity retriggers duplicate classification.
- Completed import operation IDs are not reused for unrelated candidates.
- Cancellation does not remove already committed cards.

---

## 37. Service boundaries

Required services:

```text
ImportSourceInspector
TextExtractionService
TextRecognitionService
PDFExtractionService
CSVParser
JSONImportDecoder
LanguageDetectionService
VocabularyCandidateGenerator
DuplicateClassificationService
CandidateEnrichmentService
ImportCommitUseCase
VocabularyExportService
TemporaryResourceStore
```

### 37.1 Source inspector

Owns:

- Type detection.
- Size limits.
- Encoding hints.
- Page and row estimates.

### 37.2 Extraction services

Own:

- Local source processing.
- Cancellation.
- Progress.

### 37.3 Candidate generator

Owns:

- Tokenization.
- Phrase detection.
- Stop-term filtering.
- Ranking.

### 37.4 Duplicate classifier

Owns:

- Local batch matching.
- Pending-card matching.
- Same-job grouping.
- Variant classification.

### 37.5 Commit use case

Owns:

- Validation.
- Stable operation IDs.
- Transactions.
- Mutation queue.
- Summary.

---

## 38. Data model

Conceptual candidate:

```swift
struct ImportCandidate: Identifiable, Sendable {
    let id: ImportCandidateID
    var include: Bool
    var language: CardLanguage?
    var canonicalText: String
    var pronunciation: String?
    var meanings: [String]
    var examples: [String]
    var tags: [String]
    var topic: String?
    var level: String?
    var personalNote: String?
    var sourceReferences: [ImportSourceReference]
    var classification: ImportCandidateClassification
    var validationIssues: [ImportValidationIssue]
    var provenance: ImportCandidateProvenance
}
```

### 38.1 Provenance

```text
Parsed from source
Matched local dictionary
Matched remote dictionary
AI generated
User edited
```

### 38.2 Source reference

May contain:

- Row number.
- Page number.
- Text range.
- Image index.

Avoid retaining the entire source merely to preserve the reference.

---

## 39. Testing strategy

### 39.1 Drag-and-drop tests

- Word.
- Passage.
- Image.
- PDF.
- CSV.
- JSON.
- Unsupported file.
- Multiple files.

### 39.2 Text tests

- English.
- Chinese.
- Mixed language.
- Punctuation.
- URLs.
- Code-like content.
- Very long passage.

### 39.3 OCR tests

- Rotated image.
- Low contrast.
- English.
- Chinese.
- Mixed.
- Low-confidence segments.
- Cancellation.

### 39.4 PDF tests

- Text PDF.
- Scanned PDF.
- Mixed PDF.
- Password protected.
- Multi-column.
- Large page count.
- Corrupt PDF.

### 39.5 CSV tests

- Comma.
- Tab.
- Semicolon.
- Quoted delimiters.
- Multiline field.
- UTF-8.
- Alternate encoding.
- Missing header.
- Duplicate columns.
- 10,000 rows.

### 39.6 JSON tests

- Current schema.
- Older supported schema.
- Newer unsupported schema.
- Unknown optional fields.
- Invalid field type.
- Oversized arrays.
- Conflicting IDs.

### 39.7 Duplicate tests

- Existing saved card.
- Pending card.
- Same-job duplicate.
- Case variant.
- Pinyin variant.
- Different language same visible text.

### 39.8 Commit tests

- Full success.
- Partial failure.
- Cancellation.
- Database failure.
- Offline local import.
- Retry after ambiguous remote submission.

### 39.9 Privacy tests

- No automatic upload.
- AI preview.
- Source text absent from logs.
- Temporary-file deletion.
- Sign-out isolation.

### 39.10 Accessibility tests

- Keyboard-only import.
- VoiceOver candidate table.
- Mapping labels.
- OCR correction.
- Progress announcements.
- Larger text.
- Increased Contrast.
- Reduce Motion.

### 39.11 Security tests

- Malformed PDF.
- CSV formula content.
- Huge file.
- Deeply nested JSON.
- Prompt-injection text.
- Path-like fields.
- Secret-like text before AI enrichment.

---

## 40. Requirement traceability

### `CAP-001` — Drag and drop

Covered by:

- Accepted input types.
- Drop states.
- Visual feedback.
- Preview before commit.

### `CAP-002` — Text capture

Covered by:

- Plain-text flow.
- Language detection.
- Candidate generation.
- Candidate review.

### `CAP-003` — Image OCR

Covered by:

- Vision OCR.
- Language configuration.
- Progress.
- Editable recognized text.
- Low-confidence review.

### `CAP-004` — PDF extraction

Covered by:

- PDF classification.
- Text extraction.
- OCR.
- Page selection.
- Cancellation.

### `CAP-005` — CSV and JSON import

Covered by:

- Column mapping.
- Schema validation.
- Duplicate classification.
- Preview.
- Completion summary.

### `CAP-006` — Export

Covered by:

- Export scope.
- CSV and JSON.
- Field selection.
- Save panel.
- Privacy defaults.

### `CAP-007` — macOS Services

The system entry point is detailed in [`macos-system-integrations.md`](macos-system-integrations.md). This document defines the resulting capture and review workflow.

---

## 41. Acceptance scenarios

### Scenario A — Drop one word

1. Drag a word into Vocabulary.
2. Review lookup result.
3. Save.

Expected:

- Language is detected.
- Duplicate check runs.
- One card is created after confirmation.

### Scenario B — Paste a passage

1. Paste a paragraph into Vocabulary.
2. Review highlighted candidates.
3. Hide already-known words.
4. Select new words.
5. Import.

Expected:

- Nothing is saved before confirmation.
- Existing cards remain unduplicated.

### Scenario C — OCR screenshot

1. Drop a screenshot.
2. Run local OCR.
3. Correct recognized text.
4. Select candidates.

Expected:

- Screenshot is not uploaded automatically.
- Candidate list reflects corrected text.

### Scenario D — Scanned PDF

1. Import a scanned PDF.
2. Select pages 5–10.
3. Run OCR.
4. Cancel midway.

Expected:

- Progress is visible.
- Completed page results may be retained.
- No cards are created.

### Scenario E — CSV mapping

1. Import CSV columns `Term`, `Definition`, and `Labels`.
2. Map them to Word, Meaning, and Tags.
3. Preview.
4. Import.

Expected:

- Mapping is clear.
- Invalid rows are classified.
- Completion summary is accurate.

### Scenario F — Duplicate CSV

1. Import rows containing saved and repeated words.

Expected:

- Saved words are classified.
- Same-file duplicates are grouped.
- Default selection includes only valid new candidates.

### Scenario G — JSON future schema

1. Import a file with a newer unsupported schema.

Expected:

- Voca does not partially import it.
- Upgrade guidance appears.

### Scenario H — AI enrichment

1. Select candidates with missing details.
2. Choose Generate Missing Details.

Expected:

- Transmission preview shows provider and candidate count.
- Whole document is excluded by default.
- Generated fields are labeled.

### Scenario I — Offline CSV import

1. Disconnect.
2. Import a valid CSV containing complete fields.

Expected:

- Parsing and preview work.
- Cards save locally after confirmation.
- Pending sync state is reported.

### Scenario J — Partial persistence failure

1. Import a large batch.
2. Simulate storage failure after several chunks.

Expected:

- Successful chunks remain.
- Failed remainder is reported.
- Retry does not duplicate created cards.

### Scenario K — Export privacy

1. Export a collection.
2. Leave personal notes disabled.

Expected:

- Notes are not present.
- Credentials are never present.
- Selected fields match preview.

### Scenario L — Account switch

1. Start an import as account A.
2. Switch accounts before commit.

Expected:

- Job pauses or closes safely.
- It cannot commit into account B.
- Temporary data remains account-isolated.

### Scenario M — VoiceOver import

1. Import a CSV using VoiceOver and keyboard.
2. Map fields.
3. Select valid rows.
4. Confirm.

Expected:

- Steps, mapping, status, progress, and summary are understandable.

### Scenario N — Malicious source text

1. Import text containing instructions directed at an AI model.
2. Run optional enrichment.

Expected:

- Source content is treated as data.
- Product task instructions remain authoritative.

---

## 42. Product decisions proposed

The following should be recorded in `macos-decisions.md` after review:

1. Complex imports use a dedicated resizable window.
2. No multi-item import creates cards before candidate confirmation.
3. OCR and ordinary text extraction run locally by default.
4. AI enrichment requires an explicit action and transmission preview.
5. Personal notes and full source documents are excluded from AI enrichment by default.
6. Candidate identity remains stable inside an import job.
7. Editing candidate identity retriggers duplicate classification.
8. Pending local cards count as duplicates.
9. Large imports commit in durable bounded chunks.
10. Retry reuses stable per-item operation IDs.
11. Partial import success is preserved and reported.
12. Temporary source files have an explicit retention policy.
13. Voca does not modify original source files.
14. CSV and Voca JSON are the initial import and export formats.
15. Personal notes and review history are excluded from export by default.
16. Generic JSON schema guessing is out of scope for the first release.

---

## 43. Open questions

1. What maximum file, page, row, and candidate limits should ship?
2. Which image formats should be explicitly supported?
3. Which PDF framework and OCR path provide the best local behavior?
4. Should completed OCR pages persist for job recovery?
5. Does the backend support batch card creation?
6. Which fields are required to create an incomplete offline card?
7. Should the client use a local English tokenizer library?
8. Which Chinese segmentation strategy should be used?
9. Should imported phrase candidates be enabled by default?
10. Which duplicate-normalization rules are shared with the backend?
11. Is traditional-to-simplified Chinese variant matching required?
12. Should imported jobs create a persistent Imported collection?
13. How long should completed import history remain?
14. Should source page or row references remain after import?
15. Should extracted source sentences be stored as examples?
16. What provider and request size limits apply to batch enrichment?
17. Should CSV export mitigate spreadsheet formulas by prefixing, quoting, or warning?
18. Which Voca JSON fields are portable across accounts?
19. Should review state ever be included in ordinary JSON export?
20. Does the first release need an Anki adapter?

---

## 44. Backend and platform dependencies

The complete workflow may require:

- Stable dictionary-entry lookup.
- Batch duplicate lookup.
- Batch card creation.
- Idempotent creation operation IDs.
- Tags and topics.
- Import-job association.
- Optional batch AI enrichment.
- Soft deletion for rollback workflows.
- Vision text recognition.
- PDF text extraction.
- Security-scoped file access.
- App sandbox file permissions.

Recommended batch API characteristics:

```text
Per-item operation ID
Per-item result
Existing-card result
Validation error
Retryable flag
Authoritative created entity
```

---

## 45. Definition of done

Import and Capture are complete for the first public release when:

- Drag and drop recognizes supported input types.
- Plain text produces reviewable candidates.
- Image OCR works locally for English and Chinese.
- PDF text extraction and selected-page OCR work.
- CSV mapping handles common delimiters and encodings.
- Voca JSON is versioned and validated.
- Candidates are classified as new, saved, duplicate, or invalid.
- No multi-item workflow saves before confirmation.
- Large imports provide progress and cancellation.
- Partial failures produce a clear summary.
- Retry cannot duplicate successful cards.
- Temporary files follow the retention policy.
- Export accurately reflects selected scope and fields.
- Personal notes and review metadata follow privacy defaults.
- AI enrichment is explicit and previewed.
- Offline parsing and local commit work according to documented capability.
- VoiceOver, keyboard, larger text, Increased Contrast, and Reduce Motion pass.
- Security tests cover malformed files, oversized input, CSV injection, and prompt injection.
- Critical parsing, OCR, duplicate, import, export, privacy, and recovery tests pass.

---

## 46. Next document

The next document should be:

```text
docs/macos-security-and-privacy.md
```

It should define:

- Security boundaries.
- Threat model.
- Keychain.
- Authentication credentials.
- Local database protection.
- Account isolation.
- App Group data.
- Clipboard.
- Imported files.
- AI transmission.
- Microphone and speech.
- Spotlight, widgets, and notifications.
- Logging and diagnostics.
- Analytics.
- Data retention.
- Sign-out cleanup.
- Local-data deletion.
- Incident and recovery behavior.
- Security testing and release gates.
