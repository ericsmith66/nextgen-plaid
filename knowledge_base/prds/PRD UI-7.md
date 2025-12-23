**PRD: UI-7 – Beautiful Tables with Readability Fixes**

**Overview**  
Enhance table rendering in the Mission Control dashboard and other views to ensure high readability for HNW users (22-30), fixing dark gray on black font issues by applying consistent Tailwind/DaisyUI styles with light text on dark backgrounds or high-contrast alternatives. This supports the vision by providing professional, accessible data views for wealth simulations without visual strain.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` for logging standards (e.g., structured JSON logs via Rails.logger for style updates/tests, audit trails with user_id/timestamp if any dynamic theming).

**Requirements**
- **Functional**:
    - Update ViewComponent for tables (e.g., TableComponent in app/components): Set default Tailwind classes for high contrast (e.g., text-white or text-gray-200 on bg-gray-800; hover:bg-gray-700 for rows). Use DaisyUI themes (e.g., 'dark' mode with overrides for table cells: prose-invert for light text).
    - Fix specific issues: Change font color from dark gray (#4B5563) to light gray (#D1D5DB) or white (#FFFFFF) on black/dark backgrounds (#000000 or #1F2937). Add zebra striping (table-zebra) and borders (border-collapse). Support sorting/pagination via simple_table (gem if needed) or custom JS (no heavy libs).
    - Accessibility: Ensure WCAG AA compliance (contrast ratio >4.5:1 via Tailwind opacity/contrast utilities); add aria-labels for headers/cells.
    - Apply to key views: Holdings/transactions in Mission Control (mission_control_component.html.erb); fallback for other tables (e.g., internship_tracker).
- **Non-Functional**:
    - Performance: No added JS overhead; pure CSS for styling. Compile Tailwind in production for minification.
    - Rails Guidance: Use rails g component Table headers:array data:array; extend with Tailwind config (tailwind.config.js: extend colors/themes). Tests: Capybara for visual assertions (e.g., have_css '.text-white').

**Architectural Context**  
Builds on Rails MVC: Update ViewComponents for reusable tables; integrate with Tailwind/DaisyUI (already in stack). PostgreSQL data remains unchanged; focus on presentation layer. For AI: No direct impact, but improved tables enhance dashboard snapshots for AiFinancialAdvisor prompts (e.g., "Summarize holdings table" with context from JSON blobs + 0_AI_THINKING_CONTEXT.md). Reference schema: Irrelevant (UI-only). Avoid vector DBs—stick to static styles.

**Acceptance Criteria**
- Tables render with light text (e.g., #FFFFFF) on dark backgrounds; no dark gray visible (inspect via dev tools).
- Contrast passes AA (use browser extensions to verify >4.5:1 ratio).
- Sorting/pagination works (click header → rows reorder; >10 rows → paginates).
- Zebra striping and borders applied; hover states highlight rows cleanly.
- Accessibility: Screen reader reads headers/cells correctly (aria attributes present).
- Applies to all tables (e.g., holdings, transactions); no regressions in existing views.
- Dark mode preserved but readable; optional light mode toggle if time allows.

**Test Cases**
- Unit (Minitest): TableComponent.new(headers: [...], data: [...]).render → expect(html).to have_css('td.text-white.bg-gray-800').
- Integration (Capybara): visit '/mission_control' → expect(page).to have_css('table.table-zebra td.text-gray-200'); click header → expect sorted order; check contrast via custom assertion. WebMock unnecessary (UI-only).

**Workflow**  
Junie: Ask questions/build plan first. Pull from main, branch `feature/ui-7-beautiful-tables`. Use Claude Sonnet 4.5. Commit only green code (run minitest, rubocop). Merge to main post-review.

Next steps: Junie, confirm specific tables to prioritize (e.g., holdings first)? Proceed with implementation? Questions on DaisyUI theme overrides?

### PRD UI-7 Review Response
Acknowledged—strong review; agree with clarifications on ARIA (native + scope/aria-sort), hover/focus (add focus-visible:ring), print stylesheet (add low-cost @media print for light inversion), and risks (scope styles to component, server-side for large tables).

Corrections/Clarifications:
1) Sorting/pagination: Approved—use Stimulus for client-side on small tables (<50 rows); server-side params (?sort=col&dir=asc) for larger. No heavy libs.
2) Component API: Approved as proposed—explicit props for headers (with sortable flag), rows, pagination, sort, row_href proc.
3) Theming/contrast: Approved CSS vars in tailwind.config.js (e.g., --table-bg: #1f2937, --table-fg: #e5e7eb); explicit text classes over prose-invert to avoid regressions.
4) ARIA: Approved—focus on native table semantics + scope="col" and aria-sort on headers.
5) Hover/focus: Approved—keyboard equivalents via focus-visible.
6) Print/light mode: Add print stylesheet; defer light toggle but ensure dark defaults pass contrast in OS modes.
7) Test strategy: Approved—add keyboard nav spec; use Capybara for assertions.

Targeted Questions:
- Prioritization: Start with holdings (simpler), then transactions.
- Pagination gem: No existing (confirmed via repo browse); add Pagy (lightweight, acceptable).
- Sort scope: Yes—standardize server-side via query params for all, to handle large datasets safely.
- Branding constraints: None—text-white on bg-gray-800 is fine; stick to neutral grays/blues for professional HNW feel.

Implementation Plan Adjustments: Approved with above (e.g., Pagy integration, server-side sorting, print stylesheet). Update acceptance criteria as suggested (add server-side for >50 rows, ARIA/keyboard for headers).

Next steps: Proceed on `feature/ui-7-beautiful-tables` with Claude Sonnet 4.5; pull/rebase from main first. Ask any remaining questions here before coding. Commit green only (minitest/rubocop); open PR to main post-tests.