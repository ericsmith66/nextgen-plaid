---
title: Refined Approach to SAP Agent Context Provision
author: Grok 4 (as Senior Product Manager & Architect)
version: 1.0
status: DRAFT
date: December 27, 2025
---

## Vision (One Sentence)
A robust, automated, tiered RAG system for the SAP agent that delivers precise, fresh context for generating atomic PRDs, ensuring alignment with the nextgen-plaid vision of private financial data sync for HNW families without hallucinations or manual overhead.

## Core Purpose
The SAP (Senior Architect and Product Manager) agent is central to scaling feature development in nextgen-plaid, generating atomic PRDs for Plaid API implementations (e.g., /investments/holdings/get for JPMC/Schwab) while adhering to Rails MVC, local Ollama AI, and privacy mandates. Effective context provision mitigates risks like outdated schema references or vision misalignment, enabling reliable outputs for Junie to implement. This refined approach builds on simple RAG (JSON snapshots + static doc concat) from the MCP, incorporating Junie's tiered organization with automation to handle project evolution post-Plaid core stability.

## Key Principles
- **Completeness Without Overload**: Provide only query-relevant context to avoid prompt token bloat and LLM confusion. Use executive summaries for large docs; multi-stage retrieval (intent detection → tier selection → synthesis) for efficiency.
- **Automation for Freshness**: Eliminate manual updates via Rails-native tools (rake tasks, Sidekiq jobs, post-merge hooks) to keep context current with repo changes, ensuring SAP always references the latest schema or epics.
- **Isolation & Security**: SAP operates read-only; context pulls are sandboxed and audited. SmartProxy isolates external Grok escalations/tools (e.g., web_search for market research) with per-session ENV vars to prevent cross-agent state leaks.
- **Validation & Iteration**: Embed self-checks in SAP prompts (e.g., "Cross-verify PRD against Tier 1 vision"); log context usage for post-generation audits. Pilot with 3-5 PRD generations to measure accuracy before full integration.
- **Edge Case Handling**: Auto-refresh stale data based on mod timestamps; resolve conflicts by prioritizing tiers (Foundation > Structure > History > Dynamic); cap concat at 4K tokens with truncation warnings.

## Tiered Context Organization
Refined from Junie's suggestions, this structure categorizes knowledge for targeted retrieval, stored in knowledge_base/ for git versioning and easy RAG indexing.

| Tier | Content Description | Source Locations | Refresh Mechanism | Retrieval Triggers |
|------|---------------------|------------------|-------------------|--------------------|
| **1: Foundation** | Immutable vision/rules: vision_2026.md, junie-log-requirement.md, PRODUCT_REQUIREMENTS.md, coding standards (MVC guidelines, privacy disclaimers). | knowledge_base/static_docs/ | Manual via PR merge; versioned updates. | Always included as prompt prefix for every SAP query to enforce alignment. |
| **2: Structure** | Application skeleton: Minified db/schema.rb (tables/relations), rails routes output (endpoints), directory tree (app/ subdirs), tech stack summary (Gemfile gems like plaid-ruby, attr_encrypted). | knowledge_base/structure/ (auto-generated JSON files). | Rake task on repo changes (e.g., post-migration); triggered by GitHub webhook on merge. | Keywords like "model", "controller", "endpoint", or architectural PRDs (e.g., new sync service). |
| **3: History** | Project evolution: Indexed epics/PRDs (titles, paths, summaries), decision logs (e.g., Rails over Python rationale). | knowledge_base/epics/, prds/ (metadata in inventory.json). | Rake scan on new file addition; auto-index mod dates. | PRD generation queries to check for duplicates or build on priors (e.g., extend holdings sync). |
| **4: Dynamic** | Real-time state: Extended FinancialSnapshotJob JSON (project-level: open backlog items, recent agent_logs/ summaries), Solid Queue status (pending tasks). | DB snapshots table (versioned with created_at/category); agent_logs/ parsed summaries. | Just-in-time Sidekiq job on query; 7-day retention policy for snapshots. | Time-sensitive queries (e.g., "prioritize next Plaid feature") or debugging (e.g., recent errors). |

## Maintenance Strategies
To ensure zero manual overhead while keeping context accurate:
- **Rake Suite (lib/tasks/sap_context.rake)**: Core automation hub.
    - `sap:context:discover`: Executes rails db:schema:dump minification, rails routes > output, tree -L 3 > tree.txt, and Gemfile parsing; outputs to structure/ JSONs.
    - `sap:context:inventory`: Scans epics/prds dirs recursively; builds inventory.json with paths, titles (from frontmatter), and last_mod.
    - `sap:context:refresh_check`: Compares .sap_index.json timestamps against actual files; enqueues updates for stale entries via Solid Queue.
- **Hooks & Triggers**: Integrate with existing webhook controller (#0030) for post-merge events—e.g., on main merge, rake discover/inventory runs automatically. For dynamic tier, Sidekiq cron job summarizes logs hourly.
- **Index Management**: .sap_index.json as central metadata (JSON object with tier/file entries, including last_mod and hash for integrity). If stale (>24h or hash mismatch), auto-refresh before SAP query.
- **Retention & Cleanup**: DB snapshots use simple SQL policy (delete >7 days); rake includes prune option for old JSONs.

## Retrieval & Integration Logic
- **In SmartProxy Service**: Acts as the gateway—parses query intent via simple regex/keywords (e.g., if "database" in query, inject Tier 2). Multi-stage flow:
    1. Intent classification: Categorize query (e.g., "PRD gen" → Tiers 1+3; "debug sync" → Tiers 2+4).
    2. Tier pull: Concat relevant files/summaries (exec summary first for large items, e.g., 10-line PRD distillate).
    3. Prompt synthesis: Prefix with tiers + user query; cap at token limit with prioritization (drop lower tiers if needed).
- **Ollama/Grok Escalation**: Local Ollama handles 90% (70B for fast, 405B for deep); escalate via Faraday-wrapped calls only for external needs (e.g., web_search for Plaid API updates), isolated by session ID (SecureRandom.uuid) and agent-specific ENV.
- **Audit Trail**: Log full context pull in sap.log (e.g., "Query: holdings PRD → Pulled: Tier1 vision.md, Tier2 schema.json, Tier3 sync-epic.md").

## Benefits & Risks
- **Benefits**: Enhances SAP accuracy (e.g., schema-aware PRDs reduce Junie rework); scales to full curriculum (e.g., tie tax sims to Plaid data); auditable for compliance (logs trace decisions to vision).
- **Risks & Mitigations**:
    - Overload: Enforce token caps; pilot with simple queries.
    - Staleness: Auto-hooks ensure <1h lag; fallback to manual rake if webhook fails.
    - Complexity: Start with concat-only; add multi-stage post-pilot validation (3-5 green PRDs).
    - Privacy: Read-only pulls; no PII in summaries (sanitize snapshots).

## Implementation Roadmap
- Atomic PRDs: As outlined (SAP-EXT-01 to -05); integrate post-Plaid highs.
- Dependencies: Solid Queue (AGENT-01), webhook stability (#0030).
- Metrics: PRD alignment score (manual review: 90%+ vision match); refresh latency (<5s).

## Related Epics & Dependencies
- Epics: AGENT-02 (SAP base), RAG-01 (base JSON snapshots).
- Dependencies: Plaid core (#0010-#0060 for schema maturity); SmartProxy extensions for isolation.

Next: Add this to knowledge_base/vision/ as sap_context.md? Or generate PRD for SAP-EXT-01 implementation?