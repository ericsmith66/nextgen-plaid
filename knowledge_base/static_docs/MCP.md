Vision: Private Financial Data Sync
# Master Context Plan (MCP) - NextGen Plaid

## Overview
NextGen Plaid is a secure, local-first Ruby on Rails 7+ application that synchronizes financial data from key institutions (JPMC, Schwab, Amex, Stellar) using Plaid's investments, transactions, liabilities, and enrichment products. It serves as the data foundation for a virtual family office AI tutor targeting U.S. families with $20M–$50M in assets, educating heirs (ages 18–30) on wealth stewardship through a structured, paid internship program. The goal is to prevent "shirtsleeves to shirtsleeves" by combining real-time financial insights with CFP®-level curriculum, all within a closed system emphasizing privacy and local computation.

## Core Vision
- **Target Users**: Parents (40–60) and heirs (18–30) in ~60,000 U.S. households with $20M–$50M liquid assets, currently advised by firms like Merrill PWM or independent RIAs.
- **Key Problem Solved**: Estate-tax changes (e.g., 2026 sunset) and generational wealth loss; heirs lack practical skills in investing, taxes, trusts, philanthropy, and governance.
- **Unique Value**: A "paid internship" where heirs earn a deductible salary ($60k–$120k/year) for milestones, using anonymized family data. Data stays local; AI provides personalized tutoring via Ollama without cloud leakage.
- **Business Model**: Tiered pricing ($9,900–$17,900 one-time + annual renewals) with high margins (78–95%); Year-1 goal: 100 units for ~$1.95M revenue.

## Technical Architecture
- **Framework**: Ruby on Rails 7+ with rigid MVC for reliable AI-assisted coding; PostgreSQL with Row-Level Security (RLS) for multi-user isolation.
- **Data Handling**: Plaid-ruby gem for API integration (sandbox first); models include User (Devise), PlaidItem (encrypted tokens), Account, Transaction, Position. Support CSV import/export for mocking/anonymization; manual enrichment via secure uploads for tax documents (e.g., 1099s, K-1s), income forecasts (e.g., spreadsheets), trust documents, contracts, and similar files—stored encrypted and indexed for RAG/AI access.
- **AI Integration**: Local Llama 3.1 (70B/405B) via AiFinancialAdvisor service; RAG via daily JSON snapshots (FinancialSnapshotJob) + static docs (e.g., 0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md)—no vector DBs.
- **Privacy & Security**: Column-level encryption (attr_encrypted); local-only execution; disclaimers for "educational simulation only"; human CFP/CPA review hooks.
- **Curriculum Integration**: 5 levels (Money Mindset to Future CIO); Python simulators for tax/estate calcs; internship kit (Gusto payroll, Roth IRA tracking); AI analysis of manually enriched docs (e.g., tax form parsing for simulations).

## Agents and Roles
The project incorporates autonomous AI agents to streamline development and operations, all running locally via Ollama. These agents are deferred until core Plaid sync is complete, then adapted from the "hello-agents" framework for self-improving workflows.

