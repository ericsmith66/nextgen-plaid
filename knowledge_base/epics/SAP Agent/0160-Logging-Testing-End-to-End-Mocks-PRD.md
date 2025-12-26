### 0160-Logging-Testing-End-to-End-Mocks-PRD

#### Overview
This PRD defines the comprehensive logging, testing, and end-to-end mocking setup for the SAP agent epic, ensuring reliable audits, verifiable code quality, and mocked external dependencies (e.g., Grok API via WebMock/VCR) for full workflow simulation without live calls. This completes the epic's vision of streamlined AI-assisted PRD generation and Junie handoff for HNW financial data syncing, enabling robust verification of automation loops while mitigating risks like data leakage or flaky tests.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all SAP operations (routing, storage, loops, debugging), errors, and agent interactions are logged with timestamps, anonymized details, and traces in epic-specific logs/ subdir (e.g., knowledge_base/epics/sap-agent-epic/logs/sap.log; rotate daily; include end-to-end workflow summaries like "Completed QA loop: 2 iterations").

#### Requirements
**Functional Requirements:**
- Implement logging across SAP service (app/services/sap_agent.rb): Use Rails.logger or custom Logger in epic/logs/ for key events (e.g., query routing start/end, storage commits, QA/debug iterations); anonymize payloads (e.g., mask API keys, financial mocks); rotate logs daily via File.rename or simple cron rake.
- Add testing suite: RSpec for unit/integration (spec/services/sap_agent_spec.rb); cover core methods (e.g., route_query, process_qa_loop, process_debug) with mocks for SmartProxy HTTP (WebMock stubs) and file I/O (allow(File).to receive(:write)).
- Enable end-to-end mocks: Use VCR to cassette real Grok/SmartProxy interactions (e.g., sanitized API keys); mock full workflows (e.g., generate PRD -> store -> notify -> QA loop -> debug) in integration specs; include rake tests (e.g., Rake::Task['sap:qa_loop'].invoke in specs).
- Handle errors in tests/logs: Log test failures with backtraces; ensure mocks handle retries/timeouts; add rake test:sap to run suite and report coverage (>80%).
- Workflow verification: Add end-to-end rake (e.g., rake sap:end_to_end_mock[query]) that simulates full epic flow with mocks, logging "Workflow complete: [status]" for manual validation.

**Non-Functional Requirements:**
- Performance: Logs add <50ms overhead; test suite runs <30s; mocks reduce external calls to zero in CI/dev.
- Security: Redact sensitives in logs/tests (e.g., ENV vars as [REDACTED]); ensure mocks don't leak real keys.
- Compatibility: Rails 7+; gems: rspec-rails, webmock, vcr (add to Gemfile if missing).
- Privacy: No real data in mocks/cassettes; align with local-only testing.

#### Architectural Context
Integrate logging into SapAgent methods (e.g., around blocks for events); use Rails.logger.info for simplicity, directing to epic/logs/ via custom appender if needed. Testing: Place in spec/services/; use factories/fixtures for mock snapshots/static docs. Mocks: Configure VCR in spec/support/vcr.rb (ignore_localhost: true for SmartProxy); WebMock for stubs in units. Align with epic structure: Logs in knowledge_base/epics/[slug]/logs/; no new models/migrations—leverage existing rakes. Prepare for post-CWA queues: Make tests queue-aware (e.g., perform_enqueued_jobs { ... }). Focus on MVC (services only); ensure green commits via workflow.

#### Acceptance Criteria
- Logging captures full events (e.g., manual run logs query start/end/anonymized payload in epic/logs/sap.log).
- Daily rotation works (e.g., new file created on date change; old renamed).
- Unit specs pass (>80% coverage on sap_agent.rb; mocks verify HTTP calls/file writes).
- Integration specs simulate workflows (e.g., VCR cassette plays back Grok response; asserts storage/QA/debug outputs).
- rake test:sap runs suite without failures; reports coverage.
- End-to-end rake sap:end_to_end_mock completes mock flow, logs "Workflow complete," and produces expected files/outputs.
- Errors logged with backtraces (e.g., simulated failure shows trace without crashing).
- No unredacted sensitives in logs/cassettes (manual inspection).

#### Test Cases
- Unit: RSpec for logging (assert_logged(/Query routed/)); test rotation (mock Time.now, assert File.exist?(rotated_path)); mock errors (raise in method, assert_logged backtrace).
- Integration: VCR for Grok routing (cassette matches payload/response); end-to-end spec chains generate/store/QA/debug, asserts all files/logs created; edge cases like max iterations, dirty Git, or invalid inputs.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0160-logging-testing-end-to-end-mocks`). Ask questions and build a plan before coding (e.g., "Logger config details? VCR setup preferences? Coverage threshold?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Epic complete—implement with Junie, or generate 0000-Epic-Overview.md for sap-agent-epic?