# NextGen Wealth Advisor Project Context (Ruby-Focused Version, v1.4 - January 02, 2026)
**Note on Switch from Python**: The project initially explored a Python-based implementation using Streamlit for the dashboard, Ollama for AI, Chroma for RAG, and pure Python simulators (e.g., estate-tax, GRAT, Monte Carlo). However, it switched to Ruby on Rails 8 for the core application due to Rails' rigid MVC structure, generators, and testing conventions, which enable more reliable AI-assisted coding. Python remains for optional curriculum simulators (e.g., tax/estate tools via separate scripts), but all main features (Plaid integration, data syncing, AI bridging, UI) are now in Rails. This ensures production-grade reliability, especially for sensitive financial data handling.
This context is compiled to be sufficient for SAP (SapAgent) to generate atomic PRDs and CWA (Coder With Agents) to implement code in Rails. It focuses on Ruby-relevant sections from project documents, excluding deprecated Python-specific elements. Updates: Replaced all "Position" references with "Holding"; expanded architecture to detail Chatwoot integration (e.g., conversational handoffs via webhooks to AiFinancialAdvisor); modularized with YAML/JSON where suitable; added raw excerpt from a key PRD template; versioned for freshness; prioritized Plaid backlog items; added safety checklist subsection; added templates for PRDs and EOD reports, plus other guidance (e.g., code review template); included an optimized prompt for Grok. Last Updated: Jan 02, 2026—fetch latest from repo main via browse_page if needed. Added UI/UX section; updated vision range to $20M–$50M; added encryption key setup; expanded Chatwoot details; added Solid Queue for auto-syncs; incorporated original pricing/promise; inserted repo clone step; shifted backlog priorities; added disclaimers in PRD template; added dynamic fetch note.
## Knowledge Base Structure and Naming Conventions
**Preferred Format: Bullet-point tree view with YAML for inventory excerpts.**
**Update Type: Semi-dynamic (daily)—fetch via browse_page on https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base for latest commits. For updates, browse_page on https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/[subdir] with instructions 'Extract full Markdown/JSON content without summarization'.**
The knowledge_base is organized thematically for product strategy, Agile processes, and agent-based architecture, with no date-based naming. Key patterns:
- **Thematic Subdirs**: EOD Reports (daily progress), UI (frontend docs), Vision 2026 (strategic roadmaps), epics (high-level work groups), prds (atomic requirements), static_docs (technical refs), plus inventory.json (asset registry).
- **Naming Conventions**:
    - PRDs: Numeric prefixes like "PRD 0050" or "PRD CSV-02" for atomic features (e.g., data updates, CSV handling).
    - Epics: Alphanumeric like "AGENT-02A", "SAP Agent" for agent workflows; no strict numbering but grouped by theme (e.g., AGENT- series for AGENT-05/06).
    - Files: Descriptive, e.g., "Force Full Update Feature" for sync logic; JSON for inventories; Markdown for docs.
- **Overall Structure**: Feature-based (prds/epics for implementation), operational (EOD for tracking), strategic (Vision 2026 for roadmaps). No deep recursion visible; flat with thematic grouping.
- **Relevant KB Locations** (Raw URLs for Full Content):
    - Epics: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/epics (e.g., AGENT-02A.md for agent handoffs; SAP-Agent-Review-Method.md for RAG workflows).
    - PRDs: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/prds (e.g., PRD-0010.md for data sync; PRD PROD-TEST-01.md for production testing).
    - Static Docs: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/static_docs (e.g., for plaid-ruby usage, enrichment logic).
    - Inventory: https://raw.githubusercontent.com/ericsmith66/nextgen-plaid/main/knowledge_base/inventory.json (SAP Agent RAG, backlog strategies).
    - Vision 2026: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/Vision%202026 (foundational agents, templates).
    - EOD Reports: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/EOD%20Reports (backlog syncs, TODO integrations).
    - UI: https://github.com/ericsmith66/nextgen-plaid/tree/main/knowledge_base/UI (app structure, potentially Chatwoot views).
      **Example Raw Excerpt from PRD Template (from knowledge_base/prds/PRD-0010.md)**:
