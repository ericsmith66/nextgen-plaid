# PRD — Junie Task Log Requirements

## Purpose
Create a consistent, reviewable, and commit-friendly way for Junie (running in Brave mode) to record **what was done for a specific task** into the repository so the team can track decisions, changes, commands, and outcomes over time.

This document defines:
- Where task logs live in the repo
- The exact structure (template) each log must follow
- The rules for updates, safety, and committing

---

## Goals
- **Traceability:** Every task has an auditable record of intent → actions → results.
- **Reviewability:** Logs are human-readable and optimized for code review.
- **Consistency:** Same format across tasks so searching/comparing is easy.
- **Low friction:** Writing the log should not slow work down.
- **Safety:** Never store secrets or sensitive data in logs.

## Non-Goals
- Capturing full chat transcripts.
- Storing personal data, credentials, or customer information.
- Replacing standard code documentation (README/API docs) or commit messages.

---

## Storage Location & Naming

### Directory
All Junie task logs MUST be stored in:
- `knowledge_base/prds-junie-log/`

### File naming
Each task log MUST use this format:
- `YYYY-MM-DD__<task-slug>.md`

Rules:
- `YYYY-MM-DD` is the date the task was started (local time).
- `<task-slug>` is lowercase, words separated by hyphens.
- No spaces. No special characters besides `-`.

Examples:
- `2025-12-16__csv-3-accounts-import.md`
- `2025-12-16__mission-control-costs-export.md`

---

## When to Create / Update / Commit

### Creation
A task log MUST be created at the start of work (before or alongside the first code change).

### Updates
The task log MUST be updated at these moments:
- After major decisions (architecture, approach changes)
- After implementing meaningful chunks (new feature, refactor, migration)
- After running tests or encountering failures
- Before opening a PR (final summary)

### Committing
Task logs MUST be committed to the repo:
- In the **same PR/branch** as the code changes for that task, or
- As a standalone commit if the task produced documentation only

Preferred: include the log in the final “feature complete” commit or the last commit before PR.

---

## Security & Safety Requirements (Hard Rules)

The task log MUST NOT contain:
- Passwords, API keys, tokens, private keys, session cookies
- Real account numbers, SSNs, or other personally identifying info
- Internal URLs that reveal private infrastructure (use placeholders)
- Anything that “looks like” credentials

Instead, use placeholders like:
- `<API_KEY_PLACEHOLDER>`
- `<TOKEN_PLACEHOLDER>`
- `<PRIVATE_URL_PLACEHOLDER>`
- `<REDACTED_VALUE>`

---

## Required Structure (Exact Template)

Each task log MUST follow this template and headings exactly (add content under them; do not rename headings):

---

# Junie Task Log — <TASK TITLE>
Date: YYYY-MM-DD  
Mode: Brave  
Branch: <branch-name>  
Owner: <name-or-handle>

## 1. Goal
- <one sentence summary of what success looks like>

## 2. Context
- <why this task is happening, any constraints, relevant references>
- <links to PRD or issue if applicable>

## 3. Plan
1. <step>
2. <step>
3. <step>

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- <time or step>: <what was done>
- <time or step>: <what was done>

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `path/to/file` — <what changed>
- `path/to/file` — <what changed>

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `<command>` — <result>
- `<command>` — <result>

## 7. Tests
Record tests that were run and results.

- `<command>` — ✅ pass / ❌ fail — <notes if needed>

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: <what>
    - Rationale: <why>
    - Alternatives considered: <optional>

## 9. Risks / Tradeoffs
- <risk or tradeoff>
- <mitigation or follow-up>

## 10. Follow-ups
Use checkboxes.

- [ ] <follow-up item>
- [ ] <follow-up item>

## 11. Outcome
- <what shipped / what changed / what is now true>

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- `<commit message>` — `<commit hash>`
- Pending

---

## Quality Bar (Acceptance Criteria)
A task log is considered complete when:
- It exists in `knowledge_base/prds-junie-log/` with correct naming
- It contains all required headings from the template
- `Files Changed` reflects reality (no missing files)
- `Tests` includes at least one relevant test command (or a clear note explaining why none were run)
- No secrets or sensitive values are present
- `Outcome` and `Commit(s)` are filled in (or “Pending” is intentional and later updated)

---

## Optional Enhancements (Nice-to-Have)
- Add a short “Before/After” section when behavior changes.
- Add a “Screenshots” section for UI tasks (store images under `knowledge_base/prds-junie-log/assets/` if needed).
- Add links to PRs once opened/merged.

---