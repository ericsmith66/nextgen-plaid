# Agent-04: Collaboration UI Refactor.md

### Epic Goal
Refactor /admin/sap-collaborate into a Grok/Libre-style streaming chat UI for SAP Agent oversight. Enable interactive starts with overrides, live feedback, controls, and health checks—stable, responsive, English-first.

### Scope
Vertical chat layout with streaming messages; pinned input/gear menu; polling-based logs; Heartbeat probe; audit sidebar. Use Turbo/Stimulus for dynamics; DaisyUI/Tailwind for styling.

### Non-Goals
New SapAgent logic; multi-user sharing; automated tests (manual steps only); cloud deploys.

### Dependencies
SapAgent basics (iterate_prompt with resume_token); SmartProxy ports (3001 dev/3002 test); vision.md injection for context.

### Risks/Mitigations
- Flaky polling → 3s interval with retry banner; test on slow nets.
- LLM downtime → Heartbeat pre-check before starts.
- Over-complex JS → Minimal Stimulus; manual steps verify.

### Guidance for Style, Look, and Feel
- **Style**: Conversational Grok/Libre-inspired—clean, modern, professional for HNW users. Sans-serif fonts, ample whitespace, subtle animations (bubble fade-in). English-first: Humanized summaries default, raw JSON optional.
- **Look**: Vertical message stream (user right blue bubbles, agent left gray); pinned bottom input bar; gear icon (top-right) for controls; audit in collapsible sidebar/tab. Spinners/banners neutral (info blue, error red). Mobile: Input visible, no overflow; desktop: Full-height chat (~80vh).
- **Feel**: Fluid—streaming feels "live typing"; quick feedback (spinner &lt;2s, poll 3s); intuitive (gear hides complexity); resilient (fallbacks with messages like "Polling updates...").

### Navigation to the Page
- **Path**: /admin/sap-mission-control as the new default (admin/owner-gated via Devise/Pundit); /admin/sap-collaborate redirects with a deprecation banner.
- **How**: From main nav (NavigationComponent): Add link &lt;a href="/admin/sap-mission-control" class="menu-item"&gt;SAP Oversight&lt;/a&gt; under Admin Panel dropdown. Dashboard redirect for admins: If current_user.admin?, button "Collaborate with SAP" → new path. Ensure 403/redirect for non-admins with message "Access restricted to admins/owners."

### Current Screen Elements to Remove
- Static cards (e.g., form/status/audit cards)—replace with unified chat layout.
- Top-heavy form (textarea, grid inputs, buttons)—move to pinned bottom input + gear menu.
- Collapse for raw JSON—integrate as per-message toggle (e.g., "Show raw" link on agent bubbles).
- Alert banners (e.g., success/error)—fold into system bubbles in chat stream.
- Overflow-x-auto table for audit—move to sidebar/tab, simplify to list.
- Fallback alert (hidden)—integrate as chat system message.
- JS polling/Cable script—refactor into Stimulus controller for streams.

### Recommendation: New Page Replacement
- Build the new experience at /admin/sap-mission-control and deprecate /admin/sap-collaborate via redirect + banner (no side-by-side flag). Replace the old page once new flow is ready; keep redirect for discoverability/rollback messaging.

### End-of-Epic Capabilities
At the completion of this epic (after implementing renumbered PRDs 0010A-D), the /admin/sap-collaborate page will function as a dynamic, conversational interface for overseeing SAP Agent runs. Users (owner/admin only) will be able to:

* Initiate Runs Interactively: Enter a task in the pinned bottom input box, select model (Ollama/Grok/Claude), set token limit (e.g., 4000) and max iterations (e.g., 10) via a gear menu, and submit to start Adaptive Iterate or Conductor flows. Form disables with a spinner during processing.

* Monitor Live Streaming Feedback: See messages bubble up in real time (via Turbo Streams/polling): system prompts, LLM responses, token usage (used/remaining), phase markers (e.g., "Outlining...", "Refining..."), and humanized summaries/errors (via RAG, e.g., "Aborted: exceeded token limit").

* Control and Reset Runs: Pause/resume active runs with buttons; use "New Task" to clear the chat history, reset form, and stop polling without page reload.

* Probe LLM Health: Click a Heartbeat Check button in the gear menu to send a quick "2+2?" probe to the selected model, displaying success ("Alive: latency 1.8s") or failure banners.

* View Audit History: Access a tabbed or modal audit table showing recent runs with timestamps, redacted user labels, status, model used, correlation IDs, and artifact links/downloads (if produced).

* Handle Errors Gracefully: See contextual banners for issues (e.g., connection loss, token exceed) with correlation IDs; fallback to polling if streaming fails, ensuring usability on mobile/responsive layouts.

This results in a Grok/Libre-like experience: conversational flow, full visibility into agent processes, and per-run tweaks for testing/debugging—stable, no ActionCable reliance.

### Atomic PRDs (Renumbered as 0010A-D)
- **0010A: Layout Flip &amp; Pinned Input**: Vertical scroll chat; pinned bottom form; gear menu scaffold. (Value: Conversational base; Testable: Manual steps verify layout/responsiveness. Integrated style: Vertical stream with bubbles, pinned input.)
- **0010B: Streaming via Turbo/Polling**: Poll endpoint for chunks; append bubbles (prompt/response/tokens/phase). (Value: Live visibility; Testable: Start run → see incremental updates. Integrated style: Streaming in bubbles, quick feedback.)
- **0010C: Controls in Gear Menu &amp; Heartbeat**: Model/token/iter in gear; Heartbeat button probes LLM. (Value: Per-run tweaks/health; Testable: Set overrides → run uses them; probe → banner. Integrated style: Gear menu for hidden controls.)
- **0010D: Audit Sidebar &amp; Artifacts**: Persist/display runs in sidebar; artifact links/downloads. (Value: History/tracking; Testable: Complete run → see in list with details/links. Integrated style: Collapsible sidebar, responsive polish.)

### Summary of PRDs
- **0010A**: Focuses on core chat structure (vertical bubbles, pinned input/gear)—adds conversational foundation, testable via layout checks (e.g., "scroll to bottom → input pinned; resize window → no overflow"). Integrated style: Vertical stream with bubbles, pinned input.
- **0010B**: Adds dynamics (Turbo polling for message appends)—provides live value, testable via run initiation (e.g., "start task → see phased bubbles appear incrementally"). Integrated style: Streaming in bubbles, quick feedback.
- **0010C**: Integrates overrides/Heartbeat in gear—enables tweaks/health, testable via controls (e.g., "set token=4000 → run aborts at limit; heartbeat → banner shows latency"). Integrated style: Gear menu for hidden controls.
- **0010D**: Completes with audit sidebar/artifacts—adds persistence/history, testable via lifecycle (e.g., "pause/run → see in sidebar with redacted details; download artifact"). Integrated style: Collapsible sidebar, responsive polish.

### Test Approach
- Live-proxy opt-in: nightly manual runs with captures (screenshots/HTML) against real SmartProxy; gated via `.env.testing`.