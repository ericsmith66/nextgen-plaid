### 0015-PRDs-PRD.md

#### Overview
This PRD implements the `PrdStrategy` for the unified `SapAgent::ArtifactCommand` engine. It enables SAP to generate atomic, high-quality PRDs using an ERB-driven skeleton that enforces structural integrity (Overview, AC count, etc.) and project vision alignment.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All PRD generations must be logged in `agent_logs/sap.log`. Include metadata injection and validation details.

#### Requirements
**Functional Requirements:**
- **PrdStrategy**: Implement as a module included in `ArtifactCommand`.
- **Skeleton Integration**: Use `templates/prd.md.erb` as the mandatory structural skeleton.
- **Dynamic Metadata**: Ruby pre-populates the template with:
    - current date and version.
    - vision tie-in from `MCP.md`.
    - project-specific context (e.g., Plaid schema references).
- **AI Content Generation**: AI populates the remaining sections: Overview, Functional/Non-Functional Requirements, Architectural Context, 5-8 Acceptance Criteria bullets, Test Cases, and Workflow.
- **Validation**: Ruby validates that the AC count is between 5 and 8 and that all sections are present before writing.
- **Storage**: Write to `knowledge_base/epics/[slug]/[id]-[title]-PRD.md`.

**Non-Functional Requirements:**
- Performance: PRD generation <150ms (excluding AI latency).
- Security: Sanitize all AI-generated content to prevent Markdown injection.
- Privacy: All vision ingestion and processing is local.

#### Architectural Context
Inherit from `SapAgent::ArtifactCommand`. Use the Strategy pattern to switch logic during `execute`. Integrate with `SapAgent::Router` for cost-effective execution (Grok for PRDs).

#### Acceptance Criteria
- `ArtifactCommand` correctly instantiates `PrdStrategy`.
- AI output is constrained by the `prd.md.erb` skeleton.
- Vision from `MCP.md` is correctly injected into the overview.
- Validation rejects outputs with fewer than 5 or more than 8 AC bullets.
- Validation rejects outputs missing the "Architectural Context" or "Test Cases" sections.

#### Test Cases
- Unit (RSpec): `PrdStrategy` correctly counts AC bullets; template renders with mock metadata.
- Integration: Full generation flow with VCR; verify file exists and is correctly named.
- System: Submit "Create PRD for transaction sync" -> verify vision-aligned overview and exactly 5-8 AC bullets.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0015-prd-strategy`. Ask questions about ID/slug generation. Implement in atomic commits. PR to main.
