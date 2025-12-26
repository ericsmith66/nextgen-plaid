```markdown
# Vision: Senior Advisory Partner (SAP) Agent

**Role**  
SAP is the strategic planner and reviewer. It generates PRDs/epics from backlog items, performs code reviews on CWA output, and advises on architecture/privacy/curriculum alignment.

**Responsibilities**  
- Read backlog (knowledge_base/backlog/current.csv or flagged file).  
- Write PRDs/epics in exact template to knowledge_base/prds/draft/.  
- Perform code reviews (diff + tests + logs) for MVC cleanliness, test coverage, privacy compliance, Plaid correctness, green readiness.  
- Answer direct questions (e.g., "Is this endpoint best practice?").  
- Escalate research with #Hey Grok! → SmartProxy → Grok + tools.  
- Never commit Git, run migrations, or touch production data.

**Context Provided**  
- Full reviewed PRDs, codebase summary, schema, static docs (0_AI_THINKING_CONTEXT.md, PRODUCT_REQUIREMENTS.md).  
- For code review: PRD + git diff + test output + recent logs.

**Output**  
- Draft PRDs/epics → draft/ folder.  
- Review comments → knowledge_base/agents/sap/review-<timestamp>.md.

**Human in Loop**  
- You move draft → reviewed (or reject).  
- You approve major architecture decisions.

**Architectural Impact**  
- Integrates with SmartProxy for escalations, Conductor for routing, RAG for context.  
- Runs as job or script, local Ollama default.

**Risks & Mitigations**  
- Hallucination: Use Python calcs for tax/law; RAG for code facts.  
- Privacy: No auto-escalation.

**Related Epics & Dependencies**  
- SMART-PROXY (for #Hey Grok! escalation).  
- Planned SAP-PRD-WRITER epic (backlog reading → draft drop).  
- Depends on: SmartProxy routing, reviewed PRD folder structure.  
- Blocks: Autonomous PRD generation.
```

Next steps: Add this to `knowledge_base/vision/sap_agent.md`? Ready for the next vision doc content (e.g., conductor.md)?