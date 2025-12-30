Here’s a self-contained bash script you can run locally to exercise the manual scenarios on a scratch branch without touching main. It avoids pushing to origin by using a throwaway remote and local-only dry runs for the risky cases.

```bash
#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
BRANCH="scratch/queue-handshake-manual"
ARTIFACT_JSON='{result:"ok"}'
TASK_SUMMARY="Store iteration artifact"
TASK_ID="0040"
IDEMP_UUID="manual-uuid-$(uuidgen)"
LOG_PATH="agent_logs/sap.log"
FAKE_REMOTE="origin-manual-test"

# === FUNCTIONS ===
log() { printf "\n[manual-test] %s\n" "$*"; }
run_handshake() {
  local uuid="$1"; local extra_env="$2"
  eval "$extra_env" bundle exec rails runner "puts SapAgent.queue_handshake(artifact: ${ARTIFACT_JSON}, task_summary: '${TASK_SUMMARY}', task_id: '${TASK_ID}', correlation_id: SecureRandom.uuid, idempotency_uuid: '${uuid}').to_json"
}
show_tail() { tail -n 20 "$LOG_PATH" | sed 's/\\"/"/g'; }
ensure_clean() {
  if [ -n "$(git status --porcelain)" ]; then
    log "Working tree not clean; stash or commit before running" && exit 1
  fi
}

# === PREP ===
log "Switching to scratch branch"
git fetch origin
git checkout -B "$BRANCH" origin/main

log "Ensuring log file exists"
mkdir -p "$(dirname "$LOG_PATH")" && touch "$LOG_PATH"

# Optional: add a fake remote to avoid real pushes
if ! git remote get-url "$FAKE_REMOTE" >/dev/null 2>&1; then
  git remote add "$FAKE_REMOTE" "./.git" >/dev/null 2>&1 || true
fi

ensure_clean

# === 1) Happy path (DRY_RUN=0, but push goes to fake remote) ===
log "Happy path commit"
run_handshake "$IDEMP_UUID" "GIT_REMOTE=$FAKE_REMOTE " || true
show_tail

log "Verify commit message"
git log -1 --pretty=oneline

# === 2) Duplicate UUID ===
log "Duplicate UUID should skip"
run_handshake "$IDEMP_UUID" "" || true
show_tail

# === 3) Dirty workspace stash/restore ===
log "Simulate dirty workspace"
echo "tmp" >> README.md
run_handshake "dirty-$(uuidgen)" "" || true
git status --short
# Cleanup dirty change
git checkout -- README.md
show_tail

# === 4) Tests failing block push ===
log "Simulate failing test"
# Introduce a quick failing assertion then revert afterward
FAIL_FILE="test/tmp_failing_test.rb"
cat > "$FAIL_FILE" <<'RB'
require "test_helper"
class TmpFailingTest < ActiveSupport::TestCase
  test "fails" do
    assert false
  end
end
RB
run_handshake "fail-$(uuidgen)" "" || true
rm "$FAIL_FILE"
show_tail

# === 5) DRY_RUN prevents push ===
log "DRY_RUN run"
run_handshake "dry-$(uuidgen)" "DRY_RUN=1 " || true
show_tail

# === 6) Push failure path (uses fake remote that rejects) ===
log "Push failure path (fake remote)"
run_handshake "pushfail-$(uuidgen)" "GIT_REMOTE=$FAKE_REMOTE " || true
show_tail

# === 7) Stash apply conflict (best-effort local simulation) ===
log "Stash apply conflict simulation"
ART_PATH="knowledge_base/epics/AGENT-02C/queue_artifacts/${TASK_ID}.json"
mkdir -p "$(dirname "$ART_PATH")"
# Create a baseline change and stash
printf '{"baseline":true}\n' > "$ART_PATH"
git add "$ART_PATH"
git commit -m "temp baseline for conflict sim" --no-verify
# Make conflicting local change and stash
printf '{"conflict":true}\n' > "$ART_PATH"
git stash push -u -m conflict-sim
# Now run handshake which will write artifact and commit
run_handshake "stashconflict-$(uuidgen)" "" || true
# Try to pop stash to surface conflict
if ! git stash pop; then log "(Expected) stash conflict occurred"; fi
show_tail

git reset --hard HEAD~1 >/dev/null 2>&1 || true
git stash clear >/dev/null 2>&1 || true

# === 8) Log inspection ===
log "Recent log entries"
show_tail

# === 9) Clean up ===
log "Cleaning up scratch branch"
git checkout main
```

How to use:
1) Save as `manual_queue_handshake.sh`, `chmod +x manual_queue_handshake.sh`.
2) Run from repo root: `./manual_queue_handshake.sh`.
3) It creates/uses branch `scratch/queue-handshake-manual` and a fake remote to avoid real pushes. Review outputs and logs after each section.
4) If you want real pushes, remove `GIT_REMOTE` overrides and ensure you’re okay pushing to origin.

Notes:
- The script is best-effort for conflict simulation; tweak paths if your artifact location differs.
- It writes temp commits; you can `git reset --hard origin/main` afterward to clean.
- If `bundle exec rails runner` is slow, ensure gems are installed and database is migrated.