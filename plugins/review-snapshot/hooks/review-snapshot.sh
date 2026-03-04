#!/usr/bin/env bash
# Review snapshot hook — captures changed files, diff stats, and test results
# into a JSON snapshot for post-session review.
#
# Runs as a Claude Code Stop hook. The synchronous part checks whether any
# files changed; the expensive work (tests, JSON assembly) is forked into
# the background so Claude's exit is not delayed.
#
# Snapshot schema (v1):
#   {
#     "version": 1,
#     "timestamp": "ISO-8601",
#     "baseline_sha": "short SHA",
#     "current_sha": "short SHA",
#     "changed_files": ["file1", "file2"],
#     "diff_stat": {
#       "raw": "git diff --stat summary line",
#       "files_changed": N,
#       "insertions": N,
#       "deletions": N
#     },
#     "test_results": {
#       "available": true|false,
#       "runner": "plenary"|"pytest"|...,
#       "exit_code": N,
#       "output": "last line of test output"
#     }
#   }
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

# --- Resolve baseline SHA and test config ---
CONFIG_FILE=".claude/reviews/config.json"
BASELINE_SHA=""
TEST_CMD=""
TEST_RUNNER=""

if [[ -f "$CONFIG_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
        BASELINE_SHA=$(jq -r '.sha // empty' "$CONFIG_FILE" 2>/dev/null)
        TEST_CMD=$(jq -r '.test_command // empty' "$CONFIG_FILE" 2>/dev/null)
        TEST_RUNNER=$(jq -r '.test_runner // empty' "$CONFIG_FILE" 2>/dev/null)
    else
        BASELINE_SHA=$(grep -o '"sha"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null \
            | sed 's/.*"sha"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        TEST_CMD=$(grep -o '"test_command"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null \
            | sed 's/.*"test_command"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        TEST_RUNNER=$(grep -o '"test_runner"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null \
            | sed 's/.*"test_runner"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
    fi
fi

if [[ -z "$BASELINE_SHA" ]] || ! git rev-parse --verify "$BASELINE_SHA" >/dev/null 2>&1; then
    # Fallback: HEAD~1, or HEAD if single-commit repo
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        BASELINE_SHA=$(git rev-parse --short HEAD~1)
    else
        BASELINE_SHA=$(git rev-parse --short HEAD)
    fi
fi

# --- Check for changes (synchronous, fast) ---
mapfile -t CHANGED_FILES < <(git diff --name-only "$BASELINE_SHA"..HEAD 2>/dev/null)

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    exit 0
fi

# --- Fork expensive work into background ---
(
    REVIEWS_DIR=".claude/reviews"
    mkdir -p "$REVIEWS_DIR"

    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    FILENAME=$(date -u +"%Y-%m-%dT%H-%M-%S").json
    CURRENT_SHA=$(git rev-parse --short HEAD)

    # Diff stat
    STAT_RAW=$(git diff --stat "$BASELINE_SHA"..HEAD | tail -1)
    STAT_FILES=$(echo "$STAT_RAW" | grep -o '[0-9]* file' | grep -o '[0-9]*' || echo "0")
    STAT_INS=$(echo "$STAT_RAW" | grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo "0")
    STAT_DEL=$(echo "$STAT_RAW" | grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo "0")

    # Tests — config-driven via .claude/reviews/config.json
    TEST_AVAILABLE=false
    TEST_EXIT=0
    TEST_OUTPUT=""
    if [[ -n "$TEST_CMD" ]]; then
        TEST_AVAILABLE=true
        TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
        TEST_EXIT=$?
        TEST_OUTPUT=$(echo "$TEST_OUTPUT" | tail -1)
    fi

    # --- Build JSON ---
    if command -v jq >/dev/null 2>&1; then
        # Build changed_files array
        FILES_JSON=$(printf '%s\n' "${CHANGED_FILES[@]}" | jq -R . | jq -s .)

        jq -n \
            --argjson version 1 \
            --arg timestamp "$TIMESTAMP" \
            --arg baseline_sha "$BASELINE_SHA" \
            --arg current_sha "$CURRENT_SHA" \
            --argjson changed_files "$FILES_JSON" \
            --arg stat_raw "$STAT_RAW" \
            --argjson stat_files "${STAT_FILES:-0}" \
            --argjson stat_ins "${STAT_INS:-0}" \
            --argjson stat_del "${STAT_DEL:-0}" \
            --argjson test_available "$TEST_AVAILABLE" \
            --arg test_runner "$TEST_RUNNER" \
            --argjson test_exit "$TEST_EXIT" \
            --arg test_output "$TEST_OUTPUT" \
            '{
                version: $version,
                timestamp: $timestamp,
                baseline_sha: $baseline_sha,
                current_sha: $current_sha,
                changed_files: $changed_files,
                diff_stat: {
                    raw: $stat_raw,
                    files_changed: $stat_files,
                    insertions: $stat_ins,
                    deletions: $stat_del
                },
                test_results: {
                    available: $test_available,
                    runner: $test_runner,
                    exit_code: $test_exit,
                    output: $test_output
                }
            }' > "$REVIEWS_DIR/$FILENAME"
    else
        # printf fallback — escape JSON-sensitive characters
        json_escape() {
            local s="$1"
            s="${s//\\/\\\\}"
            s="${s//\"/\\\"}"
            s="${s//$'\t'/\\t}"
            s="${s//$'\n'/\\n}"
            printf '%s' "$s"
        }

        # Build changed_files array
        FILES_JSON=""
        for f in "${CHANGED_FILES[@]}"; do
            [[ -n "$FILES_JSON" ]] && FILES_JSON+=","
            FILES_JSON+="\"$(json_escape "$f")\""
        done

        printf '%s\n' "{
  \"version\": 1,
  \"timestamp\": \"$TIMESTAMP\",
  \"baseline_sha\": \"$(json_escape "$BASELINE_SHA")\",
  \"current_sha\": \"$(json_escape "$CURRENT_SHA")\",
  \"changed_files\": [$FILES_JSON],
  \"diff_stat\": {
    \"raw\": \"$(json_escape "$STAT_RAW")\",
    \"files_changed\": ${STAT_FILES:-0},
    \"insertions\": ${STAT_INS:-0},
    \"deletions\": ${STAT_DEL:-0}
  },
  \"test_results\": {
    \"available\": $TEST_AVAILABLE,
    \"runner\": \"$(json_escape "$TEST_RUNNER")\",
    \"exit_code\": $TEST_EXIT,
    \"output\": \"$(json_escape "$TEST_OUTPUT")\"
  }
}" > "$REVIEWS_DIR/$FILENAME"
    fi

    # --- Notify nvim ---
    NVIM_SOCK=$(ls /tmp/nvim-*.sock 2>/dev/null | head -1)
    if [[ -n "$NVIM_SOCK" ]]; then
        NUM_FILES=${#CHANGED_FILES[@]}
        nvim --server "$NVIM_SOCK" --remote-expr \
            "v:lua.vim.notify('Review snapshot: ${NUM_FILES} file(s) changed', vim.log.levels.INFO)" \
            2>/dev/null || true
    fi
) & disown

exit 0
