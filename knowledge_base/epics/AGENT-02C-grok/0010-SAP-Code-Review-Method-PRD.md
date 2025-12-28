## 0010-SAP-Agent-Review-Method-PRD.md

#### Overview
This PRD outlines the implementation of a code review method within the SapAgent class to enable automated analysis of project code. The method will use the browse_page tool to fetch targeted context from 3-5 key files, integrate RuboCop for static analysis, and generate a structured output including strengths, weaknesses, issues, and recommendations. The scope focuses on enhancing iterative development by providing actionable feedback aligned with Rails best practices and the project's privacy-first architecture.

#### Acceptance Criteria
- The SapAgent class must include a new method named `perform_code_review` that accepts parameters for the target backlog item ID and an optional list of 3-5 file paths to review.
- The method must invoke the `browse_page` tool to retrieve content from specified files, ensuring only relevant Ruby files (e.g., from app/models, app/services, app/controllers) are fetched without accessing sensitive data.
- Integration with RuboCop must analyze the fetched code for style, security, and performance issues, using a custom configuration file at config/rubocop.yml to enforce project-specific rules.
- The output must be structured as a JSON object with keys: "strengths" (array of positive aspects), "weaknesses" (array of areas for improvement), "issues" (array of RuboCop-detected problems with line numbers), and "recommendations" (array of actionable fixes).
- The method must limit reviews to exactly 3-5 files per invocation, raising an error if fewer than 3 or more than 5 are provided or auto-selected based on backlog dependencies.
- Error handling must be implemented to gracefully manage failures in fetching files or running RuboCop, logging issues to Rails.logger without exposing file contents.
- The method must ensure privacy by redacting any potential sensitive information (e.g., API keys) from the fetched context before analysis.

#### Architectural Context
- **Service/Model**: Primary implementation in app/agents/sap_agent.rb; may interact with models like BacklogItem for dependency resolution.
- **Dependencies**: Relies on the browse_page tool (from lib/tools/browse_page.rb), RuboCop gem (version specified in Gemfile), and Rails logging; depends on AGENT-02B for backlog management.
- **Data Flow**: Input parameters trigger browse_page to fetch file contents; data is passed to RuboCop for analysis; results are formatted into JSON and returned or stored in a review queue for human interaction.

#### Test Cases
- **TC1**: Verify that `perform_code_review` fetches exactly 3 specified files (e.g., app/models/plaid_item.rb, app/services/plaid_service.rb, app/controllers/items_controller.rb), runs RuboCop, and outputs a JSON with all required keys populated.
- **TC2**: Test error raising when fewer than 3 files are provided, ensuring the method aborts and logs "Insufficient files for review" without proceeding to analysis.
- **TC3**: Simulate a RuboCop detection of a style issue (e.g., long method) in a fetched file and confirm the "issues" array includes the offense with line number and recommendation.
- **TC4**: Ensure privacy redaction by injecting mock sensitive data into fetched content and verifying it is removed before RuboCop analysis and in the final output.
- **TC5**: Validate auto-selection of 4 files based on backlog item dependencies (e.g., for AGENT-02C), confirming the method completes and structures output with at least one entry per key.