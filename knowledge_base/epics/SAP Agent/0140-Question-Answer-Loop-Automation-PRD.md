### 0140-Question-Answer-Loop-Automation-PRD

#### Overview
This PRD defines the automation of question/answer loops in SAP for handling Junie's reviews/plans/questions on PRDs (e.g., clarifying requirements before implementation), routing them back to Grok via SmartProxy for resolutions, and storing feedback in epic folders/logs for iterative refinement. This supports the project's vision of efficient, semi-automated workflows for HNW financial data syncing by minimizing manual pastes in RubyMine dialogs, enabling faster atomic feature builds like Plaid syncs while preparing for full queue-based agent comms post-CWA.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards, ensuring all loop operations (questions routed, answers parsed/stored, iterations) are logged with timestamps, query/answer snippets (anonymized), and error traces in epic-specific logs/ subdir (e.g., knowledge_base/epics/sap-agent-epic/logs/sap.log and logs/junie_actions.log; rotate daily).

#### Requirements
**Functional Requirements:**
- Extend sap_agent.rb with a loop method (e.g., process_qa_loop(question_path)) that reads Junie's questions from a file (e.g., epic/logs/junie_questions.md, structured as Markdown bullets), formats each as a Grok query (e.g., "Answer Junie's question on PRD [id]: [question text]"), routes via SmartProxy, parses answers, and stores as epic/logs/sap_answers.md (appending with question-answer pairs).
- Automate iteration: If answers require follow-ups (e.g., detected via self-eval prompt like "Does this answer need more details?"), re-route up to 3 times; otherwise, notify via rake output for manual Junie paste (e.g., "Answers ready: [path] – paste to Junie for next steps").
- Integrate with templates: Embed instructions in rake outputs (e.g., "Junie: Log questions in [epic/logs/junie_questions.md] as bullets. After answers, append 'Validation Steps' to PRD.md and run rake sap:review_changes[path]").
- Handle input/output: Support manual trigger via rake sap:qa_loop[question_path]; parse/validate questions (non-empty, relevant to PRD); return loop status (e.g., { "complete": true, "iterations": 2, "answer_path": "/path" }).
- Error handling: Retry failed routings (up to 2); log incomplete loops; fallback to minimal answer if Grok fails.

**Non-Functional Requirements:**
- Performance: <2s per question routing (excluding API); handle up to 10 questions per loop.
- Security: Anonymize questions/answers (e.g., mask any potential PII); read-write only on epic/ dirs.
- Compatibility: Rails 7+; no new gems—use File for I/O, existing routing.
- Privacy: Keep all data local; no external sends of unsanitized content.

#### Architectural Context
Build as methods in SapAgent service (e.g., format_questions, route_and_parse_answers, evaluate_completion). Use filesystem for inputs/outputs (e.g., junie_questions.md as bullet list; sap_answers.md as Q&A pairs). Align with epic structure: Store in knowledge_base/epics/[slug]/logs/; update 0000-Epic-Overview.md with loop summaries if resolved. No new models/migrations—leverage existing rake patterns for triggers. Prepare for post-CWA queues: Design loop as enqueuable jobs (e.g., QaLoopJob) via Solid Queue for async, agent-to-agent comms without manual pastes. Test with mocked files/routing; focus on simple loops initially to avoid complexity.

#### Acceptance Criteria
- SAP processes a mock junie_questions.md file, routes each question to Grok, and stores parsed answers in sap_answers.md with matching pairs.
- Iteration handles follow-ups: Self-eval detects incomplete answer and re-routes (e.g., 2 iterations logged).
- Rake sap:qa_loop outputs clipboard-ready notification with template instructions for Junie logging/validation append.
- Invalid input (e.g., empty questions) skips loop, returns error status, and logs warning.
- Concurrent loops don't conflict (e.g., unique temp files if needed).
- Privacy check: Logs/outputs show anonymized content (e.g., no real financial data).
- Loop completes in <10s for 5 questions; status hash reflects iterations/success.

#### Test Cases
- Unit: RSpec for process_qa_loop—mock File.read/write and routing; test formatting (assert_match(/Answer Junie's question:/, payload)); verify iteration (stub eval prompt to trigger re-route); check answer storage (assert File.exist?(answer_path) and content pairs).
- Integration: Test full flow with VCR Grok cassette; create mock questions file, enqueue job, assert answers stored/notified; edge cases like max iterations, failed routing, or non-Markdown input.

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0140-question-answer-loop-automation`). Ask questions and build a plan before coding (e.g., "Self-eval prompt details? Question format validation? Integrate with queue conditionally?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.

Next: Generate PRD-0150, or implement this with Junie?