```markdown
# PRD-0010: Plaid Sandbox Link Token Generation
## Overview
Enable secure generation of Plaid link tokens for sandbox mode to initiate account linking.
## Requirements
- Functional: Use plaid-ruby gem to call /link/token/create with sandbox env.
- Non-Functional: Encrypt tokens; RLS on User model.
## Acceptance Criteria
- Token generates without errors in console.
- VCR cassette mocks API response.
```
## Multi-Agent Framework Interactions Workflow
**Preferred Format: Numbered steps with YAML for schema examples.**
**Update Type: Static—core workflow unchanged unless epic updates.**
The project uses a multi-agent framework (e.g., SAP Agent with RAG from inventory.json) for autonomous workflows, integrated via Rails services and Ollama. Key interactions:
1. Trigger: Human/SAP enqueues tasks via Solid Queue (recurring) or Sidekiq (async).
2. Handoff: Context schema (JSON blobs from FinancialSnapshotJob) passed between agents; e.g., PRD Agent outputs to knowledge_base/prds, Coder Agent reads and plans (app/agents/engine.rb).
3. Interactions: Tool-calling (read-only v1: grep/tree/git log/diff/rubocop); feedback loops (resolution via 0020 PRD); self-debug (retries/escalation in 0040).
4. Persistence: AiWorkflowRun model (minimal: correlation_id, jsonb context/log) or file-based (run.json/events.ndjson).
5. Safety: Dry-run (ENV AI_TOOLS_EXECUTE=false), hybrid commits (AI stages local, human push/merge), sandbox subprocesses.
6. Integration: Chatwoot for user-facing chat (e.g., query handoffs to agents via webhooks; route to AiFinancialAdvisor for Ollama processing); deprecate queue-based if ai-agents succeeds.
   **Example Context Schema (YAML)**:
```yaml
correlation_id: uuid-1234
ball_with: cwa_agent
state: planning
turns_count: 3
feedback_history:
  - {turn: 1, feedback: "Add tests"}
artifacts:
  - {type: json, path: financial_snapshot.json}
```
**KB Refs**: Epics like AGENT-05/06 in knowledge_base/epics for handoffs; inventory.json for RAG/state/escalation.
## Financial Family Office / Next-Gen Internship Platform – Full Conversation Summary (December 2024 – December 2025)
**Preferred Format: Numbered sections with bullet points.**
**Update Type: Static—vision and components fixed.**
1. **Core Vision**
    - Build a “virtual family office” for families with $20M–$50M net worth who are too small for a real family office.
    - Primary product: a paid, structured 12–24 month “internship” for 18–30-year-old heirs that teaches real-world wealth management.
    - Parents literally pay the kids a real paycheck (e.g., $60k–$120k/year) for completing milestones — turns learning into a job, not homework.
    - End goal: kids become competent stewards of family wealth (investing, taxes, trusts, philanthropy, risk management, succession).
2. **Technical Architecture (Current Decision)**
    - Language / Framework: Ruby on Rails 8.0.4 (upgraded for Solid Queue defaults, enhanced MVC/testing).
    - Database: Single PostgreSQL instance with Row-Level Security (RLS) for multi-user isolation (no per-user DBs).
    - Sensitive data: column-level encryption via attr_encrypted (especially Plaid access_tokens; generate ENCRYPTION_KEY with `openssl rand -hex 32` in .env).
    - Authentication: Devise (battle-tested, built-in tests).
    - Plaid integration: official plaid-ruby gem (focus on JPMC, Schwab, Amex, Stellar; products: investments, transactions, liabilities, enrichment—use endorsed endpoints like /investments/holdings/get, /transactions/enrich).
    - AI Layer: Local Llama 3.1 (70B or 405B) running on-premises → zero data leakage.
    - AI ↔ Rails bridge: AiFinancialAdvisor service object (app/services) that calls a thin local HTTP wrapper (future-proof for swapping to Python later).
    - Background Jobs: Solid Queue (Rails 8 default for recurring, e.g., daily syncs at 3am), Sidekiq (for async tasks like real-time enrichments).
    - Chat/Support: Chatwoot integration for conversational UI (e.g., query handling via webhooks to agents; supports handoffs to Ollama for responses, with audit trails; integrate in UI for conversational feedback).
    - Mocking / Testing: WebMock + VCR + canned Plaid sandbox responses; mock AI endpoint in test env.
