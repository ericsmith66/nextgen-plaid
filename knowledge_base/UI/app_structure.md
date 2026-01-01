## NextGen Wealth Navigation Tree (with Page Descriptions)

- **Home (Landing)** – Public / Sign-in: The entry page for unauthenticated users, providing sign-up/login forms and a brief overview of the app's purpose (financial sync for HNW individuals).

- **Dashboard (Logged In)**: User's main hub showing net worth summary, recent transactions, and quick links to accounts/holdings/insights—designed for at-a-glance financial pulse.

    - Net Worth Ring (pulse): Visual ring chart displaying total net worth with breakdowns (assets/liabilities), allowing hover for details.
    - Quick Actions
        - Accounts → List / Balances: Table of linked accounts with current balances and sync status, for monitoring cash flow.
        - Holdings → Chart + Growth: Interactive chart of investment holdings with growth trends over time, for portfolio review.
        - Insights → AI One-Liner → Detail: AI-generated one-sentence advice (e.g., "Rebalance tech overweight") expanding to full RAG-based insights.
    - Gearbox (Settings): Configuration menu for user preferences like brokerage keys, Plaid env, alerts, and exports—hidden to keep dashboard clean.
    - Logout: Simple sign-out link, redirecting to home with session clearance.

- **Admin Panel**: Admin-only overview for managing users and system health, with access to all scoped data.

    - Users (Select): Dropdown to select users for admin view, showing last sync/activity; enables scoping to individual data.
        - User: – Last Sync: Per-user dashboard with sync timestamp and error alerts, for troubleshooting.
            - Accounts (Table + Export + Re-sync): Paginated table of user accounts with balances/export CSV/re-sync button, for admin monitoring.
            - Holdings (Chart + CSV): Chart of user holdings with CSV export, for portfolio admin review.
            - Liabilities (Table): Table of user liabilities (e.g., loans/credit), for debt oversight.
            - Transactions (Pag 20 + Categorize Button): Paginated (20 rows) transaction list with categorize button, for detailed activity admin.
    - Sync Log (Admin-wide): Paginated log of all sync events across users, for system-wide error tracking and debugging.
    - Audit Log: Paginated audit trail of admin actions and agent runs, for compliance and history review.
    - Mission Control: Admin hub for SAP oversight with live chat, controls, and agent workflow tracking.
        - Chat Stream (Live, user-scoped): Streaming chat for interactive SAP runs, scoped to selected user for context-aware oversight.
            - Task Input (Pinned bottom): Fixed input for task entry, with correlation/ID display for traceability.
            - Correlation / Idempotency Display: Subtle display of run IDs for debugging without clutter.
        - Controls (Gear): Menu for model/iteration/token overrides and Heartbeat probe, for per-run tweaks.

Next steps: Commit this as knowledge_base/app_structure.md for RAG? Add to vision.md? Questions: Specific pages to expand (e.g., more on Insights AI)?