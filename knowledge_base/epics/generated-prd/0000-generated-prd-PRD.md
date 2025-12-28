## AGENT-02C-Replace-FS-with-Solid-Queue-Jobs-PRD.md

#### Overview
This PRD outlines the replacement of filesystem operations with Solid Queue jobs to store SAP artifacts in `knowledge_base/epics/` and handshakes, ensuring resilience without concurrent issues. This change aims to improve system reliability and scalability by leveraging job queuing.

#### Acceptance Criteria
- The system stores SAP artifacts in a message queue (Solid Queue) instead of the filesystem.
- Solid Queue jobs are created for storing SAP artifacts in `knowledge_base/epics/` and handshakes.
- Git operations with dirty state stash are implemented to ensure auto-update statuses without concurrent issues.
- Backlog ties are established for automatic status updates.
- The system can handle a high volume of SAP artifact storage requests without experiencing concurrency issues.
- A fallback mechanism is in place to handle failed Solid Queue jobs.
- Artifact storage and retrieval operations are idempotent.

#### Architectural Context
- **Service/Model**: `SapArtifactJob` (a new model for storing SAP artifacts), `SolidQueue` gem, `GitOps` service.
- **Dependencies**: Solid Queue gem, Git library, Rails MVC framework.
- **Data Flow**:
    1. The system generates an SAP artifact.
    2. A Solid Queue job is created to store the SAP artifact in `knowledge_base/epics/` or handshakes.
    3. The job executes and stores the artifact.
    4. Git operations are performed with dirty state stash to ensure auto-update statuses.

#### Test Cases
- **TC1**: Store an SAP artifact in `knowledge_base/epics/` using a Solid Queue job and verify its presence.
- **TC2**: Simulate concurrent storage requests for multiple SAP artifacts and verify that no concurrency issues occur.
- **TC3**: Intentionally fail a Solid Queue job storing an SAP artifact and verify that the fallback mechanism is triggered.
- **TC4**: Perform Git operations with dirty state stash and verify auto-update statuses without concurrent issues.
- **TC5**: Store an SAP artifact in handshakes using a Solid Queue job and verify its presence.