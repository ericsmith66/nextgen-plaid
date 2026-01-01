# Epic 4.5: Bare-Metal Streaming Chat
### Epic Goal
Simplify Agent-04 to a minimal, functional streaming chat UI for SAP oversight—focus on bottom-pinned input, auto-scroll stream, and Turbo Streams basics (ActionCable-backed). Leverage alexrudall's gist (https://gist.github.com/alexrudall/cb5ee1e109353ef358adb4e66631799d) for Sidekiq job with streaming proc and Turbo broadcasts (adapt OpenAI to Ollama via AiFinancialAdvisor; use replace for updates), mdominiak/hotwire-chat for realtime Turbo Streams, TailView for Hotwire-ready components (bubbles/modals/gear).

### Baseline Decisions (confirmed)
- Turbo Streams (ActionCable-backed) is the v1 baseline; no custom ActionCable channels (Turbo defaults only).
- No polling/fallback for v1.
- One DB record per bubble: create one assistant message and update it over time (Turbo `replace` for updates).
- Background job owns the streaming loop; controller stays thin.
- All Ollama calls route through SmartProxy (ports 3001 dev / 3002 test).
- Use `perform_later` (ActiveJob abstraction) for enqueuing.
### Scope
Single page with pinned input/send, vertical stream for text updates; Turbo Streams for chunks; no sidebar/gear/audit—stub for future. Wire to SapAgent for question-answer flow (user inputs question → SapAgent processes → streams response).
### Non-Goals
Controls/heartbeat (defer); audit/artifacts; polling/fallback transport; `flex-col-reverse` / complex scroll or mobile keyboard handling; automated tests beyond MiniTest/VCR basics; custom ActionCable channels (Turbo defaults only).
### Dependencies
SapAgent for generation; SmartProxy ports (3001 dev/3002 test); Redis for ActionCable.
### Risks/Mitigations
Websocket flaky → document limitation for v1 (no fallback); test with canned responses via VCR.
### End-of-Epic Capabilities
- Submit task → streamed text appends/updates to single assistant bubble (prompt/response/chunks).
- Auto-scroll keeps latest at bottom; pinned input for resets.
- Error chunks show in bubble with IDs.
- Stable base for future layers (Turbo/ActionCable enabled).
### Atomic PRDs Table
| Priority | Feature | Status | Dependencies |
|----------|---------|--------|--------------|
| 1 | 0010E: Bare Layout & Input (vertical stream, pinned footer/send, auto-scroll JS) + SapAgent Wiring | Todo | None |

### PRD 0010E
See `knowledge_base/epics/AGENT-4.5/PRD-0010E.md` for the implementation-ready requirements and acceptance criteria.