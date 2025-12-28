### Quick Review Summary for AGENT-02C
The epic and four PRDs are coherent and aligned with 0_AI_THINKING_CONTEXT and MCP: strong on scoped file review (0010), capped iterative loops (0020), human-in-the-loop via rake (0030), and idempotent storage handshakes (0040). Logging, privacy/redaction, and timeouts are noted. Acceptance criteria and test cases are concrete.

### Clarifying Questions (to de-risk implementation)
1) Logging & schema
- Is there a canonical JSON schema for log entries in `agent_logs/sap.log` (fields, levels, correlation ids)? Should all methods include `task_id`, `branch`, `uuid`, `model_used`, `elapsed_ms`, and `score`?
- Should logs also emit a user-facing summary to the dashboard or remain file-only?

2) Model selection & cost controls
- What are the default/model selection rules: always Ollama 70B, escalate to Grok 4.1/Claude only on score <70, or also when token budget >500 or file count >5? Any hard budget caps per run?

3) Redaction & privacy
- What exact regex/policy for redacting secrets in code review (ENV|API keys, tokens, secrets)? Should we hash or drop matches? Should we also redact emails/domains or only obvious secrets?

4) RuboCop
- Confirm config path `config/rubocop.yml` and version pin. Should we run only on fetched snippets or temp files? Any cops to disable for agent reviews (e.g., Metrics cops) to keep noise low?

5) Git/diff context
- For 0010, if diff contains >5 files, do we prioritize by paths (models/services/tests) and then by churn? Should we include deleted files or only added/modified? What is the fallback when git is unavailable (e.g., CI sandbox)?

6) Iteration loop state
- Where do we persist iteration state (in-memory hash vs. Redis/Postgres vs. Solid Queue args)? How is human input injected—append to context or replace phase notes? What’s the exact pause/resume signal format in the queue?

7) Rake auth & UX
- For sap:interact, how do we enforce owner-only in a rake context—Devise Warden mock, ENV-based token, or a service object check? Is pbcopy optional/guarded for non-macOS?

8) Queue handshake
- For #queue_handshake, what is the accepted commit author/email and branch target (always main)? Should we allow dry-run/no-push mode? Any required commit message suffixes (ticket link)?

9) Timeouts & retries
- Are global timeouts/retries centralized (e.g., 30s RuboCop, 200ms pruning, 5min rake timeout)? Should retries be exponential or fixed? Where do we surface timeout messages in UI?

10) Testing approach
- Can we rely solely on RSpec + WebMock/VCR, or do we also want contract tests for rake tasks via Aruba/CLI harness? Any requirement for CI fixtures for git/diff/rubocop outputs?

### Improvement Suggestions
- Standardize a shared logging schema (JSON) and correlation IDs across 0010–0040 to make dashboards/ActionCable simpler later.
- Add a secrets redaction spec (patterns + unit tests) and a small allowlist/denylist to avoid over-redaction.
- Define deterministic prioritization for file selection in 0010 (e.g., modified → models/services/tests → highest churn) and explicitly exclude deleted/binary files.
- Scope RuboCop to safe cops for review runs (Lint/Security/Style subset) with a 30s timeout and cap offenses returned (e.g., top 20).
- Set explicit model escalation rules and budget caps (e.g., <70 score → Grok 4.1; >500 tokens or 2 failed retries → escalate; hard cost ceiling per run).
- Persist iteration state (0020) in a lightweight store (JSON column or queue payload) with a pause/resume token; include accumulated context and scores for reproducibility.
- For sap:interact, add platform guards for pbcopy and a fallback to write to a temp file; authenticate via a shared service that checks owner role to avoid Devise coupling in rake.
- For queue_handshake, add a dry-run/no-push flag, enforce clean workspace preflight, and store idempotency UUID + commit hash in the log schema; consider a retry limit for stash/apply.
- Add a minimal UI/error surfacing stub (toast/banner) for timeouts/errors from 0010–0040 so failures are visible before AGENT-03 UI work.
- Add load/soak mini-plan: simulate 10 parallel queue jobs and 5 iterative loops to validate caps/TTLs.

If you confirm the answers to the questions above, I can fold them into the PRDs so they’re implementation-ready.

### Responses (User Confirmed) — Incorporated into PRDs
- **Logging schema**: Canonical JSON {timestamp, task_id, branch?, uuid, correlation_id, model_used, elapsed_ms, score?} file-only for now.
- **Models/costs**: Default Ollama 70B; escalate to Grok 4.1 on score <70 or tokens >500; Claude Sonnet 4.5 via env or Grok fallback; hard cap 1000 tokens/run.
- **Redaction**: Regex /\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV[\w_]+)\b/i; hash matches; allowlist/denylist in config/redaction.yml; avoid email/domain redaction unless matched.
- **RuboCop**: config/rubocop.yml pinned >=1.60; run on tmp snippets; Metrics disabled, focus Lint/Security/Style; cap top 20 offenses; 30s TimeoutWrapper.
- **File selection (0010)**: Added/modified only; prioritize models/services/tests then churn; exclude deleted/binary; fallback to pasted/backlog files if git unavailable.
- **Iteration state (0020)**: Persist via JSON (in-memory) or JSONB IterationState for pauses; pause payload {state:"paused", resume_token}; append human feedback to context.
- **Rake auth/UX (0030)**: Owner-only via AuthService; pbcopy guarded by OS (RbConfig) with temp-file fallback; emit correlation_id in outputs.
- **Queue handshake (0040)**: Author "SAP Agent <sap@nextgen-plaid.com>"; commit msg suffix link to PRD; DRY_RUN env; clean-workspace preflight with stash/apply retry max 3; log uuid/hash.
- **Timeouts/retries**: Central TimeoutWrapper (30s RuboCop, ~200ms prune, 5min rake); fixed retries max 2; DaisyUI/stdout alerts for web-triggered errors.
- **Testing**: RSpec + WebMock/VCR; Aruba for rake; fixtures for git_diff/rubocop; soak sims (10 queue jobs, 5 loops) added.