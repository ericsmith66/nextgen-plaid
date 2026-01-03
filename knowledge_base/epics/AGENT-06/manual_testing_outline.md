### Manual Testing Outline — Agent-06 (PRDs 0000/0010/0020/0030/0040/0050)

This document is a step-by-step manual test checklist for the Agent-06 epic.

#### Preconditions (one-time)
1. Ensure dependencies are installed:
   - `bundle install`

2. Ensure SmartProxy is running locally.
   - Expected: SmartProxy listens on `http://localhost:<SMART_PROXY_PORT>/v1` and supports:
     - `POST /v1/chat/completions`
     - `GET /v1/models`

3. Export environment variables (use your real values):
   - `export SMART_PROXY_PORT=3002`
   - `export PROXY_AUTH_TOKEN=<your_secure_proxy_token>`
   - `export OLLAMA_MODEL=llama3.1:70b`
   - `export OLLAMA_KEEP_ALIVE=5m`
   - `export GROK_API_KEY=<your_grok_key>`

4. Start Rails:
   - `bin/rails s`
   - Expected: server boots without errors.

---

### PRD 0000 — Overview constraints (safety + sandbox)

#### Goal
Confirm the system is deny-by-default, dry-run by default, sandboxed, and local-only.

#### Steps
1. Verify tool execution is dry-run by default:
   - Ensure `AI_TOOLS_EXECUTE` is **not** set (or set to `false`).
   - Run a minimal workflow:
     - `rake ai:run_request['Please run bundle exec ruby -v']`
   - Expected:
     - Output completes.
     - `agent_logs/ai_workflow/<cid>/events.ndjson` contains `tool_start`/`tool_complete` events with `action: dry_run`.

2. Verify sandbox directory exists/used:
   - Expected (after any git/shell tool init): `tmp/agent_sandbox/` exists.
   - Expected: any tool output includes a `cwd` under the sandbox worktree.

---

### PRD 0010 — CWA persona + SafeShell/Git tools

#### Goal
Confirm CWA is globally registered and tools enforce guardrails.

#### Steps
1. Confirm CWA is registered and runnable:
   - Run:
     - `rake ai:run_request['Please implement a tiny change via CWA']`
   - Expected:
     - `agent_logs/ai_workflow/<cid>/events.ndjson` shows `agent_handoff` to `CWA`.

2. Confirm tool guardrails (max tool calls per turn = 5):
   - Run:
     - `bundle exec rails test test/tools/safe_shell_tool_test.rb test/tools/git_tool_test.rb`
   - Expected:
     - Tests pass.
     - Guardrail test asserts failure after 5 calls.

3. Confirm default command timeout (30s) and test timeout (300s):
   - Run a command tool call (with execute enabled):
     - `AI_TOOLS_EXECUTE=true rake ai:run_request['Run bundle exec ruby -v']`
   - Expected:
     - Command completes well under 30s.
     - `events.ndjson` includes `timeout_seconds: 30` for command runs.

---

### PRD 0020 — CWA task log template + persistence

#### Goal
Confirm the 12-section log is generated and persisted for each correlation id.

#### Steps
1. Run a request that hands off to CWA:
   - `rake ai:run_request['Please implement via CWA and describe what you would change']`

2. Inspect persisted log files:
   - Locate: `agent_logs/ai_workflow/<cid>/`
   - Expected files:
     - `events.ndjson`
     - `run.json`
     - `cwa_log.json`
     - `cwa_log.md`

3. Verify `run.json` includes embedded snapshot:
   - Open `agent_logs/ai_workflow/<cid>/run.json`
   - Expected keys:
     - `cwa_log`
     - `cwa_log_markdown`

4. Verify size cap behavior:
   - Run:
     - `bundle exec rails test test/services/ai/cwa_task_log_service_test.rb`
   - Expected:
     - Test passes.
     - The log indicates `truncated: true` when it exceeds ~100kB.

---

### PRD 0030 — Read-only MCP-like tools

#### Goal
Confirm the read-only tools exist, are sandboxed, dry-run by default, and reject unsafe input.

#### Steps
1. Run tool unit tests:
   - `bundle exec rails test test/tools/project_search_tool_test.rb test/tools/vc_tool_test.rb test/tools/code_analysis_tool_test.rb`
   - Expected: all tests pass.

2. Manual dry-run check:
   - Ensure `AI_TOOLS_EXECUTE` is not set.
   - Trigger CWA and ask it to search:
     - `rake ai:run_request['Use ProjectSearchTool to find where AiWorkflowService is defined']`
   - Expected:
     - Tool output is `action: dry_run`.
     - Search is constrained to `app/`, `lib/`, `test/`.

---

### PRD 0040 — (If applicable) Coordinator/Planner policies

#### Goal
Validate routing policy behaviors described in 0040 (if enabled in this build).

#### Steps
1. Run an analysis-only request:
   - `rake ai:run_request['Explain what AiWorkflowService does at a high level']`
   - Expected:
     - Response is produced without needing tool execution.

2. Run an implementation-type request:
   - `rake ai:run_request['Implement something small and ask CWA to do it']`
   - Expected:
     - Handoff chain is visible in `events.ndjson`.

---

### PRD 0050 — Hybrid handoff, resumability, and human review state

#### Goal
Confirm that when CWA completes, the workflow transitions to human review and can resume from `run.json`.

#### Steps
1. Run a request that hands off to CWA:
   - `rake ai:run_request['Please implement via CWA']`

2. Verify the final state is awaiting review:
   - Open: `agent_logs/ai_workflow/<cid>/run.json`
   - Expected:
     - `context.state` is `awaiting_review`
     - `context.ball_with` is `Human`
   - Also expected in `events.ndjson`:
     - `type: awaiting_review`
     - `type: draft_artifacts_available`

3. Verify resumability:
   - Re-run the same request with the same correlation id (simulate “resume”):
     - `ruby -e 'require "securerandom"; puts "Use the same cid you just used"'`
     - `rake ai:run_request['Continue the work using the existing correlation id']` (or use a small wrapper that passes `correlation_id`)
   - Expected:
     - The service loads context from `agent_logs/ai_workflow/<cid>/run.json`.
     - No crash; log files are updated.

4. Verify Junie deprecation note:
   - Run:
     - `rake ai:run_request['Junie: generate code for X']`
   - Expected:
     - `events.ndjson` includes an event with `type: junie_deprecation`.

---

### SmartProxy verification (integration + live smoke)

#### Steps
1. Run SmartProxy integration and smoke tests:
   - `SMART_PROXY_LIVE_TEST=true INTEGRATION_TESTS=1 SMART_PROXY_PORT=3002 PROXY_AUTH_TOKEN=<token> OLLAMA_MODEL=llama3.1:70b OLLAMA_KEEP_ALIVE=5m GROK_API_KEY=<key> bundle exec rails test test/integration/sap_agent_smartproxy_integration_test.rb test/smoke/smart_proxy_live_test.rb`
   - Expected:
     - `0` failures, `0` errors, `0` skips.