3. **Plaid Data Model (agreed schema)**
   **Preferred Format: YAML for schema.**
   **Update Type: Semi-dynamic—check repo for migrations via browse_page on db/schema.rb.**
   ```yaml
   User: # Devise
     associations: has_many :plaid_items
   PlaidItem:
     associations: belongs_to :user
     fields: {access_token: encrypted, item_id: string, institution_id: string}
   Account:
     associations: belongs_to :plaid_item
     fields: {account_id: string, mask: string, name: string, type: string, subtype: string, balances: jsonb}
   Transaction:
     associations: belongs_to :account
     fields: {transaction_id: string, amount: decimal, date: date, description: string, enriched_category: string, enriched_merchant_name: string, enriched_location: string} # Example enrichment
   Holding:
     associations: belongs_to :account
     fields: {security_id: string, symbol: string, name: string, type: string, quantity: decimal, cost_basis: decimal, market_value: decimal, price_as_of: date}
   ```
4. **AI / RAG Strategy (Rails-native, no Python needed)**
    - Daily cron job → FinancialSnapshotJob creates a sanitized JSON blob per user (totals, allocations, overdue tasks, risk scores, etc.) via Solid Queue (use for daily 3 AM auto-syncs per README).
    - This JSON + a static “family constitution” doc + 0_AI_THINKING_CONTEXT.md = the entire RAG context.
    - Prompt always starts with the relevant chunk of that context → 95% of classic RAG value with zero vector DB complexity.
    - Optional future upgrade: PGVector inside the same Postgres if we ever want real semantic search.
5. **Key Non-Technical Program Components**
    - Curriculum areas: Roth IRA / brokerage setup, DAF & philanthropy strategy, insurance review, debt prioritization, budgeting, estate planning basics, tax optimization, generational transfer mechanics, trust interplay & step-up basis, succession scenarios.
    - Incentive design: Paycheck tied to milestones + modest bonus tied to risk-adjusted performance vs agreed IPS (NOT raw returns → discourages gambling).
    - Tone options: “Gordon Ramsay mode” (blunt, high standards) vs normal professional tone.
6. **Business & Risk Mitigation**
    - Framing: “You are buying your child a paid professional internship in wealth management”.
    - Legal protection: 1. Massive disclaimers (“not investment advice”); 2. Partner with licensed fiduciary (human CFP/CPA) who reviews and signs off on any actionable plan; 3. Full audit trail of every AI input/output.
    - Competitive reality: JPMorgan, UBS, etc. do NOT offer this for $25M families → genuine white space; Banks are extremely slow to build anything this opinionated and hands-on.
    - Pricing & Delivery Options: Software-Only (Encrypted installer Mac/Win/Linux: $9,900 one-time + $2,900 annual, 92% margin); Appliance Lite (Bootable Thunderbolt SSD: $12,900 one-time + $2,900 annual, 88% margin); Appliance Pro (Dedicated Mac mini/AMD box: $17,900 one-time + $4,500 annual, 78% margin); + Internship Edition add-on (Payroll/Gusto/DAF kit + dashboard: +$7,000 one-time + $2,000 annual, 95% margin).
    - Core Promise: “All family data stays inside a closed system you fully control. Never touches the cloud unless you explicitly allow it.”
