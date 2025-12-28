# Epic 3: Reviews & Interaction (AGENT-02C)

**Overview**: Adds review method using browse_page/code_execution for targeted context (e.g., diffs from recent branches, RuboCop on .rubocop.yml), defaulting Ollama for cost on large repos. Addresses limited interaction via rake CLI (extending lib/tasks/ for human polls/questions) and folds 0130 by replacing filesystem with Solid Queue jobs for SAP-Junnie handshakes (e.g., enqueue PRD storage to knowledge_base/epics/, notify via rake). Ties to vision: Enables iterative feedback for Plaid enrichment (e.g., post-sync reviews), maintaining local privacy and "educational simulation" disclaimers.

## Atomic PRDs

### [0010-SAP-Code-Review-Method-PRD.md]
**Status**: Placeholder
**Description**: Implements SapAgent review method to fetch targeted context via browse_page (e.g., raw file URLs like app/models/plaid_item.rb) and code_execution for analysis (e.g., parse diffs, run RuboCop); outputs structured format (strengths/weaknesses/issues/recommendations), defaulting Ollama to handle repo limits without overload, focusing on 3-5 key files per review.

### [0020-SAP-Iterative-Prompt-Logic-PRD.md]
**Status**: Placeholder
**Description**: Updates SAP prompts to encourage clarification questions (e.g., "If unclear, output questions first") and adds queue states in Solid Queue for multi-turn iteration (e.g., pause for human input on ambiguities); integrates with existing recurring.yml for async handling, ensuring simple back-and-forth like conversation flows.

### [0030-SAP-Human-Interaction-Rake-PRD.md]
**Status**: Placeholder
**Description**: Creates rake sap:query[prompt] in lib/tasks/ for human inputs (e.g., print summaries, copy templates to pbcopy for feedback); extends to poll queue for outputs/notifications, tying to Devise auth for owner-only access and aligning to Mission Control dashboard for visibility.

### [0040-SAP-Queue-Based-Storage-Handshake-PRD.md]
**Status**: Placeholder
**Description**: Replaces 0130 filesystem with Solid Queue jobs for storing SAP artifacts (e.g., PRDs to knowledge_base/epics/ as MD files) and handshakes (enqueue to outbox job for Junie review, notify via rake); includes Git ops (commit via system calls with dirty state stash) and backlog ties (auto-update statuses on storage), ensuring resilience without concurrent issues.

## Success Criteria
- Performs targeted review on sample branch (e.g., analyzes 3-5 files like app/services/sync_holdings_job.rb without overload)
- Handles 2-3 iterative loops via queue
- Stores/notifies PRD without filesystem issues
- 100% alignment to AC in pilots, referencing README Mission Control for verification.

## Capabilities Built
- Collaborative SAP with review orchestration (e.g., post-Junnie commit analysis)
- Multi-turn human loops via rake/queue
- Reliable data management between SAP and Junnie/CWA for future autonomy.
