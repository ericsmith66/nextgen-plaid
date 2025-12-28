## AGENT-02C-0030-SAP-Rake-Task-for-Human-Prompts-and-Notifications-PRD.md

#### Overview
This PRD defines the requirements for implementing a rake task `sap:query[prompt]` that enables human inputs, extends to poll queue for outputs/notifications, and ties into Devise auth for owner-only access. The feature will also be integrated with Mission Control dashboard for visibility.

#### Acceptance Criteria
- The `sap:query[prompt]` rake task is successfully executed in the `lib/tasks/` directory.
- Human inputs are correctly captured and processed by the rake task, triggering the necessary workflows.
- The rake task extends to poll queue for outputs/notifications, ensuring timely updates and notifications.
- Devise auth is properly integrated, restricting access to owner-only and enforcing privacy-first principles.
- The feature is seamlessly integrated with Mission Control dashboard, providing visibility into human inputs, outputs, and notifications.
- Error handling and logging mechanisms are in place to ensure smooth operation and debugging capabilities.
- Unit tests and integration tests are written to validate the rake task's functionality.

#### Architectural Context
- **Service/Model**: `lib/tasks/sap_query.rake`, `app/models/user.rb`, `app/controllers/application_controller.rb`
- **Dependencies**: `devise`, `sidekiq` (for queue polling), `rails-api` (for API integrations)
- **Data Flow**: Human inputs are captured through the rake task, which triggers workflows that interact with the queue and Devise auth. Outputs/notifications are processed by the rake task and made visible on the Mission Control dashboard.

#### Test Cases
- **TC1**: Successful execution of `sap:query[prompt]` rake task with valid human input.
- **TC2**: Error handling for invalid or missing human input during rake task execution.
- **TC3**: Owner-only access restriction enforced by Devise auth, preventing unauthorized access to the rake task.
- **TC4**: Integration test for polling queue and processing outputs/notifications correctly.
- **TC5**: Mission Control dashboard visibility test, ensuring that human inputs, outputs, and notifications are accurately displayed.