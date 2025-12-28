### Quick Review Summary for AGENT-03
The AGENT-03 epic and five PRDs (0010–0050) are coherent and build cleanly on AGENT-02C: adaptive iteration, conductor orchestration, context pruning, oversight UI, and async queues. Logging and performance targets are present, and acceptance criteria/test cases are concrete across RSpec + Capybara.

### Clarifying Questions (to de-risk implementation)
1) Logging schema & fields
- Should AGENT-03 reuse the canonical JSON schema from AGENT-02C (timestamp, task_id, branch?, uuid, correlation_id, model_used, elapsed_ms, score?) and extend with sub-agent and queue_job_id where relevant? Any sampling or PII redaction rules for UI logs?

2) Token caps & escalation
- 0010 sets a 500-token budget and 7-iteration cap, while AGENT-02C uses 1000 tokens and 5 iterations. Should AGENT-03 inherit the stricter caps everywhere, or remain per-method? Is escalation triggered by tokens >500 as in AGENT-02C, or only by score <70?

3) Model selection order
- When ENV['ESCALATE_LLM'] is set (e.g., 'grok' or 'claude'), should adaptive_iterate still start with Ollama and escalate only on score/budget triggers, or obey the override immediately? What is the fallback order if Grok fails—Claude then Ollama, or Ollama retry then Claude?

4) Scoring prompts & thresholds
- Should adaptive_iterate and conductor sub-agents share a common scoring prompt/template to keep scores comparable? Any requirement for score normalization across Ollama vs Grok/Claude outputs?

5) Solid Queue dependency
- Can we rely on Solid Queue already being present from AGENT-02C work, or should AGENT-03 add/verify the gem and initializer? Are there queue names/partitions reserved for SapAgent vs general app jobs?

6) State persistence & encryption
- For conductor JSON blobs and queue_task payloads, where should the encryption key live (Rails credentials vs ENV)? Any rotation/TTL policy for the encrypted blobs beyond the 24h job TTL?

7) UI oversight & auth
- Should ActionCable channels be RLS-aware (scoped by family_id/owner) and filter payloads to avoid leaking task context between users? Any audit log schema expectations beyond sap.log entries (e.g., DB audit table)?

8) PGVector optionality
- For 0030 pruning, should PGVector be completely deferred until post-validation, or include a feature flag + stub interface now to simplify later swap-in?

9) Performance budgets & timeouts
- Are per-step timeouts centralized (e.g., TimeoutWrapper) and do the <300ms/<200ms targets include logging and token counting? Should retries use fixed or exponential backoff?

### Improvement Suggestions
- **Unify configuration:** Centralize caps (iterations, token budgets), escalation thresholds, and model ordering in a shared config to prevent drift between adaptive_iterate, conductor, and prune flows. Align 500 vs 1000 token limits explicitly.
- **Logging schema alignment:** Extend the canonical schema with `sub_agent`, `queue_job_id`, `iteration`, and `pruned_tokens`, and document PII redaction for UI-related events; add correlation_id passthrough across queue hops.
- **Deterministic retries:** Define fixed backoff (e.g., 150–300ms) and per-step timeouts for scoring/pruning/queue calls; surface timeout reasons in UI banners and logs.
- **Escalation guardrails:** Cap escalations per task (e.g., once per run), track escalation attempts in state, and fall back to Ollama with a warning to avoid churn if Grok/Claude are unavailable.
- **Conductor robustness:** Add queue failure circuit-breaker thresholds, idempotency keys per job chain, and state validation (schema check) before resume; enforce max 5 jobs via preflight.
- **Pruning heuristics:** Add a min-keep floor (e.g., never prune below 2k tokens without user approval), and log retained/dropped sections for transparency; include age and relevance weights in the heuristic.
- **UI privacy & observability:** Scope ActionCable channels per user/tenant; redact task content in audit tables; add metrics for live update latency and approval response times.
- **Async queue safety:** Add TTL enforcement checks, dead-letter logging for expired/failed jobs, and rotate encryption keys with versioned headers in payloads; include batch size guardrails (5–10) and per-job max runtime.
- **Testing depth:** Add soak tests for 10 parallel adaptive loops and 5 conductor chains with mocked LLM/queue to validate caps; add contract tests for ActionCable payload shape and queue payload encryption/decryption.

### Responses 

