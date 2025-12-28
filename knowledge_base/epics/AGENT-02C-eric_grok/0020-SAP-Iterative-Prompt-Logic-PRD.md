### 0020-SAP-Iterative-Prompt-Logic-PRD.md

#### Overview
This PRD updates SAP prompts to include clarification questions and adds Solid Queue states for multi-turn iteration, allowing back-and-forth like conversations. Ties to vision: Supports collaborative PRD refinement for Plaid features, reducing errors in tax/philanthropy simulations.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All prompt updates, queue states, and iteration events must be logged in `agent_logs/sap.log` with structured entries (e.g., timestamp, question output, human input, outcome). Rotate logs daily via existing rake.

#### Requirements
**Functional Requirements:**
- **Prompt Update**: Modify sap_system.md to add guardrail: "If query ambiguous, output questions first (numbered list) and pause for input"; integrate with RAG concat from Epic 2.
- **Queue States**: Add Solid Queue job states in SapAgent (e.g., #iterate_prompt enqueues 'await_input' if questions output; poll for human response via rake).
- **Iteration Logic**: Handle 2-3 turns (e.g., parse human input, append to context, re-run prompt); tie to recurring.yml for async timeouts (e.g., expire after 1h).
- **Error Handling**: On no input, log timeout and fallback to original prompt; limit turns to 5 to prevent loops.

**Non-Functional Requirements:**
- Performance: Iteration round <200ms; queue poll <50ms.
- Security: Sanitize human input; Devise auth on poll.
- Compatibility: Rails 7+; use Solid Queue—no new gems.
- Privacy: Local queue only.

#### Architectural Context
Update Epic 1 prompts in config/agent_prompts/; integrate queue with SapAgent router (enqueue on question output). Use Rails job for states; no migrations. Tie to Epic 2 RAG for appended context. Test with mock queues (stub Sidekiq). Challenge: Prevent infinite loops (hard turn limit); use code_execution for input parsing if complex.

#### Acceptance Criteria
- Updated prompt outputs numbered questions on ambiguous query (e.g., "1. Clarify deadline?").
- Queue state enqueues 'await_input' and polls for response.
- Iteration appends input and re-runs (e.g., 2 turns refine PRD).
- Timeout after 1h logs and falls back.
- Max 5 turns enforced.

#### Test Cases
- Unit (RSpec): For prompt logic—mock ambiguous query, assert output.include?('Questions: 1.'); for #iterate_prompt, assert enqueue and state change.
- Integration: Simulate multi-turn (enqueue, mock input, assert refined prompt); Capybara-like: Feature spec with javascript: true to visit /admin/iterate_prompt, fill_in 'Query', click 'Submit', expect page.to have_content('Questions: 1. Clarify deadline?'), fill_in 'Input', click 'Respond', expect page.to have_content('Refined PRD after 2 turns'), expect page.to have_no_content('Exceeded max turns'), cover timeout (mock delay, expect page.to have_content('Fallback to original')), max turns (simulate 5, expect page.to have_content('Iteration stopped at max')).
- Edge: No questions (no enqueue); invalid input (sanitize and log).

#### Workflow
Junie: Use Claude Sonnet 4.5 (default). Pull from master (`git pull origin main`), create branch (`git checkout -b feature/0020-sap-iterative-prompt-logic`). Ask questions and build a plan before coding (e.g., "Prompt guardrail phrasing? Queue state enum? Timeout config? Input sanitization?"). Implement in atomic commits; run tests locally; commit only if green. PR to main with description linking to this PRD.
