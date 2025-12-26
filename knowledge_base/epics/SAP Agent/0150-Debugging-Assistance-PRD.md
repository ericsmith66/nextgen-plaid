### 0150-Debugging-Assistance-PRD

#### Overview
This PRD defines the debugging assistance feature in SAP to analyze logs/errors from Junie's implementations (e.g., failed tests, runtime issues), route them to Grok via SmartProxy for fix proposals, and store suggestions in epic folders/logs for iterative resolution. This enhances the project's vision of automated workflows for HNW financial data syncing by reducing manual debugging in RubyMine, enabling faster fixes for Plaid features while preparing for queue-based agent collaboration post-CWA.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all debugging operations (log analysis, fix proposals, iterations) are logged with timestamps, error snippets (anonymized), and traces in epic-specific logs/ subdir (e.g., knowledge_base/epics/sap-agent-epic/logs/sap.log and logs/junie_actions.log; rotate daily).

#### Requirements
**Functional Requirements:**
- Extend sap_agent.rb with a debug method (e.g., process_debug(log_path, error_desc)) that reads error logs/tests from files (e.g., epic/logs/junie_errors.log or test failures), formats as Grok query (e.g., "Analyze Rails error in [log snippet]: Propose fix for PRD [id]"), routes via SmartProxy (with tools like code_execution if needed for simulation), parses proposals, and stores as epic/logs/sap_fix_proposals.md (appending with error-proposal pairs).
- Automate iteration: Use self-eval prompt (e.g., "Is this fix complete?") to re-route up to 3 times if proposal incomplete; notify via rake output for manual Junie paste (e.g., "Fix proposals ready: [path] – paste to Junie for application").
- Integrate with templates: Embed instructions in outputs (e.g., "Junie: Apply fix, log in [epic/logs/junie_actions.log], append 'Validation Steps' to PRD.md, then run rake sap:review_changes[path]").
- Handle inputs: Support manual trigger via rake sap:debug[log_path, desc]; validate logs (non-empty, relevant); return status (e.g., { "complete": true, "iterations": 1, "proposal_path": "/path" }).
- Error handling: Retry failed routings (up to 2); log unresolved issues; fallback to basic advice if Grok fails.

**Non-Functional Requirements:**
- Performance: <3s per debug routing (excluding API); handle up to 5KB log snippets.
- Security: Anonymize logs/errors (e.g., mask PII/tokens); read-write only on epic/ dirs.
- Compatibility: Rails 7+; no new gems—use File for I/O, existing routing.
- Privacy: Keep data local; no external sends of unsanitized logs.

#### Architectural Context
Build as methods in SapAgent service (e.g., parse_logs, route_debug_query, evaluate_fix). Use filesystem for inputs/outputs (e.g., junie_errors.log as structured text; sap_fix_proposals.md as pairs). Align with epic structure: Store in knowledge_base/epics/[slug]/logs/; update 0000-Epic-Overview.md with debug summaries if resolved. No new models/migrations—leverage rake for triggers. Prepare for post-CWA queues: Design as enqueuable jobs (e.g., DebugJob) via Solid Queue for async debugging without manual intervention. Test with mocked files/routing; focus on simple analysis initially.

#### Acceptance Criteria
- SAP processes a mock junie_errors.log, routes analysis to Grok, and stores parsed fix proposals in sap_fix_proposals.md with matching pairs.
- Iteration handles incompletes: Self-eval triggers re-route (e.g., 2 iterations logged).
- Rake sap:debug outputs clipboard-ready notification with template instructions for Junie application/logging/validation append.
- Invalid input (e.g., empty logs) skips process, returns error status, and logs warning.
- Anonymization works: Sensitive data masked in queries/logs (e.g., tokens as [REDACTED]).
- Concurrent debugs don't conflict (e.g., unique temp files).
- Process completes in <15s for 2KB log; status reflects iterations/success.

#### Test Cases
- Unit: RSpec for process_debug—mock File.read and routing; test formatting (assert_match(/Analyze Rails error:/, payload)); verify iteration (stub eval to re-route); check proposal storage (assert File.exist?(path) and content pairs).
- Integration: Test full flow with VCR Grok cassette; create mock error log, enqueue job, assert proposals stored/notified; edge cases like max iterations, failed routing, or irrelevant logs.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0150-debugging-assistance`). Ask questions and build a plan before coding (e.g., "Self-eval prompt for fixes? Log parsing format? Integrate with queue?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Generate PRD-0160, or implement this with Junie?