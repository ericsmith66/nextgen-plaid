## 0010-SAP-Code-Review-Method-PRD.md

#### Overview
This PRD implements a specialized `review` method within the `SapAgent` service. The goal is to allow the agent to perform targeted code analysis on specific files or diffs, leveraging `browse_page` for fetching remote context (e.g., raw GitHub/GitLab files) and `code_execution` for local analysis (e.g., running RuboCop or parsing `git diff`). This method will output a structured assessment to assist Junie or human developers in identifying potential issues or improvements in 3-5 key files per session.

#### Acceptance Criteria
- Implement `SapAgent#review(target_context)` method that accepts file paths or branch diffs.
- Integrate `browse_page` tool to fetch raw file content for remote repository analysis.
- Integrate `code_execution` tool to run `rubocop` or custom static analysis scripts on the targeted files.
- Ensure the output follows a strict structured format: Strengths, Weaknesses, Critical Issues, and Recommendations.
- Implement a default escalation to Ollama for code-heavy reviews to manage costs on large repos.
- Limit review scope to a maximum of 5 files per call to prevent token overflow and ensure depth.
- Provide a summary of the review to be logged in `agent_logs/sap.log`.

#### Architectural Context
- **Service**: `app/services/sap_agent.rb`
- **Tooling**: `SapAgent::SmartProxyClient` for `browse_page` and `code_execution`.
- **Escalation**: `SapAgent::Router` will prioritize Ollama for large file payloads (>2k tokens) while keeping Grok for summary synthesis.
- **Data Flow**: Target files -> Tool Fetch -> LLM Analysis -> Structured Markdown Output.

#### Test Cases
- **TC1: Remote Review**: Verify the agent can fetch a raw file URL via `browse_page` and provide a structured review.
- **TC2: Local Diff Review**: Verify the agent can analyze a local `git diff` via `code_execution` and identify syntax errors.
- **TC3: Escalation Logic**: Confirm the router switches to Ollama when the combined file size exceeds 4,000 tokens.
- **TC4: Format Validation**: Ensure the output always contains the four required headers (Strengths, Weaknesses, Issues, Recommendations).
- **TC5: Scope Limit**: Verify that requesting a review for 10 files results in a warning and processes only the first 5.
