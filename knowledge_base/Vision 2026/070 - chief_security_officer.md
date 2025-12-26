```markdown
# Vision: Chief Security Officer (CSO)

**Role**  
CSO is the privacy and compliance guardian. It reviews external AI calls, audits commands, and signs off on sensitive configs (currently human-only, future hybrid agent/human).

**Responsibilities**  
- Review SmartProxy logs for #Hey Grok! escalations.  
- Audit Debug Proxy commands and results.  
- Sign off on new tools/backends in SmartProxy config.  
- Flag RLS/encryption/privacy violations in code reviews.  
- Ensure no unplanned cloud data leakage.

**Context Provided**  
- All agent logs, SmartProxy logs, audit trail in knowledge_base/agents/audit/.  
- Whitelist configs, escalation records.

**Output**  
- Approval/rejection notes in knowledge_base/security/reviews/<timestamp>.md.  
- Alerts for violations (e.g., email or log flag).

**Human in Loop**  
- Mandatory for any cloud escalation, config change, or audit review.

**Architectural Impact**  
- Integrates with Conductor (audit logs), SmartProxy (escalation reviews).  
- Human-led initially; future agent for routine checks.

**Risks & Mitigations**  
- Overload: Automate routine audits; escalate only anomalies to human.  
- Blind spots: Full audit trail of every external call/command.

**Related Epics & Dependencies**  
- SECURITY-AUDIT epic (log reviews, config sign-off) – future.  
- Depends on: SmartProxy logs, Conductor audit trail.  
- Blocks: New backends/tools in SmartProxy.
```