### 0012-Epics-PRD.md

#### Overview
This PRD implements the `EpicStrategy` for the unified `SapAgent::ArtifactCommand` engine. It enables SAP to generate structured Epic overviews that group related atomic PRDs, define success criteria, and maintain a backlog stub. It ensures all epics align with the project vision in `MCP.md`.

#### Log Requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`. All epic generations must be logged in `agent_logs/sap.log`. Include metadata injection and validation details.

#### Requirements
**Functional Requirements:**
- **EpicStrategy**: Implement as a module included in `ArtifactCommand`.
- **Skeleton Integration**: Use `templates/epic.md.erb` as the mandatory structural skeleton.
- **Dynamic Metadata**: Ruby pre-populates the template with:
    - current date and version.
    - vision summary from `MCP.md`.
    - list of existing PRDs (regex scan of IDs in `knowledge_base/epics/[slug]/`).
- **AI Content Generation**: AI populates the remaining sections: Overview, Success Criteria, Capabilities Built, and Backlog Table Stub.
- **Validation**: Ruby validates that all required sections (Overview, Success Criteria, etc.) are present in the AI output before writing.
- **Storage**: Write to `knowledge_base/epics/[slug]/0000-Epic-Overview.md`.

**Non-Functional Requirements:**
- Performance: Template rendering <50ms.
- Security: Sanitize slug and filenames to prevent injection.
- Privacy: All vision ingestion and processing is local.

#### Architectural Context
Inherit from `SapAgent::ArtifactCommand`. Use the Strategy pattern to switch logic during `execute`. Reference `knowledge_base/epics/` for directory management (create if missing).

#### Acceptance Criteria
- `ArtifactCommand` correctly instantiates `EpicStrategy`.
- AI output is constrained by the `epic.md.erb` skeleton.
- Vision from `MCP.md` is correctly injected into the overview.
- Existing PRDs are detected and listed automatically.
- Validation rejects outputs missing the "Success Criteria" or "Capabilities" sections.

#### Test Cases
- Unit (RSpec): `EpicStrategy` correctly scans for PRD IDs; template renders with mock metadata.
- Integration: Full generation flow with VCR; verify file exists in `knowledge_base/epics/test-epic/`.
- System: Submit "Create epic for investment enrichment" -> verify vision-aligned overview and PRD list.

#### Workflow
Junie: Use Claude Sonnet 4.5. Pull from master, branch `feature/0012-epic-strategy`. Ask questions about PRD grouping regex. Implement in atomic commits. PR to main.

