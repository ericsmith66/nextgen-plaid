
# Epic: AGENT-03 - Enhanced SAP Iteration & Collaboration (Refined)

## Overview
AGENT-03 evolves SAP with adaptive iteration, multi-agent orchestration, dynamic context pruning, UI oversight extensions, and async queues, building on AGENT-02C baseline. Ties to vision: Supports scalable, overseen dev for Plaid enrichments (e.g., iterative holdings review), ensuring reliable financial sync in nextgen-plaid.

## Key Improvements
- **Adaptive Iteration**: Scoring-based retries/escalation with caps.
- **Multi-Agent Orchestration**: Conductor routes sub-agents iteratively via queues.
- **Context Optimization**: Heuristic pruning with token targets.
- **UI Extensions**: Real-time monitoring, approvals, audits.
- **Async Queues**: Batch processing with TTLs, encryption.

## Atomic PRDs (Stories)
| ID | Title | Description | Dependencies |
|----|-------|-------------|--------------|
| 0010 | Adaptive Iteration Engine | Extend AGENT-02C-0020: Add #adaptive_iterate; scoring (<80% retry Ollama max 2, <70% escalate Grok 4.1/Claude Sonnet 4.5); hard max 7 iterations; 500 token budget cap per task. | AGENT-02C-0020 |
| 0020 | Multi-Agent Conductor | Implement Conductor in sap_agent.rb: Sub-agents (Outliner: decompose, Refiner: iterate, Reviewer: score); routing rules (serial Solid Queue, state via JSON blobs); serialize/restore between jobs. | 0010, AGENT-02C-0040 |
| 0030 | Dynamic Context Pruning | Add #prune_context: Heuristic (<4k tokens/call; relevance via Ollama eval + age prune >30 days via code_execution); latency <200ms; optional PGVector if limits hit (defer post-validation). | 0020, AGENT-02B |
| 0040 | UI Enhancements for Oversight | Extend AGENT-02C-0030: Devise RLS for roles; ActionCable real-time; approval forms; audit logs to sap.log; dashboard alerts for failures/timeouts (DaisyUI). | 0030, AGENT-02C-0030 |
| 0050 | Async Queue Processing | Add #queue_task: Solid Queue batches (24h TTL); encrypt payloads (attr_encrypted); UI monitoring; green commits only. | 0040 |

## Architectural Context
- **Service Updates**: sap_agent.rb as orchestrator; UI in admin controllers with ActionCable.
- **Dependencies**: AGENT-02C merges; Ollama 70B default.
- **Risks/Mitigations**: Runaway loops—max 7/TTLs; costs—Ollama priority; privacy—encrypt at rest/transit.
- **Testing**: RSpec mocks for escalation; Capybara for UI; load/soak for queues/ActionCable (10 tasks sim via code_execution).

## Roadmap Tie-In
Post-AGENT-02C; preps for CWA curriculum iteration.

Next steps: Proceed to AGENT-02C implementation starting with 0010; generate its PRD using Eric_Grok template? Questions: Prioritize PGVector in 0030 optional, or park entirely?