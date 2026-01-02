# Agent-06 — Review Feedback (Alignment with Agent-05)

Date: 2026-01-01

This document reviews:
- `knowledge_base/epics/AGENT-06/0000.overview-agent-06.md`
- `knowledge_base/epics/AGENT-06/0010-Agent-06.md`
- `knowledge_base/epics/AGENT-06/0020-Agent-06.md`
- `knowledge_base/epics/AGENT-06/0030-Agent-06.md`
- `knowledge_base/epics/AGENT-06/0040-Agent-06.md`

It also considers the current Agent-05 plan (Epic 5 / PRDs `0050A–E`) and the actual spike work already merged on branch `AGENT-05-Spike`:
- `ai-agents` working with **real handoffs** (`handoff_to_coordinator`) under deterministic tests.
- SmartProxy now has `GET /v1/models` backed by Ollama `GET /api/tags`.

---

## High-signal summary

Agent-06 is clearly intended to be a **CWA / code-writing agent epic** (tools + self-debug loop + hybrid handoff). That is directionally consistent with Agent-05’s later PRDs (especially `0050C` tool calling + safety and `0050E` planning).

However, there are still alignment issues to address:

1) **Naming convention alignment**: You changed PRD naming to numeric `0010–0050` (instead of A–E). Agent-06 is now aligned on that convention.
   - Action: ensure Agent-05 docs and any cross-references avoid `0050A/0050B` naming where your repo standard is `0010/0020/...`.
2) **Claude assumption mismatch**: Agent-06 overview lists “Ollama/Grok/Claude”, but SmartProxy **does not implement Claude yet**.
   - Action: mark Claude as “⏳ Not yet” (like we did in Agent-05) until SmartProxy adds it.
3) **Risk + safety**: Agent-06 proposes `rails runner`/runtime inspection and mentions commands including `rm`.
   - Objection: any write-capable runtime tool is high risk unless it is heavily constrained.
   - Action: keep v1 read-only tools; consider removing `rm` from the “capabilities” list.

---

## Detailed questions / comments / objections

### A) Epic definition & file correctness

**Update (re-review)**: The cut/paste issue appears resolved. `0000.overview-agent-06.md` is now correctly titled **“Epic 6: Code Writing Agent Build (Agent-06)”** and the PRDs are consistently numbered `0010–0050`.

**Question**: Should Agent-06 remain a separate epic, or should its later PRDs (especially `0030` and `0040`) be folded into Agent-05 as post-`0050C` extensions?

**Alternative**: If you want everything under one umbrella, treat Agent-06 as “Epic 5 continuation” and move:
- `0030` → “CWA tooling extensions” after Agent-05 tools are stable
- `0040` → “Self-debug loop” after basic tool sandbox is proven

### B) Claude/Grok/Model routing assumptions

**Comment**: Agent-05 now includes a “Provider Support Matrix” and explicitly flags Claude as “not yet” (because SmartProxy doesn’t implement it).

**Recommendation**:
- Update Agent-06 docs to treat Claude as **future** until SmartProxy adds it.
- Prefer “model ids advertised by SmartProxy `/v1/models`” rather than hardcoded model strings.

### C) Tooling scope: MCP-like tools (0030)

**Objection**: “MCP-like tools” is broad and can easily become an unsandboxed remote shell.

**Safer alternative** (recommended for a code-writing agent):
1) Start with **read-only** tools only:
   - `ProjectSearchTool` (repo grep restricted to allowlisted dirs)
   - `VcTool` (git status/log/diff only)
   - `CodeAnalysisTool` (rubocop output only)
2) Defer `RuntimeTool` until we have:
   - a proven sandbox
   - a firm allowlist
   - explicit “no DB writes” enforcement (e.g., run in a dedicated read-only mode, or wrap in a transaction that is rolled back)

**Additional objection**: The overview’s “whitelisted commands” list includes `rm`.
- Recommendation: remove `rm` entirely from v1; if ever needed, restrict to `rm` within `tmp/agent_sandbox/` only.

**Question**: Do we really need runtime eval for CWA in v1, or can schema intel come from:
- `db/schema.rb` parsing
- Rails model reflection via precomputed metadata

### D) Self-debug loop (0040)

**Comment**: This aligns well with Agent-05’s philosophy (“AI commits locally; human pushes/merges”).

**Objection**: “rubocop -a” is a write operation. It can be safe, but it’s still an automated modification.

**Alternative**:
- In v1, run `rubocop` only (no auto-correct) and ask CWA to propose patches; then execute if allowed.
- Or allow `rubocop -A` only for a narrow set of cops and only under explicit approval.

### E) Testing strategy

**Comment**: Both Agent-05 and Agent-06 mention VCR. Based on our spike experience, deterministic tests should prefer **WebMock stubs** for OpenAI-shaped responses.

**Recommendation**:
- For Agent-06 tools: unit tests should stub `Process.spawn` / command output and assert parsing/allowlist.
- Only do VCR when absolutely needed, and only with stable endpoints.

---

## Alignment with Agent-05 plan: do we need to modify it?

### What looks good (no change needed)
Agent-05 resequencing is still correct and safe:
`0050A (spike/runner) → 0050B (feedback/guardrails) → 0050E (planning) → 0050C (tools) → 0050D (UI)`.

**Naming convention note**: If the repo standard is now numeric PRDs (`0010–0050`), we should update the Agent-05 epic/prds to match that convention before starting `0050B` work, to avoid confusion in branch naming, logs, and tool prompts.

### Suggested minor updates to Agent-05 docs (optional)
These are not blockers, but would improve future alignment:

1) **Add a note that model discovery should ultimately come from SmartProxy**
- Since SmartProxy now has `GET /v1/models`, Agent-05 could note “preferred source of truth = SmartProxy model list; ENV fallback.”

2) **Explicitly treat Agent-06 as “post-0050C extensions”**
- If Agent-06 stays separate, add a dependency note: Agent-06 depends on `0050C` (CWA tooling baseline) and `0050E` (micro-task schema).

---

## Concrete doc fixes for Agent-06 (recommended)

1) Update all references to “Claude via SmartProxy” to “not yet implemented” until SmartProxy adds it.
2) Add an explicit safety policy section (mirrors Agent-05):
   - out-of-process sandbox
   - deny-by-default allowlist
   - no network
   - AI commits locally only
   - human push/merge
3) Remove/limit destructive commands from stated capability lists (`rm` especially).
