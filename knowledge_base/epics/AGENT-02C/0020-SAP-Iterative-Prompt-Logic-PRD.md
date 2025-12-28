## 0020-SAP-Iterative-Prompt-Logic-PRD.md

#### Overview
This PRD updates the `SapAgent` system prompts and logic to support multi-turn iterations. Instead of failing on ambiguity, the agent is encouraged to ask clarification questions. This iteration is managed via queue states in Solid Queue, allowing the agent to "pause" and wait for human input. This enables a more conversational and accurate workflow for complex tasks like Plaid data enrichment.

#### Acceptance Criteria
- Update `config/agent_prompts/sap_system.md` to mandate clarification questions (e.g., "If context is missing, output questions first").
- Implement `awaiting_input` state in `AgentLog` and `AgentQueueJob` for Solid Queue management.
- Add logic to `SapAgent::Router` to detect "clarification requests" and pause execution.
- Integrate with `recurring.yml` to poll for human responses to agent questions.
- Ensure the agent can resume a task once the `payload[:human_input]` is provided.
- Maintain a history of the current iteration loop (up to 3 turns) to provide context for the next prompt.
- Log iteration turns in `agent_logs/sap.log` with a unique `iteration_id`.

#### Architectural Context
- **Prompts**: `config/agent_prompts/sap_system.md`
- **Queueing**: Solid Queue via `AgentQueueJob`.
- **State Management**: `AgentLog` records the transition from `RUNNING` to `AWAITING_INPUT`.
- **Iteration History**: Stored in the payload passed through the queue.

#### Test Cases
- **TC1: Clarification Trigger**: Verify that an ambiguous request (e.g., "Fix the bug in Plaid") results in a list of questions rather than a failed attempt.
- **TC2: State Transition**: Confirm the job state changes to `awaiting_input` in the database when a question is posed.
- **TC3: Resumption**: Verify that providing input via a Rake task (see PRD 0030) resumes the job with the new context.
- **TC4: Turn Limit**: Ensure the agent terminates the loop after 3 unsuccessful iterations to prevent infinite loops.
- **TC5: Persistence**: Verify that the context from Turn 1 is present in the prompt for Turn 2.