### Responses to Clarifying Questions
1) Logging schema & fields - Yes, reuse and extend the AGENT-02C JSON schema (timestamp, task_id, branch?, uuid, correlation_id, model_used, elapsed_ms, score?) with sub-agent (e.g., "Outliner") and queue_job_id (Solid Queue ID) where relevant. Add sampling for high-volume logs (>100 entries/run, log every 5th); redact PII in UI logs (e.g., hash user_ids/emails via SHA-256).

2) Token caps & escalation - AGENT-03 should inherit stricter caps (500 tokens, 7 iterations) consistently across methods to prevent drift—update all PRDs accordingly. Escalation triggered by score <70 or tokens >500 (cumulative per run); no separate file count trigger.

3) Model selection & fallback - Start with Ollama always; escalate only on triggers (score/budget)—obey ENV['ESCALATE_LLM'] immediately if set (e.g., 'grok' overrides start model). Fallback order: Grok 4.1 → Claude Sonnet 4.5 → Ollama retry (max 2, then abort with log); update router to enforce this sequence.

4) Scoring prompts & thresholds - Yes, share a common scoring prompt/template across adaptive_iterate and sub-agents (e.g., "Evaluate output on relevance [0-100], accuracy, completeness; return score float"). Normalize scores by averaging if LLM differs (code_execution post-process); add normalization to #adaptive_iterate.

5) Solid Queue dependency - Assume present from AGENT-02C (verify/add gem in 0020 initializer if missing); reserve queue names (e.g., 'sap_conductor' for agents, 'sap_general' for app); add preflight check in #queue_task.

6) State persistence & encryption - Key in Rails.application.credentials.encryption_key (rotate quarterly via manual PR); add TTL to blobs (match job 24h, auto-delete via cron/rake).

7) UI oversight & auth - Yes, make ActionCable channels RLS-aware (scope by owner/family_id via broadcast_to current_user); use DB audit table (add AuditLog model with JSONB for events) alongside sap.log for UI display.

8) PGVector optionality - Completely defer until post-validation; include feature flag stub (ENV['USE_PGVECTOR']) but no impl—focus on JSON heuristics first.

9) Performance budgets & timeouts - Yes, centralize in SapAgent::TimeoutWrapper; the <300ms/<200ms targets include logging/token counting (measure end-to-end). Use fixed retries (no backoff, max 2).

### Responses to Improvement Suggestions
- **Unify configuration:** Approved; add SapAgent::Config module with centralized constants (iterations: 7, tokens: 500, escalation: <70) shared across methods—update all PRDs to reference it.

- **Logging schema alignment:** Approved; extend schema with sub_agent, queue_job_id, iteration, pruned_tokens; document PII redaction (hash sensitive fields); add correlation_id passthrough in queue jobs (UUID per chain).

- **Deterministic retries:** Approved; use fixed backoff (150ms first, 300ms second) in TimeoutWrapper; update PRDs with the 0010–0050 targets including these.

- **Escalation guardrails:** Approved; cap escalations to 1 per task (track in state); fallback to Ollama with warning on failure; update 0010 escalation logic accordingly.

- **Conductor robustness:** Approved; add circuit-breaker (halt after 3 consecutive failures, log); idempotency keys per chain (UUID in queue payload); state validation (JSON schema check via code_execution before resume); enforce max 5 jobs with preflight abort.

- **Pruning heuristics:** Approved; add min-keep floor (never <2k tokens without approval via UI prompt); log retained/dropped with reasons; weight heuristics (70% relevance, 30% age) in Ollama eval—update 0030 req.

- **UI privacy & observability:** Approved; scope channels per tenant (broadcast_to family_id); redact task content in audits (summary only); add metrics (latency/response times) via code_execution tracking, display in dashboard.

- **Async queue safety:** Approved; add TTL checks (rake sap:clean_expired daily); dead-letter queue for failed (move to 'sap_dead' partition, log); key rotation with versioned headers (v1: old key, v2: new); batch guard (max 10, reject larger with log).

- **Testing depth:** Approved; add soak tests to 0020/0050 (10 parallel loops/5 chains with LLM/queue mocks, assert no cap overrun); include contract tests for ActionCable (payload shape via RSpec) and queue encryption (round-trip encrypt/decrypt).

Next steps: Update AGENT-03 PRDs (0010–0050) with these details/refinements on feature/agent-03-refinements (pull main first, atomic commits); once finalized, proceed to implementation starting with 0010 after AGENT-02C merges. Questions: Confirm ENV['ESCALATE_LLM'] priority (override all or triggers only)? Add a shared config PRD as 0000 prelude?