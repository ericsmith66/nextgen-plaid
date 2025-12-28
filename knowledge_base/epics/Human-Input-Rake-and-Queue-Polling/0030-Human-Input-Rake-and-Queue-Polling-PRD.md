## 0030-Human-Input-Rake-and-Queue-Polling-PRD.md

#### Overview
This PRD outlines the development of a Rake task named sap:query[prompt] in lib/tasks/ to handle human inputs for the SAP agent system, enabling iterative prompts and interactions. It extends functionality to poll a queue for outputs and notifications, ensuring secure access tied to Devise authentication for owner-only interactions. The implementation aligns with the Mission Control dashboard for visibility, supporting reviews and interactions in the AGENT-02C backlog item.

#### Acceptance Criteria
- The Rake task sap:query[prompt] must be defined in lib/tasks/sap.rake and accept a string prompt as an argument to submit human inputs to the agent's interaction queue.
- Task execution must enforce Devise authentication, restricting access to the authenticated owner user (e.g., via current_user check in a wrapped service), preventing unauthorized runs.
- The task must integrate queue polling logic to retrieve and display outputs/notifications from a Redis-backed queue (e.g., using Sidekiq or Resque), with polling occurring at configurable intervals (default: 30 seconds).
- Outputs from the queue must be formatted as JSON and logged to the console, including fields for response_text, timestamp, and status, while also triggering email notifications via ActionMailer for the owner.
- Integration with the Mission Control dashboard must display queued inputs/outputs in a dedicated view (e.g., app/views/mission_control/queue.html.erb), showing real-time updates via WebSockets or polling.
- Error handling must be implemented for invalid prompts (e.g., empty strings) and authentication failures, raising specific exceptions like ArgumentError or AuthorizationError.
- The task must support iterative prompts by storing session state in the queue, allowing follow-up queries to reference prior context via a session_id parameter.

#### Architectural Context
- **Service/Model**: Key files include lib/tasks/sap.rake for the Rake task definition, app/services/sap/human_input_service.rb for business logic, and app/models/queue_item.rb for modeling queue entries with attributes like prompt, response, and user_id.
- **Dependencies**: Relies on Devise gem for authentication, Sidekiq or Resque for queue management, ActionMailer for notifications, and Rails WebSockets (ActionCable) for dashboard updates; depends on AGENT-02B for backlog and RAG methods.
- **Data Flow**: Human inputs via the Rake task are authenticated, then enqueued as QueueItem records; a polling mechanism dequeues and processes items, updating the Mission Control dashboard in real-time while storing persistent data in PostgreSQL for privacy-compliant access.

#### Test Cases
- **TC1**: Invoke sap:query["Test prompt"] as an authenticated owner; verify the prompt is enqueued, polled, and displays a JSON output in the console with correct timestamp and status.
- **TC2**: Attempt to run sap:query["Invalid"] without authentication; confirm an AuthorizationError is raised and no queue item is created.
- **TC3**: Submit an iterative prompt with session_id; ensure the response references prior context from the queue and updates the Mission Control dashboard view.
- **TC4**: Test queue polling with multiple notifications; verify all are retrieved, formatted as JSON, and trigger an email to the owner via ActionMailer.
- **TC5**: Provide an empty prompt argument; confirm an ArgumentError is raised, and the task logs the error without enqueuing anything.