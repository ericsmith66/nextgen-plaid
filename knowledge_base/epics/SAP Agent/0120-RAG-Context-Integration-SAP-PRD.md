### 0120-RAG-Context-Integration-SAP-PRD

#### Overview
This PRD defines the integration of a simple RAG (Retrieval-Augmented Generation) mechanism into the SAP agent. It includes the creation of a `Snapshot` model for daily data state and a `Context Map` for intelligent document selection, ensuring accurate, project-aligned AI outputs without vector DB bloat.

#### Context Map
Create `knowledge_base/static_docs/context_map.md` to map query types to relevant documentation.
- Example: `generate_prd` -> `PRODUCT_REQUIREMENTS.md`, `0_AI_THINKING_CONTEXT.md`.
- SAP reads this map to select which documents to concatenate.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards. Log all context selection and concatenation steps in `agent_logs/sap.log`.

#### Definition of Done (DoD)
- **Model Implementation**: `Snapshot` model created with migration (belongs_to User, jsonb data).
- **RAG Logic**: SAP selects context based on `Context Map`.
- **Anonymization**: Snapshots are verified to be anonymized before being sent to the proxy.
- **Testing**: RSpec for `Snapshot` model and `ContextMap` query logic.

#### Requirements
**Functional Requirements:**
- **Snapshot Model**: `rails generate model Snapshot user:references data:jsonb`.
- **Context Map**: Create and maintain `knowledge_base/static_docs/context_map.md`.
- **Lightweight RAG**: SAP reads `Context Map`, selects relevant static docs, and fetches the latest `Snapshot` for the user.
- Prefix queries: Concatenate selected context as a prompt header. Max 4K characters; truncate oldest if exceeded.
- Handle context failures: Fallback to minimal prefix if `Snapshot` or docs are missing.
- Anonymization: Mask PII and real financial values (e.g., account numbers, exact balances) in snapshots.
- Dynamic Context: Support overrides via query parameters.

**Non-Functional Requirements:**
- Performance: <200ms for context fetch/concat (file reads/DB queries); keep total prompt under 8K chars to avoid API limits.
- Security: Anonymize all context (e.g., replace account masks/numbers with placeholders); use read-only access for files/DB.
- Compatibility: Rails 7+; no new gems—use built-in File/JSON for parsing.
- Privacy: Ensure context stays local; no external sends of raw data—prefix only sanitized strings.

#### Architectural Context
Extend SapAgent service within AiFinancialAdvisor framework, keeping it stateless except for query-time fetches. Reference agreed data model for snapshots (e.g., query Snapshot.where(user_id: current).last.as_json if model exists; add if not via migration). Use Rails-native file reads for static docs (e.g., File.read(Rails.root.join('0_AI_THINKING_CONTEXT.md'))). Align with RAG strategy: Simple concat for Phase 1 (95% value without PGVector); defer embeddings. No new models/controllers needed—add methods to sap_agent.rb (e.g., build_rag_prefix(query)). Prepare for future upgrades (e.g., optional PGVector query if added later). Test with mocked file/DB reads; ensure compatibility with Solid Queue for async prefixing if queries are queued.

#### Acceptance Criteria
- SAP routes a query with RAG: build_rag_prefix appends JSON snapshot + static docs correctly (e.g., console test shows prefixed string).
- Anonymization works: Sensitive fields (e.g., balances) masked in prefix (e.g., "$XXXX" instead of real values).
- Truncation handles limits: Long context truncates without errors, logging the action.
- Fallback on missing context: Proceeds with minimal prefix (e.g., MCP summary) and logs warning.
- Tool integration: Appends resolved tool results (e.g., search snippets) to context for re-routing if needed.
- No performance hit: Prefixing adds <200ms in benchmarks.
- Privacy check: Manual log inspection shows no unmasked data.

#### Test Cases
- Unit: RSpec for sap_agent.rb methods—mock File.read and Snapshot.as_json; test prefix concat (assert_match(/Context:.*Query:/, result)); verify anonymization (assert_no_match(/\$\d+/, prefixed)); edge cases like empty files or over-limit context.
- Integration: Test full routing with VCR for Grok (include prefixed prompt in cassette); enqueue job and assert logged prefix; simulate tool append (stub response with tool output, assert merged context).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0120-rag-context-integration-sap`). Ask questions and build a plan before coding (e.g., "What exact static docs to include? How to anonymize JSON snapshots? Add Snapshot model if missing?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Generate PRD-0130, or implement this with Junie?