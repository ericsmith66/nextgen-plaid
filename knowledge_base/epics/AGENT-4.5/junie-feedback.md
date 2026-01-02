## PRD 0010E: Bare Layout & Input (vertical stream, pinned footer/send, auto-scroll JS) + SapAgent Wiring
**Overview**: Create a minimal chat UI page at /admin/sap_collaborate for SAP interactions, featuring a vertical message stream, bottom-pinned input form, auto-scrolling JS, and direct wiring to SapAgent for submitting questions and streaming answers via Turbo. This establishes a bare-metal base for oversight, enabling users to ask questions (e.g., "Generate PRD for Plaid holdings sync") and receive streamed responses without sidebars or advanced controls.

**Requirements**:
1) **Bare Layout & Stream**: Use ERB view (admin/sap_collaborate/index.html.erb) with Tailwind CSS for a full-height vertical container (#chat-stream flex-col). Render messages as simple div bubbles (user: right-aligned blue, assistant: left-aligned gray) via partial (_message.html.erb). Stub future gear menu as empty div.
2) **Pinned Input & Send**: Footer form with textarea (pinned via position: sticky, min-height 100px) and submit button ("Send"). On submit, POST to /admin/sap_collaborate/ask → clear input, append user message to stream.
3) **Auto-Scroll JS**: Stimulus controller (chat_controller.js) with connected() for initial scrollIntoView on last message; MutationObserver on #chat-stream for dynamic scroll on updates. No mobile keyboard handling for v1.
4) **Turbo Streams Wiring**: Use Turbo Streams for real-time appends/replaces (broadcast_to "sap_channel" with partial chunks). No polling fallback for v1. Use Sidekiq job (SapAgentJob) for chunking: Enqueue on submit, process SapAgent.generate in background, broadcast each accumulation/error as Turbo Stream replace (target assistant bubble).
5) **SapAgent Connection**: Controller action ask (POST) → validate input, create user SapMessage, create assistant SapMessage (content: "Thinking..."), enqueue SapAgentJob.perform_later(sap_run_id, assistant_message_id), return Turbo Stream to append initial bubbles. SapAgentJob: Call AiFinancialAdvisor.ask(prompt) via SmartProxy (HTTP to localhost:3001), yield chunks, accumulate in-memory, broadcast replace after periodic updates (~500ms/500 chars) + final.
6) **Non-Functional**: Page loads in <2s; stream chunks every 1-2s; support 10k+ token responses without lag. Admin-only (before_action :authenticate_user!, :authorize_admin).
7) **alexrudall Gist Direction**: Copy GetAiResponse job structure closely: Enqueue SapAgentJob.perform_later(sap_run_id, assistant_id); use call_openai equivalent for Ollama (AiFinancialAdvisor.chat with stream: proc, routed via SmartProxy); create_messages to pre-build assistant stub; stream_proc to accumulate content in-memory, update! periodically, and broadcast_replace_later_to with partial (target assistant DOM id). Use Message model pattern for SapMessage (belongs_to :sap_run, enum role, after_update_commit broadcasts replace). Ignore OpenAI params; map to Ollama (model: "llama3.1:70b", prompt, stream: true). Simplify to single stream (n:1).

**Architectural Context**: Aligns with Rails MVC: SapCollaborateController for actions (ask); new SapRun model (tracks session) and SapMessage (for messages). Minimal migrations (create_table :sap_runs/:sap_messages). Use plaid-ruby patterns for services (SapAgentService for Ollama calls via SmartProxy, wrapping HTTP with JSON blobs from FinancialSnapshotJob). Inject vision.md/personas into SapAgent prompts for context. Local-only: Ollama on-premises, no cloud. Defer vector DB—use static MD files in RAG. UI: Tailwind/DaisyUI for responsive (mobile-first with flex); ViewComponent optional for _message if complexity grows.

**Acceptance Criteria**:
- Load /admin/sap_collaborate → empty stream, pinned input visible at bottom.
- Type question → submit → user bubble appends right-aligned, "Thinking..." left-aligned.
- SapAgent processes → chunks stream into assistant bubble via Turbo replaces, auto-scrolls to bottom.
- Full response completes → bubble markdown-rendered (e.g., bold/lists).
- Error (e.g., Ollama down) → bubble updates with "Error: [msg] (ID: xyz)".
- Mobile: Basic functionality (no overlap fixes).
- Admin-gate: Non-admins 403 on access.

**Test Cases**:
- Unit: MiniTest for SapAgentService.ask (mock HTTP to SmartProxy, assert chunk yields).
- Integration: MiniTest with VCR cassettes for end-to-end: Record real SmartProxy interactions (e.g., cassette for "Test question" → chunk responses); assert broadcast calls and final SapMessage.content. Use WebMock for stubs in non-VCR tests. Edge: Empty prompt → validation error bubble; long response (>5k tokens) → no truncation.

**Workflow**: Junie: Pull from main, git checkout -b feature/prd-10e-bare-chat-sap. Read <project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md for logging. Ask questions (e.g., "Redis config details?") and build a plan in junie-log.md before coding. Use Claude Sonnet 4.5 default in RubyMine. Implement, test with MiniTest/VCR using real SmartProxy (cassettes capture live runs), commit only if green (no errors in logs). Push branch for review.

---

## Alignment check (Epic ↔ PRD) after your answers
Your answers clearly choose the lowest-complexity path (copy the gist architecture, accept Turbo/ActionCable, single assistant bubble updated over time, no polling, SmartProxy mandatory). With that, the key alignment points are:

1) **Transport baseline**
- Epic: Turbo Streams (ActionCable-backed), no custom channels ✓
- PRD: Turbo Streams only, no polling fallback ✓

2) **Message persistence model**
- Epic: one DB record per bubble ✓
- PRD: avoids per-chunk rows and updates a single assistant `SapMessage` via `replace` broadcasts ✓

3) **Broadcast semantics**
- Epic/PRD: updates must be `replace`-style, not `append`, to avoid duplication ✓

4) **SmartProxy routing**
- Epic: SmartProxy required (3001 dev / 3002 test) ✓
- PRD: does not reference direct `localhost:11434` Ollama calls ✓

5) **Scope control / complexity avoidance**
- Epic/PRD: no `flex-col-reverse`, no mobile keyboard overlap logic, no hybrid Turbo+polling failure detection for v1 ✓

## Additional feedback (post-alignment)
1) **Avoid duplicated PRD text inside the Epic**
- Recommendation: keep the Epic as a high-level decision record (baseline decisions + PRD index) and keep detailed requirements only in `PRD-0010E.md`. This prevents inevitable drift.

2) **Make the Turbo stream name/channel explicit in the PRD**
- The PRD should name what we broadcast to (e.g., per-`SapRun` stream) so implementers don’t invent multiple incompatible conventions.

3) **Job input contract**
- PRD currently implies the job can reconstruct prompt from records; consider explicitly passing `user_message_id` (or the prompt string) alongside `sap_run_id` + `assistant_message_id` to keep the job deterministic.

4) **Testing scope**
- Keep VCR for SmartProxy integration tests, but don’t attempt to “assert streaming HTML in controller response bodies.” Focus on: chunk yielding, accumulation cadence, and that model/job triggers the expected broadcast calls.

