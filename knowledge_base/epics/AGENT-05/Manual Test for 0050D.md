# Manual Test for 0050D (Admin UI: `/admin/ai_workflow`)

This is a **manual QA checklist** for PRD `AGENT-05-0050D`.

## Preconditions
- You have a local **admin** user account you can log into.
- The app boots locally.
- (Per your note) both the **proxy** and **Ollama** are already running.

## 1) Start the Rails app

### Command
```bash
cd /Users/ericsmith66/development/nextgen-plaid
bin/dev
```

### Expected result
- Rails starts successfully.
- You can load the site in a browser (typically `http://localhost:3000`).

> If you don’t use `bin/dev` in this repo, use whatever you normally run (e.g., `bin/rails s`).

## 2) Verify route exists (sanity check)

### Command
```bash
cd /Users/ericsmith66/development/nextgen-plaid
bin/rails routes | grep admin_ai_workflow
```

### Expected result
You should see a line similar to:
```
admin_ai_workflow GET /admin/ai_workflow(.:format) admin/ai_workflow#index
```

## 3) Verify access control (admin-only)

### Step
1. In a browser, log in as a **non-admin** user (or temporarily impersonate one).
2. Visit:
   - `http://localhost:3000/admin/ai_workflow`

### Expected result
- You receive **HTTP 403 Forbidden**.

### Step
1. Log in as an **admin** user.
2. Visit:
   - `http://localhost:3000/admin/ai_workflow`

### Expected result
- Page loads successfully.
- If there are no artifacts yet, you should see an empty-state banner message:
  - `No active workflow artifacts found.`

## 4) Generate a real workflow run (creates artifacts)

This uses the built-in rake task `ai:run_request`, which calls `AiWorkflowService.run`.

### Command
```bash
cd /Users/ericsmith66/development/nextgen-plaid

# Optional: choose a model if your setup requires it
# export AI_MODEL=qwen2.5:14b

bundle exec rake "ai:run_request[Give me a short summary of what this app does and the key models involved.]"
```

### Expected result
- The command runs and prints something like:
```
correlation_id=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
ball_with=coordinator
output:
...
```
- Save the printed `correlation_id` value.

### Expected artifact files
After it runs, a new directory should exist:
```
agent_logs/ai_workflow/436096a6-7ae9-4ac8-9c19-2ad582f4bf5a/
```
And should include at least:
- `run.json`
- `events.ndjson` (may exist depending on what the workflow emitted)

You can verify with:
```bash
cd /Users/ericsmith66/development/nextgen-plaid
ls -la agent_logs/ai_workflow/<correlation_id>/
```

Expected result: `run.json` exists (and typically `events.ndjson`).

## 5) Verify populated UI (Ownership / Context / Logs)

### Step
As admin, visit (replace with your correlation id):

```
http://localhost:3000/admin/ai_workflow?correlation_id=26ed0fcd-6898-4621-bb18-d4e6f4ce14eb
```

### Expected result (Banner)
- The banner shows:
  - `Correlation: <correlation_id>`
  - `Ball with: ...`
  - `State: ...`
  - `Status: ...`

### Step (Ownership tab)
1. Click the `Ownership` tab (or use `tab=ownership`).

Expected:
- You see:
  - `Ball with` value
  - `State` value
  - `Started` and optionally `Finished`
- If `feedback_history` exists, you see a list.

### Step (Context tab)
1. Click the `Context` tab (or use `tab=context`).

Expected:
- A table of context keys/values.
- Complex values render as pretty JSON.

### Step (Logs tab)
1. Click the `Logs` tab (or use `tab=logs`).

Expected:
- A list of log events rendered as pretty JSON blocks.
- A line that includes something like:
  - `Showing X of Y events`

## 6) Verify log pagination

### Step
On the `Logs` tab:
1. Click `Next` (or append `events_page=2`).

Example URL:
```
http://localhost:3000/admin/ai_workflow?tab=logs&correlation_id=<correlation_id>&events_page=2
```

### Expected result
- Page number increments.
- Different log entries appear (when there are more than 100 events loaded).
- `Prev` becomes enabled on page 2.

> Note: The UI loads at most the last ~500 events from `events.ndjson`, then paginates 100 per page.

## 7) Verify empty-state still works (optional)

If you want to re-check empty-state behavior:

### Command (temporary move artifacts)
```bash
cd /Users/ericsmith66/development/nextgen-plaid
mv agent_logs/ai_workflow agent_logs/ai_workflow.bak
```

### Step
Visit:
```
http://localhost:3000/admin/ai_workflow
```

### Expected result
- Shows:
  - `No active workflow artifacts found.`

### Cleanup
```bash
cd /Users/ericsmith66/development/nextgen-plaid
mv agent_logs/ai_workflow.bak agent_logs/ai_workflow
```

## 8) Pre-push verification

### Command
```bash
cd /Users/ericsmith66/development/nextgen-plaid
git status --porcelain
bin/rails test
```

### Expected result
- `git status --porcelain` is empty (or only shows the files you expect to commit).
- Tests complete with **0 failures** and **0 errors**.
