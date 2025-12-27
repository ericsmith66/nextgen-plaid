# Master Control Protocol (MCP) - Project Vision 2026

## One Sentence Vision
A private financial data sync and AI-driven advisory system for HNW families ($20-50M), ensuring privacy via local-only AI (Ollama) and automated, vision-aligned feature generation (SAP agent).

## Core Pillars
1. **Private Data Sync**: Full Plaid integration for JPMC, Schwab, Amex, and Stellar. Covers investments, transactions, liabilities, and data enrichment.
2. **Local AI first**: Primary execution via local Ollama (70B/405B) via `AiFinancialAdvisor`. External escalation to Grok only for speed or web research, isolated via `SmartProxy`.
3. **Automated Excellence**: SAP (Senior Architect and Product Manager) agent generates atomic PRDs and manages the project backlog to accelerate development while enforcing Rails MVC and privacy mandates.
4. **Hallucination Mitigation**: Rigid structural enforcement (ERB templates), pre-storage validation, and Python-based simulations for complex financial logic.

## Key Principles
- **Foundation over Overload**: Tiered context retrieval (Vision > Structure > History > Dynamic).
- **Security & Privacy**: Read-only context pulls; anonymized snapshots; per-session ENV isolation in `SmartProxy`.
- **YAGNI & Atomic**: Focus on small, verifiable PRDs; prune stale backlog items (>30 days).

## Tiered Context (SSOT)
- **Tier 1 (Foundation)**: This MCP.md, `junie-log-requirement.md`, coding standards. Always included in SAP prompts.
- **Tier 2 (Structure)**: Minified schema, routes, and directory tree. Auto-generated via Rake.
- **Tier 3 (History)**: Epic/PRD inventory and decision logs.
- **Tier 4 (Dynamic)**: Real-time state, backlog.json, and agent log summaries.

## Risks & Mitigations
- **Privacy Leak**: Local-only processing; sanitization of all external payloads.
- **Hallucination**: Structural enforcement via ERB; mandatory 5-8 AC bullets; self-correction retries.
- **Token Bloat**: Strict 4K token caps for context; executive summaries for large documents.

---
*Last Updated: 2025-12-27*