| Agent Name | Role | Key Responsibilities | Implementation Notes |
|------------|------|----------------------|----------------------|
| **SAP Agent** (Self-Aware Programmer Agent) | Oversees project evolution and query handling | Manages backlog, RAG context, tool integration (e.g., code_execution, browse_page); routes queries to sub-agents; ensures green commits and privacy. | Core in `sap_agent.rb`; uses epics like AGENT-02A/B/C for tools, RAG, and reviews; integrates with AiFinancialAdvisor for financial insights. |
| **PRD Agent** | Generates atomic Product Requirements Documents | Takes natural language inputs and produces self-contained PRDs with Rails-specific guidance, acceptance criteria, and tests. | In `prd_agent.rb`; outputs to `knowledge_base/prds/`; focuses on atomic scopes tied to MCP vision. |
| **Coder Agent** | Implements code from PRDs | Reads PRDs, generates MVC files (models, migrations, controllers, tests), runs migrations/tests, and commits only if green. | In `coder_agent.rb`; uses feature branches; modular with classes like Engine, FileWriter, TestRunner; self-improving via 70B/405B models. |
| **Conductor Agent** | Orchestrates multi-agent workflows | Coordinates between agents (e.g., PRD → Coder); handles overnight queues for autonomous processing. | High-level vision in `knowledge_base/Vision 2026/`; parked until dual-agent validation; uses Solid Queue for background jobs. |
| **CWA (Curriculum Writing Agent)** | Develops educational content | Generates CFP®-level curriculum modules (e.g., tax simulations, philanthropy strategies) integrated with Python simulators; creates end-user exams/quizzes to assess mastery, with scoring tied to internship milestones. | Vision in `knowledge_base/Vision 2026/`; ties to internship edition; outputs to dashboards and daily briefings; quizzes stored as JSON for Rails rendering. |
| **AiFinancialAdvisor** | Provides real-time tutoring and analysis | Grounds responses in user data snapshots; offers personalized advice on wealth topics without hallucinations (via Python calcs). | Service object in `app/services/`; thin wrapper to local Ollama; used by tutors/internship features. |
| **Tax Advisor Agent** | Delivers simulated tax guidance and calculations | Runs simulations for strategies like deductions, distributions, and optimizations (e.g., S-corp salaries, trust income, 401(k) contributions); explains IRS rules for family offices and trusts; integrates with curriculum on tax efficiency. | Python scripts for calcs (e.g., estate-tax sunset, FICA minimization) via Rails service; Ollama for explanations; always includes disclaimers and redirects to CPA. |
| **Legal Tutor Agent** | Offers educational legal insights | Explains structures like trusts, LLCs/S-corps, fiduciary duties, and compliance (e.g., self-dealing avoidance, beneficiary disclosures); supports curriculum on governance and succession. | RAG on static legal docs; Ollama for breakdowns; mandatory disclaimers emphasizing non-professional advice and need for attorney consultation. |

## Risks & Mitigations
- **Privacy**: Three Plaid modes (Mock/Anonymized/Full); no cloud unless opted-in.
- **Hallucination**: Pure Python calcs for critical sims; AI grounded in snapshots.
- **Regulatory**: Partner with licensed fiduciaries; audit trails for AI outputs.
- **Development**: Atomic PRDs; feature branches; green commits only.

## Roadmap Priorities
1. Core Plaid Sync: OAuth, holdings/transactions/liabilities refresh.
2. Data Enrichment: Local processing for insights; manual uploads for tax/income/trust/contract docs.
3. AI Tutoring: RAG-enhanced responses.
4. Internship Features: Payroll dashboards, milestone tracking.
5. Deployment: Local appliance options (Mac mini/SSD).

## Future Evolution (2027+)
Post-2026, after validating the primary heir-focused use case (e.g., 500+ units sold, stable Plaid sync, proven internship outcomes), expand to broaden the market by addressing HNW individuals in life transitions such as divorce, death of a spouse, or spousal incapacitation. This phased approach ensures core stability before scaling:
- **2027 Phase**: Add modular curriculum extensions for transitions (e.g., asset division simulations, QDRO overviews, beneficiary updates via Python calcs); introduce user profiles for "transition mode" with tailored RAG contexts (e.g., legal/tax docs on spousal incapacity).
- **2028+ Phase**: Integrate advanced Plaid enrichments (e.g., liability scenarios for divorce); enhance agents (e.g., Tax Advisor for step-up basis in spousal death); launch add-on tiers ($5k+) for transition users; target 100k+ households by partnering with divorce attorneys/widow support groups. Risks: Heightened regulatory scrutiny—mitigate via stronger CPA hooks and disclaimers. Revenue potential: Double user base by tapping underserved segments while leveraging heir core for cross-sell.

This MCP is the SSOT for all agents/PRDs—update via PR process.

