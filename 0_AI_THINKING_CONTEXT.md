# 0_AI_THINKING_CONTEXT

Version: 1.0 (December 28, 2025) — update via PR when vision evolves; keep changelog notes with each version bump.

## Project Vision Recap
NextGen Plaid is a local-first Ruby on Rails 7+ application that securely synchronizes financial data from JPMC, Schwab, Amex, and Stellar using Plaid's investments, transactions, liabilities, and enrichment APIs. It powers a virtual family office AI tutor for U.S. families with $20M–$50M assets, educating heirs (18–30) on wealth stewardship via a structured paid internship ($60k–$120k/year deductible salary tied to milestones). Core goal: Prevent "shirtsleeves to shirtsleeves" through CFP®-level curriculum (5 levels: Money Mindset to Future CIO), real/anonymized portfolio insights, and simulations (e.g., 2026 estate-tax sunset). All data/computation stays closed-system, privacy-first—no cloud unless explicitly opted-in.

## Data Handling Rules
- Snapshots (e.g., daily `FinancialSnapshotJob`) produce sanitized JSON blobs per user (totals, allocations, tasks, risk scores) from Plaid models (User, PlaidItem, Account, Transaction, Position) or manual enrichments (e.g., uploaded tax docs like 1099s/K-1s, income forecasts, trust/contract PDFs—stored encrypted via `attr_encrypted`).
- PII is masked/omitted in snapshots; manual doc ingestion requires explicit user consent and audit logging. Never expose raw identifiers in agent responses.
- Support three Plaid modes: Mock (`portfolio_mock.json`), Anonymized (scrubbed tokens), Full (read-only); prefer Mock/Anonymized for simulations.
- Ground responses in snapshot JSON + static docs (e.g., family constitution, `knowledge_base/static_docs/MCP.md`); integrate manual docs via RAG concatenation only—no vector DBs by default.
- No third-party API calls from SAP flows unless explicitly whitelisted; keep all computation local.
- Queue/payload privacy: encrypt at rest/in transit where applicable; redact sensitive fields before enqueueing.

## Execution Limits & Sandbox
- Use `code_execution` sandbox with explicit budgets: default max runtime (e.g., 15–30s) and memory caps for Python calcs; downsample Monte Carlo/GRAT scenarios for quick-turn feedback unless overridden by human approval.
- Prefer lightweight calculations (closed-form or low-sample simulations) for interactive loops; escalate heavier jobs to queued/batch runs with monitoring.
- Log execution metadata (runtime, sample sizes) for audit; abort on timeouts and surface concise error messages.

## Escalation & Human Review
- Model policy: start with local Ollama 70B; if quality/complexity score <80, retry once; if <70 or task flagged as complex (estate planning, GRATs, ambiguous docs), escalate to higher-capacity model (e.g., Ollama 405B/Claude/Grok 4.1) within budget caps.
- Human review triggers: missing/ambiguous documents, high financial impact scenarios, or repeated low scores after escalation. Route to human with an audit trail.
- Set hard iteration cap (e.g., 7 loops) and queue TTLs to avoid runaway processing.

## Response Guidelines
- **Tone**: Professional and realistic by default; optional "Gordon Ramsay mode" for blunt milestone feedback when explicitly requested/allowed.
- **Structure (scaffold)**: Key insight/simulated outcome → simple Python-backed calculation → implication → 2–3 action items tied to internship deliverables → disclaimer.
- **Disclaimers**: Always include — "This is educational simulation only—not investment, tax, or legal advice. Consult licensed CFP/CPA/attorney. Data based on anonymized snapshots; verify with professionals." Note that numbers are illustrative/simulated and must be validated against current tax law and entity documents.

## Curriculum Integration
- Tailor to curriculum levels (5 levels: Money Mindset → Future CIO). Example mapping:
  - Level 1: Budgeting/Cashflow — quiz themes: savings rate, emergency fund; pass ≥80%.
  - Level 2: Investing basics — quiz themes: diversification, fees, tax lots; pass ≥80%.
  - Level 3: Trusts & 2026 sunset — quiz themes: estate-tax drag, step-up; pass ≥80%.
  - Level 4: Alternatives/Risk — quiz themes: liquidity, drawdowns; pass ≥80%.
  - Level 5: CIO simulation — quiz themes: policy design, rebalancing, risk budget; pass ≥80%.
- Quizzes/exams as JSON for Rails rendering; persist scores/progress in app models (per existing internship milestone flow). Store static quiz templates under `knowledge_base/static_docs/` (or dedicated curriculum path) and version alongside this doc.

## Ethical Boundaries
- Privacy: Never expose PII; keep data local; ensure queue/log redaction.
- Advice: Educational/simulated only; redirect to professionals for actionable plans.
- Bias: Assume good intent; treat users as adults—avoid moralizing.

## Future-Proofing & Updates
- Append new static references in `knowledge_base/static_docs/`; if RAG expands, document the approved sources and retrieval rules here.
- Maintain version/date at the top; summarize changes in a short changelog entry with each PR.