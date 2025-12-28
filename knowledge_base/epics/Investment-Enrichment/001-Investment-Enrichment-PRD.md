## 001-Investment-Enrichment-PRD.md

#### Overview
This PRD defines an atomic feature for enriching investment data locally, aligning with the Nextgen-Plaid vision of Private Financial Data Sync. It enables high-net-worth (HNW) families to augment their synced investment holdings with additional metadata (e.g., risk assessments or performance metrics) processed entirely on-device using local Ollama models, ensuring privacy and seamless synchronization without external dependencies.

#### Log Requirements
(Read junie-log-requirement.md)

#### Requirements
**Functional Requirements:**
- Provide a local endpoint `/investments/enrich` that accepts a list of investment holdings and returns enriched data (e.g., adding fields like volatility score or sector classification).
- Use local Ollama/Python scripts to perform enrichment computations, pulling from pre-synced local data sources only.
- Support input formats from existing synced data (e.g., JSON objects with fields like symbol, quantity, and current value).
- Output enriched data in a standardized JSON format, including original data plus new enriched fields.

**Non-Functional Requirements:**
- Ensure all processing occurs locally with no network calls for data enrichment to maintain privacy.
- Performance: Enrichment for up to 100 holdings should complete in under 5 seconds on standard hardware.
- Security: Encrypt temporary data during processing and ensure no persistent storage of enriched results outside user-controlled local databases.
- Compatibility: Integrate with Rails MVC patterns, using existing models for investments.

#### Architectural Context
- **MVC References:** Controller: `InvestmentsController` with a new `enrich` action. Model: Extend `Investment` model with enrichment methods. View: Not applicable (API endpoint only; results can be rendered via existing views if needed).
- **Schema:** Add optional fields to the `investments` table schema (e.g., `enriched_volatility decimal`, `enriched_sector string`) via a migration, but enrichment is computed on-the-fly without altering core schema permanently.
- **Local AI:** Leverage local Ollama models (e.g., via Python scripts in `/lib/enrichment_scripts/`) for AI-driven enrichment, such as natural language processing on holding descriptions or basic ML for risk scoring. All execution happens in a local Python environment integrated with Rails via system calls.

#### Acceptance Criteria
- The `/investments/enrich` endpoint accepts a POST request with a JSON payload of holdings and returns a 200 OK with enriched JSON output.
- Enrichment adds at least two new fields (e.g., risk score and sector) computed locally without external APIs.
- No data is sent to or processed in the cloud; all operations are verifiable as local via logs.
- Handles edge cases like empty holdings list, returning an empty enriched array.
- Integrates with existing authentication to ensure only authorized users can access enrichment.
- Enrichment results are consistent across multiple runs with the same input data.
- Fails gracefully with a 400 error if input data is malformed (e.g., missing symbol field).

#### Test Cases
**Unit Tests:**
- Test `Investment` model method for single holding enrichment (e.g., assert volatility score calculation).
- Verify Python script isolation: Mock Ollama calls to ensure no network leakage.

**Integration Tests:**
- End-to-end API test: POST to `/investments/enrich` with sample data and validate enriched response structure.
- Test with Rails authentication: Ensure unauthenticated requests are rejected.

**System Tests:**
- Performance test: Measure time for enriching 100 holdings on a local setup.
- Privacy audit: Run system in debug mode to confirm no outbound network requests during enrichment.

#### Workflow
1. `git checkout -b feature/001-investment-enrichment`
2. Implement changes in relevant files (e.g., controllers/investments_controller.rb, models/investment.rb, lib/enrichment_scripts/enrich.py).
3. Add tests in spec/ (e.g., spec/controllers/investments_controller_spec.rb).
4. Run `bundle exec rspec` and ensure all tests pass.
5. Commit with message: "Implement 001-Investment-Enrichment feature"
6. Push branch: `git push origin feature/001-investment-enrichment`
7. Create PR on GitHub targeting main branch.