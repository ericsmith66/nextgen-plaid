### Feedback on Epic 2: RAG & Backlog Management (AGENT-02B)

I have reviewed the PRDs for Epic 2 and evaluated their sufficiency in meeting the stated goals. Overall, the plan is robust and builds logically on the foundations established in Epic 1.

#### 1. Observations and Findings
*   **Strong Integration**: The use of `FinancialSnapshotJob` as the vehicle for RAG state is excellent. It leverages an existing pattern while expanding its utility from "User Data" to "Project State."
*   **Backlog SSOT**: `0030` correctly identifies the need to move from a flat `TODO.md` to a structured `backlog.json` while maintaining `TODO.md` as a readable entry point.
*   **Event-Driven Freshness**: `0040` (Webhooks) is a key differentiator. It ensures the AI isn't working with "stale" information after a merge, which is a common failure mode in agentic workflows.
*   **Performance Awareness**: The <4K token limit for RAG concat is a pragmatic constraint that will prevent prompt bloat while forcing high-quality summarization.

#### 2. Clarifying Questions
*   **Backlog Sync Direction**: Is `TODO.md` the primary source that updates `backlog.json`, or should `backlog.json` eventually become the source of truth with `TODO.md` being generated from it? (Recommendation: `backlog.json` as SSOT, `TODO.md` as a view).
*   **Summarization Strategy**: In `0010`, should summarization be deterministic (e.g., first N lines + tail) or LLM-driven? (Recommendation: Start deterministic to save tokens/cost, escalate to LLM for complex history).
*   **Webhook Secret**: Does the project already have a `GITHUB_WEBHOOK_SECRET` configured in `.env`, or should that be part of the `0040` setup?
*   **Snapshot Retention**: `0010` mentions dated files for audit. Do we need a cleanup task for these snapshots to avoid disk bloat over months of daily runs?

#### 3. Proposed Improvements & Alternatives

✅ **Unified Metadata Extraction (0020)**
*   **Proposal**: Instead of just regex for titles, use a lightweight frontmatter parser (or simulate one) to allow PRDs to define their own metadata (e.g., `priority: High`) in a structured block at the top of the file.
*   **Benefit**: More resilient than regex and allows PRDs to "self-declare" their status in the inventory.

✅ **"Prune with Care" (0030)**
*   **Proposal**: Instead of strictly deleting Low-priority items >30 days, move them to a `knowledge_base/backlog_archive.json`.
*   **Benefit**: Maintains the "YAGNI" goal for the active prompt while preserving the "Someday/Maybe" ideas for long-term planning.

✅ **Schema Minification (0010)**
*   **Proposal**: For `schema.rb` minification, focus on extracting table names and column names/types, but omit indices and foreign key constraints unless specifically requested.
*   **Benefit**: Dramatically reduces token usage while keeping 90% of the architectural context.

✅ **Local Git Check (0010)**
*   **Proposal**: If `git` is not available in the environment where the job runs, fallback to reading the `inventory.json` created in `0020`.
*   **Benefit**: Ensures the RAG framework is resilient to different deployment environments.

#### 4. Concurrence & Next Steps
I concur that these PRDs are sufficient to achieve the AGENT-02B goals. They provide a clear path from "Static Prompting" to "Context-Aware Architecture."

**Recommended Sequence**:
1.  Implement `0010` (Snapshot Framework) - This is the "Data Source."
2.  Implement `0020` (Inventory Task) - This is the "Metadata Layer."
3.  Implement `0030` (Backlog Methods) - This is the "Logic Layer."
4.  Implement `0040` (Webhook Refresh) - This is the "Automation Layer."

I am ready to begin with **0010-SAP-RAG-Concat-Framework-PRD.md**. Shall I proceed?


* **My response:** 
### Response to Junie's Feedback on Epic 2

#### 1. Observations and Findings
- **Strong Integration**: Agreed—extending FinancialSnapshotJob for project state is a smart reuse, aligning to Rails conventions and avoiding new jobs. This strengthens RAG without over-engineering.
- **Backlog SSOT**: Confirmed, `0030` correctly positions `backlog.json` as the evolving SSOT, with `TODO.md` as input/view— we'll enforce this in implementation to prevent sync conflicts.
- **Event-Driven Freshness**: Yes, `0040` is critical for agent reliability; it ties well to existing webhook infrastructure, ensuring SAP's context is always post-merge accurate.
- **Performance Awareness**: The 4K token limit is pragmatic; we'll monitor in pilots and adjust if Ollama/Grok prompts need more, but start strict to force quality summaries.

#### 2. Clarifying Questions
- **Backlog Sync Direction**: `backlog.json` should be the SSOT, with `TODO.md` as a human-readable view generated from it (e.g., via rake export). Update `0030` implementation to include bidirectional sync logic, prioritizing JSON for AI.
- **Summarization Strategy**: Start with deterministic summarization (e.g., first N lines + tail for history, keyword extract for vision) to save tokens/cost; escalate to LLM (Ollama default) only if deterministic insufficient (add toggle in job). Update `0010` to specify this.
- **Webhook Secret**: Project has GITHUB_WEBHOOK_SECRET in .env (from README setup); `0040` should verify/use it—add to AC for signature validation.
- **Snapshot Retention**: Yes, add cleanup to `0010`: Retain last 7 daily snapshots, archive/delete older via rake (e.g., in recurring.yml weekly); log deletions to avoid bloat.

#### 3. Proposed Improvements & Alternatives
- **Unified Metadata Extraction (0020)**: Agreed—use lightweight frontmatter parser (e.g., regex for YAML block at top of MD); PRDs can self-declare (e.g., --- priority: High ---). Update `0020` to include this, falling back to regex if no frontmatter.
- **"Prune with Care" (0030)**: Accepted—move pruned items to `knowledge_base/backlog_archive.json` instead of delete; add restore method if needed. This balances YAGNI with retention for future governance/philanthropy features.
- **Schema Minification (0010)**: Yes, limit to table/column names/types (omit indices/FKs unless key for Plaid models like Account/Position); update `0010` code_state extraction to use regex on schema.rb for this.
- **Local Git Check (0010)**: Good catch—add fallback to inventory.json if git unavailable (e.g., deployment env check); log warning and use last snapshot. Update `0010` error handling accordingly.

#### 4. Concurrence & Next Steps
Concur—the PRDs meet AGENT-02B goals for context-aware SAP. Proceed with your recommended sequence (0010 first). Incorporate human inspection: Add admin web page (preferred over rake) for viewing context metadata (e.g., /admin/rag_inspector in Mission Control dashboard, showing latest snapshot/inventory/backlog JSON with search/filter; specify in `0010` as optional UI extension, using Streamlit-like simplicity if tying to app.py inspiration).

Next steps: Proceed with `0010-SAP-RAG-Concat-Framework-PRD.md` implementation; confirm any LLM switch (stick to Claude Sonnet 4.5 default).