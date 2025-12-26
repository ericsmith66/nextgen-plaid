```markdown
# Vision: Conductor Agent

**Role**  
Conductor is the traffic director and safety gate. It routes tasks between agents, moves files, enqueues jobs, and executes privileged operations like debug proxy.

**Responsibilities**  
- Watch for new reviewed PRDs → notify/trigger CWA.  
- Promote files on approval (draft → reviewed).  
- Run Debug Proxy (whitelisted read-only commands).  
- Enqueue recurring jobs (daily sync, snapshots).  
- Write cross-agent audit logs.  
- Future: Git push/merge on final human green-light.  
- Never reason or generate content—only move/execute.  
- Runs via Solid Queue recurring task (every 5 min poll) or file watcher (TBD).

**Context Provided**  
- All knowledge_base paths, queue status, whitelist config.

**Output**  
- File moves, job enqueues, audit logs in knowledge_base/agents/conductor/.

**Human in Loop**  
- Only for final merge or overrides.

**Architectural Impact**  
- Integrates with SmartProxy (routing), Solid Queue (jobs), Debug Proxy (commands).  
- Standalone or job-based, local execution only.

**Risks & Mitigations**  
- Bottleneck: Keep lightweight, no state beyond queue.  
- Security: Strict whitelist for commands; audit every action.

**Related Epics & Dependencies**  
- CONDUCTOR epic (file moving, queue watching, debug proxy).  
- Depends on: SmartProxy (for escalation routing), Solid Queue setup.  
- Blocks: Full agent automation, debug safety.
```

Next steps: Ready for the next vision doc content (e.g., rag.md)? Or any adjustments to this one?