
# Epic: AGENT-03 - Enhanced SAP Iteration & Collaboration (Refined)

## Overview
AGENT-03 evolves SAP with adaptive iteration, multi-agent orchestration, dynamic context pruning, UI oversight extensions, and async queues, building on AGENT-02C baseline. Ties to vision: Supports scalable, overseen dev for Plaid enrichments (e.g., iterative holdings review), ensuring reliable financial sync in nextgen-plaid.

## Key Improvements
- **Adaptive Iteration**: Scoring-based retries/escalation with SapAgent::Config caps (7 iterations, 500 tokens), shared scoring template, deterministic retries, and single escalation guardrail.
- **Multi-Agent Orchestration**: Conductor routes sub-agents iteratively via Solid Queue with idempotency keys, schema validation, and circuit-breaker fallback.
- **Context Optimization**: Heuristic pruning with token targets, 2k min-keep floor, weighted relevance/age, and PGVector deferred behind a flag.
- **UI Extensions**: Real-time monitoring, approvals, audits with RLS-scoped ActionCable, redaction, and latency/approval metrics.
- **Async Queues**: Batch processing with TTLs, encryption key rotation, dead-letter handling, and batch guardrails.

## Atomic PRDs (Stories)
| ID | Title | Description | Dependencies |
|----|-------|-------------|--------------|
| 0010 | Adaptive Iteration Engine | Extend AGENT-02C-0020: Add #adaptive_iterate using SapAgent::Config (7 iterations/500 tokens), shared scoring template/normalization, deterministic retries (150/300ms), and single escalation guardrail (Grok → Claude → Ollama retry). | AGENT-02C-0020 |
| 0020 | Multi-Agent Conductor | Implement Conductor in sap_agent.rb: Sub-agents (Outliner, Refiner, Reviewer) via Solid Queue (`sap_conductor`) with idempotency keys, schema validation, circuit-breaker fallback, and shared scoring/caps. | 0010, AGENT-02C-0040 |
| 0030 | Dynamic Context Pruning | Add #prune_context: Heuristic (<4k tokens, >=2k floor; relevance 70% + age 30%); latency <200ms via TimeoutWrapper; PGVector deferred behind ENV flag only. | 0020, AGENT-02B |
| 0040 | UI Enhancements for Oversight | Extend AGENT-02C-0030: Devise RLS; tenant-scoped ActionCable; approval forms; audit logs with redaction/metrics; DaisyUI alerts with correlation_id. | 0030, AGENT-02C-0030 |
| 0050 | Async Queue Processing | Add #queue_task: Solid Queue (`sap_general`) batches (24h TTL) with encryption key rotation/version headers, dead-letter (`sap_dead`), batch guardrails (max 10), and UI monitoring. | 0040 |

## Architectural Context
- **Service Updates**: sap_agent.rb as orchestrator; UI in admin controllers with ActionCable.
- **Dependencies**: AGENT-02C merges; Ollama 70B default; Solid Queue present/verified; SapAgent::Config centralizes caps/escalation/model order.
- **Risks/Mitigations**: Runaway loops—max 7/TTLs + single escalation; costs—Ollama priority; privacy—encrypt at rest/transit with key rotation and redaction; queue failure—circuit-breakers + dead-letter.
- **Testing**: RSpec mocks for escalation/queue/encryption; Capybara for UI; load/soak for queues/ActionCable (10 tasks sim via code_execution) and adaptive loops/conductor chains.

## Roadmap Tie-In
Post-AGENT-02C; preps for CWA curriculum iteration.

Next steps: Proceed to AGENT-02C implementation starting with 0010; AGENT-03 to follow with SapAgent::Config baseline, PGVector deferred, and queue/action logging schema alignment.