7. **Immediate Next Steps (the “get it running” plan)**
    1. Clone repo, bundle install, db:create/migrate, rails s.
    1. New Rails 8 app.
    2. Add gems: plaid-ruby, devise, attr_encrypted, sidekiq, webmock, vcr, solid_queue (if not default).
    3. Devise → User model + RLS-ready policies.
    4. PlaidController with link_token & exchange_public_token.
    5. PlaidItem model (encrypted token) + basic sync service.
    6. Sandbox testing → real bank link for your own accounts.
    7. Daily FinancialSnapshotJob → JSON blob (via Solid Queue).
    8. AiFinancialAdvisor service that hits local Llama wrapper.
    9. 0_AI_THINKING_CONTEXT.md + PRODUCT_REQUIREMENTS.md in repo root (this becomes the bible for every coding agent).
## Future Task: “Offshore Mode” – Fully Autonomous Overnight Agent Pipeline
**Preferred Format: Bullet points with checkboxes for triggers/AC.**
**Update Type: Static—parked until validation.**
**Status**: Parked – Do NOT start until dual-agent workflow is 100% validated.
- **Goal**: Turn the proven PRD Agent + Coder Agent pair into a headless, test-gated, overnight “offshore team” that processes an entire queue of atomic PRDs while you sleep – using only the Mac Studio M3 Ultra you already own.
- **Trigger Condition**: Proven reliability of prd_agent.rb and coder_agent.rb for 10+ features with green commits.
- **Acceptance Criteria**: Enqueue and process PRDs autonomously; Model selection: 70B for light tasks, 405B for code; Email reports on completion.
- **Planned Tech**: Solid Queue (Rails 8 default), ollama-ai gem, whenever gem, Action Mailer.
## PROJECT SUMMARY – December 5, 2025
**Preferred Format: Bullet points.**
**Update Type: Static—historical summary.**
“Hello Agents” → Fully Autonomous Local AI Rails Developer
- Autonomous agents: prd_agent.rb (generates PRDs), coder_agent.rb (implements code, tests, commits if green).
- Local on Mac Studio via Ollama (llama3.1:70b).
- Zero cloud/data leakage.
- File structure for agents in Rails app.
- Usage: ./prd_agent.rb for PRD, ./coder_agent.rb for implementation.
## EOD Report: January 02, 2026 (Ruby-Relevant Excerpts)
**Preferred Format: Bullet points under subsections.**
**Update Type: Dynamic—fetch latest EOD via browse_page on knowledge_base/EOD%20Reports.**
### Accomplishments
- Refined Agent epics/PRDs for Ruby agents (e.g., ai-agents gem integration, CWA as registered agent).
- Updated naming to numeric PRDs (0010–0050).
- Incorporated safety (read-only tools, dry-run ENV, hybrid commits: AI stages, human push).
- Allowed minimal DB persistence (AiWorkflowRun model).
- Testing: WebMock preferred, 80% coverage, spikes for multi-agent chains.
### Decisions Made
- Ruby focus: Rails 8 for core, gem framework for agents (state/escalation).
- Models: Default llama3.1:70b, overrides for 8b/Grok/Claude (adapt Grok's OpenAI-like API).
- Safety: Read-only v1 tools (no rm/write), sandbox, dry-run default.
- Persistence: File-based fallback (run.json/events.ndjson) or minimal model.
- Sequencing: Safety-first (spike, feedback, planning, tools, UI).
- Deprecate queue-based CWA in favor of ai-agents path.
### Brainstorming Summary
- Gem: ai-agents for multi-agent (Junie/CWA), handoffs via context schema.
- Safety: Allowlist, no destructive cmds, hybrid git (AI commit local, human push).
- Persistence schema: correlation_id, ball_with, state, etc.
- Testing: WebMock for determinism, green 2-agent chains.
- Cross-Epic: Agent-06 depends on Agent-05 0040 (tools baseline), 0030 (planning schema); MCP tools limited to read-only (grep/tree/git log/diff/rubocop); self-debug proposes fixes, executes approved only.
- Future: Defer RuntimeTool, auto-correct, push/merge until safety proven; questions on folding MCP (0030) into Agent-05 post-0040.
### Backlog Table (Plaid/Agent Focus, Prioritized)
**Preferred Format: Markdown table.**
**Update Type: Semi-dynamic (daily)—sync with knowledge_base/inventory.json or EOD reports via browse_page.**
| Priority | Feature/Epic | Status | Dependencies | KB Location |
|----------|--------------|--------|--------------|-------------|
| 1 | Setup New Rails 8 App with Core Gems (plaid-ruby, devise, attr_encrypted, sidekiq, webmock, vcr, solid_queue) | Todo | None | knowledge_base/static_docs/rails_setup.md |
| 2 | Implement Devise Authentication with User Model and RLS Policies | Todo | #1 | knowledge_base/prds/PRD UC-14.md |
| 3 | Create Plaid Sandbox Link Token Generation | Todo | #2 | knowledge_base/prds/PRD CSV-02.md |
| 4 | Implement Public Token Exchange and Encrypted Storage in PlaidItem Model | Todo | #3 | knowledge_base/prds/PRD CSV-03.md |
| 5 | Build Basic Sync Service for Accounts, Transactions, and Holdings | Todo | #4 | knowledge_base/prds/PRD CSV-05.md |
| 6 | Add Sandbox Testing and Real Bank Link Support | Todo | #5 | knowledge_base/prds/PRD CSV-06.md |
| 7 | Implement Daily FinancialSnapshotJob for JSON Blobs (Solid Queue) | Todo | #6 | knowledge_base/epics/full-fetch.md |
| 8 | Create AiFinancialAdvisor Service for Local Ollama Integration | Todo | #7 | knowledge_base/epics/agents.md |
| 9 | Add Core Context Files (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md) | Todo | #8 | knowledge_base/static_docs/0_AI_THINKING_CONTEXT.md |
| 10 | Implement Investments/Holdings/Get Endpoint Sync | Todo | #9 | knowledge_base/prds/PRD PROD-TEST-01.md |
| 11 | Implement Transactions/Get Endpoint Sync | Todo | #10 | knowledge_base/epics/Investment-Enrichment.md |
| 12 | Implement Liabilities/Get Endpoint Sync | Todo | #11 | knowledge_base/epics/Local-Transaction-Enrichment.md |
| 13 | Implement Enrichment Features (e.g., Categorization) | Todo | #12 | knowledge_base/static_docs/enrichment.md |
| 14 | Setup CSV Import/Export for Data Mocking/Anonymization | Todo | #13 | knowledge_base/prds/PRD-Backlog.md |
| 15 | Agent-05 Epic: Multi-Agent Basics (Persona Setup, Feedback, Planning, Tools, UI) | Todo | None | knowledge_base/epics/AGENT-05.md (spike in 0010) |
| 16 | Agent-05 PRD 0010: Persona Setup & Console Handoffs | Todo | #15 | knowledge_base/prds/PRD-0010.md |
| 17 | Agent-05 PRD 0020: Feedback & Resolution Loop | Todo | #16 | knowledge_base/prds/PRD-0020.md |
| 18 | Agent-05 PRD 0030: Planning Phase for CWA | Todo | #17 | knowledge_base/prds/PRD-0030.md |
| 19 | Agent-05 PRD 0040: Impl/Test/Commit with CWA | Todo | #18 | knowledge_base/prds/PRD-0040.md |
| 20 | Agent-05 PRD 0050: UI Layer & Tracking | Todo | #19 | knowledge_base/prds/PRD-0050.md |
| 21 | Agent-06 Epic: Advanced CWA (Persona/Toolkit, Logs, MCP Tools, Self-Debug, Workflow Handoff) | Todo | Agent-05 | knowledge_base/epics/AGENT-06.md |
| 22 | Agent-06 PRD 0010: CWA Persona & Safe Shell Toolkit | Todo | #21 | knowledge_base/prds/PRD-0010.md |
| 23 | Agent-06 PRD 0020: Task Log Template & Persistence | Todo | #22 | knowledge_base/prds/PRD-0020.md |
| 24 | Agent-06 PRD 0030: MCP-Like Tools Integration | Todo | #23 | knowledge_base/prds/PRD-0030.md |
| 25 | Agent-06 PRD 0040: Self-Debug Loop | Todo | #24 | knowledge_base/prds/PRD-0040.md |
| 26 | Agent-06 PRD 0050: Workflow Integration & Hybrid Handoff | Todo | #25 | knowledge_base/prds/PRD-0050.md |
| 27 | AGENT-4.5 PRD-0010E: Bare Metal Streaming Chat | Todo | Agent-06 | knowledge_base/prds/PRD-0010E.md |
## Coding Standards
**Preferred Format: Bullet points with code examples.**
**Update Type: Static—best practices fixed, unless repo .rubocop.yml updates.**
Adhere to Rails conventions for reliable implementation by Junie Pro (default LLM: Claude Sonnet 4.5; consider Grok 4.1 for complex agent logic if needed):
- **MVC Patterns**: Models for data logic (e.g., validations, scopes); Controllers for actions (e.g., thin, use services for business logic); Views with ViewComponent + Tailwind/DaisyUI for reusable UI.
- **Testing**: 80% coverage; RSpec for units (models/services), integration (controllers/jobs); WebMock for API stubs, VCR for live cassettes; e.g., `it "syncs holdings" { expect { SyncHoldingsJob.perform_now }.to change(Holding, :count) }`.
- **Gems/Integrations**: Use plaid-ruby for API calls (sandbox first); attr_encrypted for tokens; Solid Queue/Sidekiq for jobs (e.g., `class SyncHoldingsJob < ApplicationJob; queue_as :default`).
- **Branching/Commits**: Pull from master; feature branches (e.g., `git checkout -b feature/prd-0010`); commit only green code (run `rspec` before).
- **Style**: RuboCop enforced (.rubocop.yml); DRY code; comments for complex logic.
- **Procfile.dev for local dev (rails s + sidekiq)** and **TODO.md integration for open items** from repo.
- **Safety Checklist**:
    - Encrypt all sensitive data.
    - Dry-run for tools (ENV check).
    - No destructive ops in v1.
    - Human review for merges.
    - Disclaimers in UI/Chatwoot responses.
## UI/UX Guidelines
**Preferred Format: Bullet points.**
**Update Type: Static—defer until post-core Plaid stability.**
When relevant (post-core Plaid), specify simple, professional designs for young adults (22-30)—no "kid-friendly" elements. Use Tailwind CSS + DaisyUI with ViewComponent for maintainable, elegant components; mock data for previews; optional Capybara tests. Focus on privacy (e.g., local network only); include disclaimers ("Educational simulation only, consult CFP/CPA"). Reference knowledge_base/UI for wireframes/app structure.
## Available Models for Use
**Preferred Format: Bullet points.**
**Update Type: Semi-dynamic—check SmartProxy via browse_page on /v1/models if overrides change.**
- Default: llama3.1:70b (via Ollama, fast for light tasks/PRDs).
- Optional: llama3.1:405b (accurate for code implementation).
- Overrides: llama3.1:8b (lightweight), Grok (modified OpenAI API, via SmartProxy), Claude (deferred until SmartProxy implements, marked ⏳; use /v1/models for truth).
- For agents: 70B for PRD/light, 405B for coding; adapt for multi-agent chains in spikes.
## Template for PRDs
**Preferred Format: Markdown skeleton.**
**Update Type: Static—use for all PRD generation; reference knowledge_base/prds/prds-junie-log/junie-log-requirement.md for logging specifics.**
Use this self-contained template for atomic PRDs (<1500 words). Tie to vision; specify LLM (default Claude Sonnet 4.5; e.g., "Use Grok 4.1 for agent logic"). Include human steps if needed (e.g., infra setup). End with: "Junie: Review this PRD, ask questions, build a plan, then implement on feature branch—commit only if green."
```markdown
# PRD-[Numeric ID]: [Feature Title]
## Overview
[1-2 sentences linking to core vision, e.g., "Enables secure Plaid token exchange to support family wealth data syncing without cloud exposure."]
## Requirements
- **Functional**: [Bullet points, e.g., "Call /item/public_token/exchange via plaid-ruby; store encrypted access_token in PlaidItem."]
- **Non-Functional**: [e.g., "Use attr_encrypted; RLS for user isolation; sandbox mode first."]
- **Rails Guidance**: [e.g., "Model: PlaidItem with migration; Service: PlaidSyncService; Controller: PlaidController."]
- **Logging**: [Per junie-log-requirement.md: Audit all API calls/errors; use Rails.logger with structured JSON.]
- Include disclaimers in UI/output (e.g., 'Not investment advice').
## Architectural Context
[Rails MVC focus; reference schema; local Ollama via AiFinancialAdvisor; RAG via JSON snapshots.]
## Acceptance Criteria
- [5-8 verifiable bullets, e.g., "Token exchanges successfully in Rails console; VCR mocks API response."]
## Test Cases
- [Examples: "RSpec for PlaidItem model: expect(plaid_item.access_token).to be_encrypted."]
## Workflow for Junie
- Pull from master; branch: feature/prd-[ID].
- Ask questions/build plan before code.
- Implement, test (rspec), commit green.
```
## Template for EOD Reports
**Preferred Format: Markdown with sections and table.**
**Update Type: Static—use at conversation end when requested.**
Summarize daily progress; include decisions, brainstorming, backlog table (prioritized Plaid first), and next context. Keep <800 words.
```markdown
### EOD Report: [Date]
#### Accomplishments
- [Bullets: e.g., "Generated PRD-0010; reviewed code for PRD-0005."]
#### Decisions Made
- [Bullets: e.g., "Switched to Grok 4.1 for agent spikes."]
#### Brainstorming Summary
- [Bullets: e.g., "Explored Chatwoot handoffs; deferred vector DB."]
#### Backlog Table
| Priority | Feature | Status | Dependencies |
|----------|---------|--------|--------------|
| [Rows...]
#### Context for Next Conversation
- [Bullets: Open items, questions, e.g., "Validate spike with Ollama/Grok."]
```
## Other Guidance Templates
**Preferred Format: Markdown skeletons.**
**Update Type: Static—use as needed for reviews/plans.**
### Code Review Template
Post-implementation; fetch via browse_page; summarize strengths/weaknesses/issues/recommendations.
```markdown
#### Post-Review Summary for [PRD-ID/Commit]
- **Strengths**: [e.g., "Clean MVC; 85% test coverage."]
- **Weaknesses**: [e.g., "Missing VCR for Plaid calls."]
- **Critical Issues**: [e.g., "Unencrypted token—fix immediately."]
- **Recommendations**: [e.g., "Add WebMock stubs; retest."]
```
### Junie Implementation Plan Template
For Junie: Before coding, outline steps.
```markdown
#### Plan for PRD-[ID]
- Step 1: [e.g., "Generate migration for PlaidItem."]
- Questions: [e.g., "Confirm encryption key env var?"]
- Estimated Time: [e.g., "2 hours."]
```
## Optimized Prompt for Grok
**Preferred Format: Plain text block.**
**Update Type: Static—use for self-referencing or chaining.**
"You are Grok 4, assisting in nextgen-plaid development. Use provided RAG context fully; generate atomic PRDs via template when asked; review code via browse_page tool (start with repo overview, then raw files/diffs). Default to Claude Sonnet 4.5 for Junie; suggest Grok 4.1/Gemini for complex/creative tasks. Challenge ideas; prioritize Plaid stability (sandbox/live). Response: Concise, action-oriented; end with next steps/questions. Tools: Use for fetches (e.g., browse_page on raw URLs); no assumptions on code."