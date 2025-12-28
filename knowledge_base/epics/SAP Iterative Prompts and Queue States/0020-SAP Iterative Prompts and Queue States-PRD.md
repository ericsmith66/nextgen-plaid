## 0020-SAP Iterative Prompts and Queue States-PRD.md

#### Overview
This PRD outlines updates to the Strategic Architecture Planner (SAP) agent prompts to encourage proactive clarification questions during requirement decomposition, enabling multi-turn interactions. It introduces queue states in Solid Queue to manage iterative conversation flows, integrating with the existing recurring.yml for asynchronous handling of human-in-the-loop reviews. The scope focuses on enhancing agent-human collaboration for refining PRDs without disrupting core backlog processing, ensuring privacy by storing queue data in encrypted database fields.

#### Acceptance Criteria
- SAP prompts must include explicit instructions to ask up to 2 clarification questions per response if requirements are ambiguous, with questions formatted as a numbered list at the end of the output.
- Solid Queue must implement new states (e.g., 'pending_clarification', 'awaiting_review', 'iterated') for jobs handling SAP iterations, stored in a new QueueState model with foreign keys to Job records.
- Integration with recurring.yml must add a new scheduled task that checks queue states every 15 minutes and triggers notifications for pending clarifications via email or in-app alerts.
- Multi-turn flows must support at least 3 iterations per PRD generation, with each turn persisting conversation history in a JSONB field on the QueueState model to maintain context.
- System must ensure back-and-forth conversations are limited to simple text-based exchanges, rejecting any attempts to process non-text inputs or external data fetches during iterations.
- Error handling must log and retry failed queue state transitions up to 3 times, with failures escalating to an admin alert without exposing user data.
- All queue state changes must be audited in a log file at config/log/queue_iterations.log, including timestamps and user IDs for traceability.

#### Architectural Context
- **Service/Model**: Updates to app/agents/sap_agent.rb for prompt modifications; new app/models/queue_state.rb model with associations to SolidQueue::Job; extensions to app/jobs/iteration_job.rb for state management.
- **Dependencies**: Solid Queue gem for job queuing; existing config/schedule/recurring.yml for cron-like tasks; Rails ActiveRecord for database interactions and encryption via attr_encrypted.
- **Data Flow**: User requests trigger SAP prompt execution via a controller action, enqueueing an IterationJob; job updates QueueState and checks recurring.yml for async processing; clarifications are routed back to the user via a webhook or polling mechanism, looping until resolution.

#### Test Cases
- **TC1**: Simulate ambiguous user request in SAP agent; verify prompt output includes exactly 2 clarification questions and enqueues job with 'pending_clarification' state.
- **TC2**: Trigger recurring.yml task; confirm it detects 'pending_clarification' states and sends notification email with conversation history, without processing further until response.
- **TC3**: Submit clarification response to queued job; ensure state transitions to 'iterated', persists updated history in JSONB, and generates refined PRD output.
- **TC4**: Force 4 iterations on a single PRD; validate system caps at 3 iterations, logs excess attempts in config/log/queue_iterations.log, and finalizes PRD.
- **TC5**: Induce queue state transition failure (e.g., database timeout); check for 3 retry attempts, escalation to admin alert, and no data exposure in logs.