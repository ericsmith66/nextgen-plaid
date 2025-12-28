# Epic: AGENT-02C - Reviews & Interaction (Refined)

## Overview
AGENT-02C implements SAP's code review method, iterative prompt logic, human interaction tools, and queue-based storage handshake, with refined thresholds, schemas, and test harnesses for reliability. Ties to vision: Enables targeted feedback on Plaid features (e.g., reviewing transaction sync code) and interactive refinement for curriculum/PRD tasks, ensuring high-quality, privacy-focused Rails dev in nextgen-plaid.

## Key Improvements
- **Code Review Method**: Diff-based file selection (3-5 files), RuboCop integration with redaction, structured JSON output.
- **Iterative Prompt Logic**: Capped multi-turn loops (max 5 iterations) with scoring/stop conditions (>80% confidence) and human injection points.
- **Human Interaction**: Rake tasks with auth, polling, and error handling; outputs to stdout/pbcopy.
- **Queue Storage**: Idempotent commits with conflict resolution, focusing on green-only artifacts.

## Atomic PRDs (Stories)
| ID | Title | Description | Dependencies |
|----|-------|-------------|--------------|
| 0010 | SAP Code Review Method | Add #code_review: Input branch/commit; select 3-5 files via git diff (code_execution, prioritize models/services/tests); fetch via browse_page (raw URLs); analyze with RuboCop (config/rubocop.yml, 30s timeout); redact sensitive (regex for ENV/API keys); output JSON schema: { "strengths": [strings], "weaknesses": [strings], "issues": [{ "offense": string, "line": int }], "recommendations": [strings] }; store in agent_logs/sap.log. | AGENT-02A (tools/router) |
| 0020 | SAP Iterative Prompt Logic | Add #iterate_prompt: Decompose into phases (max 5 iterations); scoring via Ollama self-eval (>80% stop, <70% escalate to Grok 4.1); states: Pending/Paused/Resumed/Completed; human input via rake injection; default Ollama 70B, Claude Sonnet 4.5 toggle for precision. | 0010, AGENT-02B (RAG/backlog) |
| 0030 | SAP Human Interaction Rake | Implement rake sap:interact[task_id]: Devise current_user auth; poll every 10s (5min timeout); output to stdout/pbcopy (Mac); surface errors as alerts (e.g., queue failures logged to sap.log). | 0020 |
| 0040 | SAP Queue-Based Storage Handshake | Add #queue_handshake: Commit format "AGENT-02C-[ID]: [Task Summary] by SAP"; UUID idempotency keys; handle dirty workspace (stash/retry); conflict resolution via git merge --abort if fails. | 0030, AGENT-02B (backlog) |

## Architectural Context
- **Service Updates**: app/services/sap_agent.rb with methods; use existing router for LLM/escalation; RuboCop via gem (timeout via Timeout lib).
- **Dependencies**: AGENT-02A/B; plaid-ruby testing patterns for mocks.
- **Risks/Mitigations**: Iteration overload—cap 5; privacy—redact in reviews, encrypt queues; runaway rake—timeouts.
- **Testing**: Mock browse_page + RuboCop for 0010; queue sim for 0020/0040; auth/unit for 0030 (RSpec); harnesses: VCR/WebMock for determinism.

## Roadmap Tie-In
Complete before AGENT-03; enables iterative Plaid PRD refinement (e.g., OATH-1).
