# Junie Task Log — AGENT-05-0050C CWA Impl/Test/Commit (Tool Calling)
Date: 2026-01-01  
Mode: Brave  
Branch: feature/prd-50c-cwa-impl  
Owner: Junie

## 1. Goal
- Add a tool-calling CWA agent (INTP persona) to the `ai-agents` workflow so Coordinator can hand off implementation/test/commit work, with a sandboxed, dry-run-first execution model.

## 2. Context
- PRD: `knowledge_base/epics/AGENT-05/AGENT-05-0050C.md`
- Existing baseline: `AiWorkflowService` uses `ai-agents` runner with SAP → Coordinator handoff and audits to `agent_logs/ai_workflow/<correlation_id>/events.ndjson`.
- Decision (per user): implement CWA via `AiWorkflowService`/`ai-agents` path; do not refactor the queue-based `CwaAgent`/`CsoAgent` in this task.
- Safety: tools are local-only; default `dry_run`; execution requires explicit enable (`AI_TOOLS_EXECUTE=true`); no remote git push/merge.

## 3. Plan
1. Inspect `ai-agents` 0.7.0 tool API and handoff wiring.
2. Create `SafeShellTool` and `GitTool` with strict allowlists + deny-by-default behavior.
3. Add an out-of-process sandbox runner under `tmp/agent_sandbox/`.
4. Wire Coordinator → CWA handoff into `AiWorkflowService`.
5. Add unit + integration tests for tool allowlists, dry-run, and “no commit when tests fail”.
6. Run `bundle exec rake test` (and `rubocop` if present).
7. Commit locally when green.

## 4. Work Log (Chronological)
- Boot verified after tool DSL fix (removed invalid `name "..."` usage that prevented Rails boot).
- Implemented tool-calling CWA wiring in `AiWorkflowService` (Coordinator can hand off to CWA).
- Added sandboxed tool execution via `script/agent_sandbox_runner` + `AgentSandboxRunner`.
- Hardened sandbox runner to avoid shell invocation by executing argv arrays.
- Implemented tool guardrails (max calls/turn=10, max retries=2) and commit gating (commit requires green tests).
- Added MiniTests for `SafeShellTool`, `GitTool`, and Coordinator→CWA handoff.

## 5. Files Changed
- `app/services/ai_workflow_service.rb` — include `CWA` agent in runner; Coordinator→CWA handoff; event artifacts.
- `app/tools/safe_shell_tool.rb` — deny-by-default allowlist + denylist; dry-run gate; sandbox cwd; guardrails; record test exit status.
- `app/tools/git_tool.rb` — local-only git actions; sandbox init; remote-op blocks; commit gating; guardrails.
- `app/services/agent_sandbox_runner.rb` — out-of-process execution wrapper; worktree creation via runner.
- `script/agent_sandbox_runner` — executes commands in sandbox; exits with underlying command status.
- `config/initializers/ai_agents.rb` — eager-load tools/runner; document `AI_TOOLS_EXECUTE`.
- `knowledge_base/personas.yml` — added `intp` persona description for CWA.
- `test/tools/safe_shell_tool_test.rb` — tool unit coverage.
- `test/tools/git_tool_test.rb` — tool unit coverage.
- `test/services/ai_workflow_service_test.rb` — added Coordinator→CWA handoff test.
- `knowledge_base/prds-junie-log/2026-01-01__agent-05-0050c-cwa-impl-test-commit.md` — task log.

## 6. Commands Run
- `bin/rails runner 'puts "boot_ok"'` — ✅ boot ok
- `bundle exec rails test test/tools/safe_shell_tool_test.rb test/tools/git_tool_test.rb` — ✅ pass
- `bundle exec rails test test/services/ai_workflow_service_test.rb` — ✅ pass
- `bundle exec rake test` — ✅ pass

## 7. Tests
- `bundle exec rake test` — ✅ pass

## 8. Decisions & Rationale
- Decision: Use `AI_TOOLS_EXECUTE=true` as the explicit human enable switch; default is dry-run.
  - Rationale: safe-by-default behavior; easy to audit and override.
- Decision: Implement in `AiWorkflowService`/`ai-agents` path; keep existing queue-based agents unchanged.
  - Rationale: aligns with the epic’s Coordinator→CWA handoff requirements; avoids scope creep.

## 9. Risks / Tradeoffs
- Introducing shell/git tooling increases risk surface.
  - Mitigation: deny-by-default allowlists, sandboxed cwd, no network/remote git operations, dry-run by default.

## 10. Follow-ups
- [ ] Decide whether to deprecate or bridge the queue-based `CwaAgent`/`CsoAgent` after the `ai-agents` CWA path is validated.

## 11. Outcome
- `AiWorkflowService` supports Coordinator→CWA handoff with tool calling.
- Tools are dry-run by default and require `AI_TOOLS_EXECUTE=true` for execution.
- Tool execution is sandboxed and out-of-process; unsafe commands and remote git ops are blocked.
- Commits are blocked unless tests have been executed and are green.

## 12. Commit(s)
- Pending
