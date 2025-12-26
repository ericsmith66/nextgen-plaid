```markdown
# Vision: Explicit Escalation Gateway (Smart Proxy)

**Role**  
Smart Proxy is the simple, local-first router for AI calls. It handles explicit escalations from agents to external backends (e.g., Grok) while enforcing privacy rules.

**Responsibilities**  
- Accept POST /prompt with { message: ... }.  
- If message contains #Hey Grok!, forward to Grok with tools (web_search, x_search, browse_page) and RAG context.  
- Return JSON response; reject non-escalated requests with 400.  
- Log all calls to log/smart_proxy.log (timestamp, status, redacted message).  
- Support multiple backends via config/smart_proxy_backends.yml (e.g., grok, local_x).  
- Runs on configurable local port (default 11435 to avoid Ollama conflict).  
- Never auto-escalate; explicit #Hey <backend>! only.

**Context Provided**  
- Prompt message + RAG chunks (if integrated).  
- Configured API keys (e.g., GROK_API_KEY from .env).

**Output**  
- JSON from backend or error response.

**Human in Loop**  
- Config changes (new backends) require Chief Security Officer review.

**Architectural Impact**  
- Standalone Rack app (no Rails dependency for speed).  
- Integrates with agents via HTTP wrapper (e.g., AiFinancialAdvisor calls it).  
- Future: Add backend for Claude/Anthropic via YAML config.

**Risks & Mitigations**  
- Privacy leak: Reject non-explicit calls; redact logs.  
- Downtime: Fallback to local Ollama if backend fails.

**Related Epics & Dependencies**  
- SMART-PROXY epic (0010-Submodule → 0070-Monitoring) – primary.  
- Depends on: None (can start anytime).  
- Blocks: SAP research escalation, Conductor Grok calls.
```

Next steps: Add this to `knowledge_base/vision/smart_proxy.md`? Ready for the next vision doc content?