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