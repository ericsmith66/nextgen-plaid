### Junie Feedback on Epic 3: Reviews & Interaction (AGENT-02C)

#### 1) Observations
- Strong alignment with 0_AI_THINKING_CONTEXT and MCP: scoped reviews (3–5 files), capped iterations (max 5), human-in-the-loop rake, and idempotent queue handshakes.
- Logging/privacy/timeouts are called out across stories; JSON outputs and RuboCop integration are clear.

#### 2) Clarifying Questions (per story)
- **0010 Code Review**: Canonical log schema for `agent_logs/sap.log`? Include `task_id/branch/uuid/model_used/elapsed_ms/score`? Redaction policy—regex list (ENV|API|token|secret); hash vs. drop? Prioritization when diff >5 files (models/services/tests first; exclude deleted/binary)? RuboCop scope—config path/version and cops to disable for noise?
- **0020 Iterative Prompt Logic**: Where to persist loop state (in-memory vs. queue payload vs. Postgres/Redis)? Human input injection—append to context or replace a phase? Exact pause/resume signal? Escalation budget caps beyond score <70?
- **0030 Human Interaction Rake**: Owner-only auth in rake—Devise check, service guard, or ENV token? pbcopy optional/guarded for non-macOS? Polling output also to dashboard or file-only?
- **0040 Queue-Based Storage Handshake**: Commit author/email/branch target (always main)? Allow dry-run/no-push? Idempotency key storage location (log only or persisted)? Retry limit for stash/apply; conflict policy?

#### 3) Improvement Suggestions
- **Shared logging schema** across 0010–0040: JSON with correlation IDs; include task_id/uuid/branch/model/score/elapsed_ms/outcome to simplify dashboards/ActionCable later.
- **Secrets redaction spec**: Define patterns + unit tests; add allow/deny list to avoid over-redaction; redact (drop) rather than hash unless required.
- **Deterministic file selection (0010)**: Prioritize added/modified files → models/services/tests → highest churn; exclude deleted/binary; cap offenses returned (e.g., top 20) and run RuboCop safe cops (Lint/Security/Style subset) with 30s timeout.
- **Model escalation & budgets (0020)**: Explicit rules—<80 retry (max 2), <70 escalate; hard token/cost ceiling per run; log escalation decisions.
- **State persistence (0020)**: Store phase outputs + scores in JSON (queue payload or lightweight store) with pause/resume token for reproducibility.
- **Rake UX (0030)**: Platform guard for pbcopy with file/stdout fallback; auth via shared service (owner/admin) to avoid Devise coupling in rake; surface queue errors as alerts and logs.
- **Handshake safety (0040)**: Add dry-run/no-push flag; preflight clean workspace; store idempotency UUID + commit hash in logs; limit stash/apply retries; require green tests before push.
- **Error surfacing**: Minimal UI/banner stub for timeouts/failures so issues are visible before AGENT-03 UI work.
- **Load/soak mini-plan**: Simulate ~10 queue jobs + 5 iterative loops to validate caps/TTLs.

#### 4) Next Steps
- Confirm answers to clarifying questions; then fold decisions into each PRD’s Requirements/AC/Test sections.
- Standardize the logging schema and redaction rules once approved; update PRDs accordingly.