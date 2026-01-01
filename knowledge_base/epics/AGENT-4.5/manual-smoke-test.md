### Manual smoke test — AGENT-4.5 bare-metal streaming chat

This is a quick manual validation checklist for `/admin/sap_collaborate`.

#### Prereqs
1. **DB migrated**
   - Ensure migrations are applied:
     - `bin/rails db:migrate`

   - If using Solid Cable (recommended for dev streaming from a separate worker), also migrate the `cable` DB:
     - `bin/rails db:migrate:cable`

2. **SmartProxy running**
   - Dev: SmartProxy should be reachable at `http://localhost:3001/proxy/generate`
   - Test: `http://localhost:3002/proxy/generate`
   - If you use a full URL, set `SMART_PROXY_URL`.
   - If you use a port, set `SMART_PROXY_PORT`.
   - **For smoke testing against SmartProxy on `3002`**, use Grok routing:
     - `SMART_PROXY_PORT=3002 SAP_CHAT_MODEL=grok-4`

3. **Background jobs running (Solid Queue)**
   - In a separate terminal:
     - `bin/rails solid_queue:start`

4. **ActionCable endpoint present**
   - Confirm ActionCable is mounted and reachable at:
     - `GET /cable`
   - (Turbo Streams require a websocket connection to `/cable`.)

5. **Rails server running**
   - `bin/rails server`

#### Smoke checklist (happy path)
1. **Login** as an admin/owner user.
2. Visit `GET /admin/sap_collaborate`.
   - Expected: page loads with an empty chat stream and a sticky textarea + Send button.
3. Submit a prompt like: `"Say 'OK' then count to 5."`
   - Expected immediately:
     - a **user** bubble appears on the right
     - an **assistant** bubble appears on the left with `Thinking...`
4. Observe streaming:
   - Expected: the assistant bubble **updates in-place** (Turbo `replace`) as content grows.
   - Expected: **no duplicate assistant bubbles** (i.e., no “append per chunk”).
   - DevTools: you should see a WebSocket connection to `/cable` (Turbo Streams subscription).
5. Auto-scroll:
   - Expected: the stream scrolls to the newest content on each update.
6. Refresh the page.
   - Expected: the current run’s messages are still visible (messages persisted).

#### Smoke checklist (validation + error path)
1. Submit an empty prompt.
   - Expected: an assistant bubble appears with an error message (no crash).
2. Stop SmartProxy and submit a prompt.
   - Expected: the assistant bubble updates to something like `Error: ... (ID: <uuid>)`.

#### Quick command-line sanity checks
These checks don’t validate browser-side Turbo behavior, but confirm the core wiring:

1. Create a run + messages:
   - `bin/rails runner 'u=User.first; r=SapRun.create!(user:u, correlation_id:SecureRandom.uuid, status:"running", started_at:Time.current); r.sap_messages.create!(role: :user, content:"hi"); r.sap_messages.create!(role: :assistant, content:"hello"); puts r.sap_messages.count'

2. Job test (fast):
   - `bin/rails test test/jobs/sap_agent_job_test.rb`
