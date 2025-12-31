### AGENT-04 Feedback: Suggestions, Questions, Objections, Alternatives, and Test Approach

#### Suggestions
- **Side-by-side rollout flag**: Keep both legacy and chat views behind a query param/env flag until 0010B is proven on slow networks; add a prominent fallback link to the legacy form.
- **Consistent bubble taxonomy**: Standardize bubble types (user/system/agent/error/token/phase) with a shared partial to avoid divergence across 0010A/0010B.
- **Correlation-first logging**: Ensure every poll response and UI event includes `correlation_id` to align with SmartProxy logs and SapAgent outputs.
- **Retry/backoff UX**: Add a subtle banner and exponential backoff after 3 poll failures; keep heartbeat button enabled during recoveries.
- **Gear presets**: Provide quick presets (e.g., "Fast draft" vs. "Deep dive") mapping to model/iteration/token defaults for faster operator starts.
- **Mobile-safe footer**: Reserve ~88px for mobile keyboards; ensure the pinned footer does not cover the latest bubble by adding bottom padding to the stream.
- **Raw/summary toggle**: Per agent bubble, add a "Show raw" toggle to expose JSON payloads without leaving the stream (ties to Non-Goals: no separate cards).
- **Pause/resume semantics**: Define explicit UI states (idle/running/paused/error) with button enable/disable rules to avoid conflicting actions during streaming.
- **Audit filters**: In 0010D, add quick filters (status/model) to reduce noise when many runs accumulate; paginate after 10 items.

#### Questions
- **Model mapping**: Which concrete model names map to "Grok" and "Claude" in dev/test/prod, and do we need environment-specific fallbacks if unavailable?
- **Heartbeat rate limits**: Are there SmartProxy or provider limits that require throttling heartbeats per user/session?
- **Token accounting source**: Should token usage be sourced from SmartProxy metrics or SapAgent estimates? How do we reconcile discrepancies in the UI?
- **Session persistence**: Should overrides (model/tokens/iterations) persist per user session or per correlation_id only?
- **Auth gating**: For admin/owner checks, should the page return 403 JSON for Turbo requests or always redirect with a flash message?
- **Resume tokens**: For paused runs, do we expose `resume_token` in the UI or keep it internal to avoid user misuse?

#### Objections / Risks
- **Polling fragility**: A hard-coded 3s poll may overload SmartProxy or miss fast phases; consider adaptive polling tied to run status.
- **LLM downtime UX**: Heartbeat alone may not cover transient failures during runs; need in-stream error bubbles with actionable text.
- **Audit data volume**: Without retention limits, SapRun rows + artifacts could grow quickly; define pruning/archival early.
- **State drift**: UI pause/resume buttons without server-side locks could double-issue commands; enforce idempotency on the backend before exposing controls.
- **Accessibility**: Bubble-only color cues may be insufficient; add iconography/aria labels for error and phase markers.

#### Alternatives
- **Streaming transport**: If Turbo Streams prove flaky, allow optional SSE endpoint with the same payload schema as the polling JSON.
- **Gear placement**: Instead of a dropdown, consider a slide-over drawer on desktop for better space to show presets and heartbeat history.
- **Token/phase display**: Collapse token counts into a compact badge on each agent bubble to reduce vertical space; expand on click for details.
- **Audit surface**: Instead of a sidebar, use a modal with a searchable table to minimize layout shifts on mobile.

#### Test Approach (with live proxy considerations)
- **Env setup**: Point the UI to SmartProxy dev (port 3001) and test (3002) with clear toggles; document a `.env.testing` for live-proxy runs.
- **Happy-path manual flow**: Start a run with defaults → verify streaming bubbles (phase/prompt/response/tokens) appear within 2s; ensure auto-scroll and footer pinning hold on mobile viewport sizes.
- **Error-path manual flow**: Force token-limit exceed or proxy timeout → expect red error bubble with correlation_id and retry banner; verify pause/resume buttons disable correctly.
- **Heartbeat probe**: With proxy up, run heartbeat and record latency; with proxy down, verify graceful failure bubble and no console errors.
- **Side-by-side check**: Toggle legacy vs. chat mode to confirm safe fallback and no 500s on legacy routes during chat rollout.
- **Integration/E2E candidates**:
  - Capybara/Playwright smoke: submit a task, stub SmartProxy with VCR/WebMock for deterministic responses; assert bubble order and auto-scroll.
  - Live-proxy gated suite (opt-in): against real SmartProxy, mark as `slow` and run nightly; capture artifacts (screenshots/HTML) for regressions.
  - Controller test: polling endpoint returns JSON schema (phase/prompt/response/tokens/error) and honors correlation_id scoping.
  - Stimulus unit test: scroll-to-bottom fires on turbo:frame-load and on new poll append; footer stays pinned after window resize.
- **Observability**: Add log hooks around poll/heartbeat requests with correlation_id and latency; assert in tests that logs are emitted (via `assert_logs` or captured stdout) to aid live-proxy debugging.
