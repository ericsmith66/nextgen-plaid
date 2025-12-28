## 0030-SAP-Human-Interaction-Rake-PRD.md

#### Overview
This PRD introduces a Rake-based interface for human-agent interaction. Since Junie operates primarily via CLI/Filesystem, the `sap:query` task provides a bridge for the user to answer the agent's clarification questions (from PRD 0020), provide feedback on reviews (from PRD 0010), and view agent status. It also integrates with `pbcopy` for easy transfer of templates/feedback.

#### Acceptance Criteria
- Create `rake sap:query[prompt]` in `lib/tasks/sap_interaction.rake`.
- Implement `sap:poll` to check for agents in the `awaiting_input` state and print their questions.
- Implement `sap:respond[task_id, response]` to push human answers back into the Solid Queue.
- Add `sap:review:feedback` to copy review summaries to `pbcopy` and prompt for "Approve/Reject".
- Restrict interaction to authorized users (using Devise auth checks where applicable via a helper).
- Align output formatting with the Mission Control dashboard style for visual consistency.
- Ensure all interactions are logged to `agent_logs/sap.log` with `human_interaction` event type.

#### Architectural Context
- **Task Location**: `lib/tasks/sap_interaction.rake`.
- **Interaction Layer**: Connects human CLI input to `AgentQueueJob` (Solid Queue).
- **Security**: Basic ownership check on `AgentLog` or `User` records.
- **Integration**: Uses `system("echo '#{content}' | pbcopy")` for clipboard support on macOS.

#### Test Cases
- **TC1: Polling**: Run `rake sap:poll` and ensure it lists active jobs waiting for input.
- **TC2: Responding**: Execute `rake sap:respond[123, 'Yes, proceed']` and verify the `AgentQueueJob` for task 123 is re-enqueued.
- **TC3: Clipboard Integration**: Run `rake sap:review:feedback` and verify the review content is in the system clipboard.
- **TC4: Error Handling**: Ensure providing an invalid `task_id` to `sap:respond` returns a clear "Task not found" error.
- **TC5: Log Audit**: Check `sap.log` after a response to verify the event is recorded correctly.
