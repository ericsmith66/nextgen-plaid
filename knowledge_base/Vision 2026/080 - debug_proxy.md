```markdown
# Vision: Debug Proxy

**Role**  
Debug Proxy is the safe gateway for agent debugging. It allows agents (e.g., CWA) to request read-only command execution without direct shell access, enforcing security while enabling self-fixing loops.

**Responsibilities**  
- Accept debug requests from agents (e.g., "tail log/development.log" or "Transaction.count").  
- Check against whitelist (read-only: cat, grep, ls, rails r, ps; no rm, sudo, git push).  
- Execute via Conductor (sandboxed, local only).  
- Return stdout/stderr to agent via file/response.  
- Log every request/execution to knowledge_base/agents/audit/.  
- Reject non-whitelisted commands with error.

**Context Provided**  
- Whitelist config (config/agent_commands.yml).  
- Request details from agent (command, env).

**Output**  
- Command result (text or error) in work/debug_responses/<request-id>.result.

**Human in Loop**  
- Configures whitelist; reviews audit logs via Chief Security Officer.

**Architectural Impact**  
- Part of Conductor (proxy logic in app/services/debug_proxy_service.rb).  
- Integrates with queue/filesystem for requests.  
- No direct DB writes; read-only focus.

**Risks & Mitigations**  
- Overreach: Strict whitelist; audit all.  
- Performance: Limit concurrent requests to 5.

**Related Epics & Dependencies**  
- Part of CONDUCTOR epic.  
- Depends on: Conductor running, whitelist config.  
- Blocks: Safe agent debugging.
```