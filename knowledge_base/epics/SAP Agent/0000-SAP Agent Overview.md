### Proposed SAP Agent Epic to Address Workflow Inefficiencies

This epic implements the SAP (Senior Architect and Product Manager) Agent to automate PRD/epic generation, storage, and collaboration loops, eliminating manual copy-pasting across Grok web, RubyMine/Junie, and logs. By routing queries to Grok API via a standalone SmartProxy, SAP will handle end-to-end tasks: generating atomic PRDs, storing them directly in knowledge_base/prds/, querying Junie for reviews/questions, resolving answers via Grok, and aiding debugging with log access—streamlining to a single rake invocation or service call.

- **Core Role**: SAP orchestrates AI-driven product/architecture tasks, formatting queries with RAG context (JSON snapshots + static docs), proxying to Grok for generation/resolution, parsing outputs, and integrating with Junie workflows (e.g., auto-pull PRDs for review, feed questions back for answers).
- **Setup**: SAP in app/services/sap_agent.rb via AiFinancialAdvisor; standalone SmartProxy as Sinatra app (localhost:4567) for Grok API proxying with ENV (GROK_API_KEY, SMART_PROXY_URL). Use Solid Queue for async jobs; integrate RubyMine/Junie hooks via rake tasks or file watches for seamless loops.
- **Augmentation**: SmartProxy manages secure proxying (e.g., anonymized requests, retries); SAP adds RAG prefixing, quality self-eval, and Junie integration (e.g., simulate paste via file I/O or API if available).
- **Workflow**: Invoke via `rake sap:process[query]` (e.g., "Generate PRD for webhook"); SAP generates via Grok proxy, stores in `knowledge_base/`, writes to `inbox/` for Junie. Use `rake junie:poll_inbox` to see pending tasks. SAP iterates until green implementation, and debugs by pulling/analyzing logs.

### PRDs in This Epic (Atomic Breakdown, Using Naming Convention)
- 0100-SmartProxy-Sinatra-Server-PRD: Standalone SmartProxy Sinatra Server (Basic Grok API proxy setup + VCR/WebMock DoD).
- 0110-SAP-Core-Service-Setup-PRD: SAP Core Service Setup (Unified Command Pattern: Generate, QA, Debug).
- 0120-RAG-Context-Integration-SAP-PRD: RAG Context Integration (Snapshot Model, Context Map, Lightweight RAG).
- 0130-PRD-Epic-Storage-Notification-PRD: Storage, Notification & Handshake (Inbox/Outbox folders, `junie:poll_inbox` rake task).

### Updated Implementation Path
1. **Phase 1: Connectivity & Core (0100 + 0110)** - Get Rails talking to Grok via Proxy and establish the Unified Command Pattern.
2. **Phase 2: The Handshake (0130)** - Establish the Inbox/Outbox registry and Junie CLI wrapper.
3. **Phase 3: Intelligence & RAG (0120)** - Add Snapshot model, Context Map, and RAG prefixing.
4. **Phase 4: Hardening (DoD)** - Integrated testing, logging, and rotation across all services.

Next: Implement 0100-SmartProxy-Sinatra-Server-PRD.