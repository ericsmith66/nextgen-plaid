# Junie Task Log — AGENT-05-0050F Unified AI Routing & Live-Search Orchestration
Date: 2026-01-02  
Mode: Brave  
Branch: <branch-name>  
Owner: ericsmith66

## 1. Goal
- Unify model routing decisions across SAP + AI Workflow and add SmartProxy server-side tool-loop orchestration (max 3 loops) with deterministic tests.

## 2. Context
- PRD: `knowledge_base/epics/AGENT-05/AGENT-05-0050F.md`
- Prior milestone: PRD 50E Planner phase already implemented and tested.

## 3. Plan
1. Add shared routing policy service with unit tests.
2. Wire policy into SAP routing and AI workflow runs; log routing decisions.
3. Implement SmartProxy `/v1/chat/completions` server-side tool loop (max 3) using existing live-search logic.
4. Add deterministic tests (Rails Minitest + SmartProxy RSpec) and run them green.

## 4. Work Log (Chronological)
- Added `Ai::RoutingPolicy` with a small heuristic (simple → `ollama`, complex/research → `grok-4`, privacy high → `ollama`).
- Updated `SapAgent::Router` to delegate to policy and log structured JSON routing decisions.
- Updated `AiWorkflowService.run_once` to compute a routing decision per run, record a `routing_decision` artifact event, and use the chosen model.
- Implemented SmartProxy tool-loop orchestration for OpenAI-style `tool_calls` in `/v1/chat/completions` with `SMART_PROXY_MAX_LOOPS` (default 3).
- Added deterministic RSpec coverage for tool loop and max loop enforcement.

## 5. Files Changed
- `app/services/ai/routing_policy.rb` — new shared routing policy service.
- `test/services/ai/routing_policy_test.rb` — unit tests for routing policy.
- `app/services/sap_agent/router.rb` — SAP routing now delegates to policy and logs structured decisions.
- `test/services/sap_agent/integration_test.rb` — added delegation test.
- `app/services/ai_workflow_service.rb` — per-run policy decision + routing decision artifact event.
- `test/services/ai_workflow_service_planner_test.rb` — asserts `routing_decision` event; relies on policy-selected model.
- `smart_proxy/app.rb` — server-side tool loop for `/v1/chat/completions`.
- `smart_proxy/spec/app_spec.rb` — tool-loop specs + max loop enforcement.

## 6. Commands Run
- `bin/rails test test/services/ai/routing_policy_test.rb test/services/sap_agent/integration_test.rb test/services/ai_workflow_service_planner_test.rb` — ✅ pass
- `cd smart_proxy && bundle exec rspec` — ✅ pass

## 7. Tests
- `bin/rails test test/services/ai/routing_policy_test.rb test/services/sap_agent/integration_test.rb test/services/ai_workflow_service_planner_test.rb` — ✅ pass
- `cd smart_proxy && bundle exec rspec` — ✅ pass

## 8. Decisions & Rationale
- Decision: Implement routing policy as a heuristic service (`Ai::RoutingPolicy`) returning a structured decision.
    - Rationale: Centralizes existing routing heuristics and makes outputs inspectable/loggable.
    - Alternatives considered: Keep SAP router + AI workflow defaults separate (rejected; inconsistent behavior).
- Decision: Implement SmartProxy tool loop inside `/v1/chat/completions`.
    - Rationale: Enables “single request → tool execution → final response” semantics.

## 9. Risks / Tradeoffs
- Server-side tool loop increases SmartProxy coupling/complexity.
- Mitigation: `SMART_PROXY_MAX_LOOPS` cap (default 3) and deterministic unit tests.

## 10. Follow-ups
- [ ] Ensure `/admin/ai_workflow` UI (if present) surfaces `routing_decision` events clearly.
- [ ] Consider expanding supported tool name mapping as providers converge on `tool_calls` conventions.

## 11. Outcome
- SAP + AI workflow now share the same routing policy outputs, and SmartProxy can execute tool calls server-side with a safety loop cap.

## 12. Commit(s)
- Pending
