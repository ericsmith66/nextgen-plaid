++++++# Epic 4.5: Bare-Metal Streaming Chat

### Epic Goal
Simplify Agent-04 to a minimal, functional streaming chat UI for SAP oversight—focus on bottom-pinned input, auto-scroll stream, and Turbo/polling basics. Leverage HostedGPT for Turbo partials/message broadcasting, alexrudall's gist (https://gist.github.com/alexrudall/cb5ee1e109353ef358adb4e66631799d) for Sidekiq job with streaming proc and Turbo appends (adapt OpenAI to Ollama via AiFinancialAdvisor), mdominiak/hotwire-chat for realtime Turbo Streams, TailView for Hotwire-ready components (bubbles/modals/gear).

### Scope
Single page with pinned input/send, vertical stream for text appends; Turbo Streams/polling for chunks; no sidebar/gear/audit—stub for future. Wire to SapAgent for question-answer flow (user inputs question → SapAgent processes → streams response).

### Non-Goals
Controls/heartbeat (defer); audit/artifacts; automated tests beyond MiniTest/VCR basics.

### Dependencies
SapAgent for generation; SmartProxy ports (3001 dev/3002 test).

### Risks/Mitigations
Flaky streaming → polling fallback with banner; test with canned responses via VCR.

### End-of-Epic Capabilities
- Submit task → streaming text appends to stream (prompt/response/chunks).
- Auto-scroll keeps latest at bottom; pinned input for resets.
- Error chunks show in stream with IDs.
- Stable base for future layers (no ActionCable reliance).

### Atomic PRDs Table
| Priority | Feature | Status | Dependencies |
|----------|---------|--------|--------------|
| 1 | 0010E: Bare Layout & Input (vertical stream, pinned footer/send, auto-scroll JS) + SapAgent Wiring | Todo | None |
