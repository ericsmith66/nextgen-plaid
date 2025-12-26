### 0120-RAG-Context-Integration-SAP-PRD

#### Overview
This PRD defines the integration of a simple RAG (Retrieval-Augmented Generation) mechanism into the SAP agent service to prefix queries with relevant context (daily JSON snapshots + static docs) before routing to Grok via SmartProxy, ensuring accurate, project-aligned AI outputs like PRDs/epics. This supports the project's vision of reliable workflow automation for HNW financial data syncing by providing context-aware generations without complex vector DBs, reducing hallucinations in tasks like feature planning.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all RAG context fetches, concatenations, and prefixing operations are logged with timestamps, anonymized snippets, and error traces in agent_logs/sap.log.

#### Requirements
**Functional Requirements:**
- Extend sap_agent.rb to fetch and concatenate RAG context before routing: Pull daily user-specific JSON blobs from FinancialSnapshotJob (e.g., totals, allocations, tasks via a service call or DB query on Snapshot model if exists), plus static docs (e.g., read 0_AI_THINKING_CONTEXT.md and PRODUCT_REQUIREMENTS.md from repo root or knowledge_base/).
- Prefix queries: Concatenate context as a prompt header (e.g., "Context: [JSON blob + static doc chunks]. Query: [user input]") with a max token limit (e.g., 4K characters; truncate oldest if exceeded); ensure anonymization (e.g., mask real financial values in snapshots).
- Handle context failures: Fallback to minimal MCP summary if fetch fails (e.g., file not found); log warnings but proceed with query.
- Support dynamic context: Allow optional per-query context overrides (e.g., via method arg for specific docs); integrate with tools (e.g., append search results from web_search if tool call resolved).

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