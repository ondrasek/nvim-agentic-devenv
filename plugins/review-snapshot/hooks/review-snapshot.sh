#!/usr/bin/env bash
# Review dashboard hook — generates markdown reports for post-session review.
#
# Runs as a Claude Code Stop hook. The synchronous part checks whether any
# files changed; the expensive work (tests, PR status, transcript parsing,
# markdown generation) is forked into the background so Claude's exit is
# not delayed.
#
# Output: .claude/reviews/latest/ — a rolling folder of markdown reports,
# overwritten each Stop.
#
# Reports:
#   00-summary.md        — at-a-glance overview with links
#   01-changes.md        — changed files list, insertions/deletions
#   02-tests.md          — test runner, exit code, output
#   03-conversation.md   — user/assistant dialogue from session transcript
#   04-pull-requests.md  — current branch PR + recent open PRs
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
    REPORT_DIR=".claude/reviews/latest"
    rm -rf "$REPORT_DIR"
    mkdir -p "$REPORT_DIR"

    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    CURRENT_SHA=$(git rev-parse --short HEAD)
    BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
    NUM_FILES=${#CHANGED_FILES[@]}

    # --- Diff stats ---
    STAT_RAW=$(git diff --stat "$BASELINE_SHA"..HEAD | tail -1)
    STAT_FILES=$(echo "$STAT_RAW" | grep -o '[0-9]* file' | grep -o '[0-9]*' || echo "0")
    STAT_INS=$(echo "$STAT_RAW" | grep -o '[0-9]* insertion' | grep -o '[0-9]*' || echo "0")
    STAT_DEL=$(echo "$STAT_RAW" | grep -o '[0-9]* deletion' | grep -o '[0-9]*' || echo "0")

    DIFF_STAT_FULL=$(git diff --stat "$BASELINE_SHA"..HEAD 2>/dev/null)

    # --- Tests ---
    TEST_STATUS="N/A"
    TEST_EXIT=0
    TEST_OUTPUT=""
    if [[ -n "$TEST_CMD" ]]; then
        TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
        TEST_EXIT=$?
        if [[ $TEST_EXIT -eq 0 ]]; then
            TEST_STATUS="PASS"
        else
            TEST_STATUS="FAIL"
        fi
    fi

    # --- PR status ---
    PR_STATUS_OUTPUT=""
    PR_LIST_OUTPUT=""
    PR_COUNT=0
    if command -v gh >/dev/null 2>&1; then
        PR_STATUS_OUTPUT=$(gh pr status 2>&1) || PR_STATUS_OUTPUT=""
        PR_LIST_OUTPUT=$(gh pr list --state open --limit 5 2>&1) || PR_LIST_OUTPUT=""
        if [[ -n "$PR_LIST_OUTPUT" ]]; then
            PR_COUNT=$(echo "$PR_LIST_OUTPUT" | wc -l | tr -d ' ')
        fi
    fi

    # --- Conversation transcript ---
    CONVERSATION_MD=""
    if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]] && command -v jq >/dev/null 2>&1; then
        # Derive project hash: replace / with - and prepend -
        PROJECT_HASH=$(echo "$CLAUDE_PROJECT_DIR" | sed 's|/|-|g')
        PROJECTS_DIR="$HOME/.claude/projects/${PROJECT_HASH}"

        if [[ -d "$PROJECTS_DIR" ]]; then
            # Find the most recently modified .jsonl file
            JSONL_FILE=$(ls -t "$PROJECTS_DIR"/*.jsonl 2>/dev/null | head -1)

            if [[ -n "$JSONL_FILE" && -f "$JSONL_FILE" ]]; then
                CONVERSATION_MD=$(jq -r '
                    select(.type == "user" or .type == "assistant") |
                    .type as $t |
                    [.message.content[] | select(.type == "text") | .text] |
                    join("\n") |
                    if . != "" then
                        if $t == "user" then "**You:** " + . + "\n\n---\n"
                        else "**Claude:** " + (split("\n")[0]) + "\n\n---\n"
                        end
                    else empty end
                ' "$JSONL_FILE" 2>/dev/null) || CONVERSATION_MD=""
            fi
        fi
    fi

    # --- Generate 01-changes.md ---
    {
        echo "# Changes"
        echo ""
        echo "**Baseline:** \`${BASELINE_SHA}\` → **Current:** \`${CURRENT_SHA}\`"
        echo ""
        echo "## Changed Files"
        echo ""
        for f in "${CHANGED_FILES[@]}"; do
            echo "- \`${f}\`"
        done
        echo ""
        echo "## Diff Stats"
        echo ""
        echo '```'
        echo "$DIFF_STAT_FULL"
        echo '```'
    } > "$REPORT_DIR/01-changes.md"

    # --- Generate 02-tests.md ---
    {
        echo "# Tests"
        echo ""
        if [[ -z "$TEST_CMD" ]]; then
            echo "*No tests configured.* Add \`test_command\` to \`.claude/reviews/config.json\` to enable."
        else
            echo "- **Runner:** ${TEST_RUNNER:-unknown}"
            echo "- **Command:** \`${TEST_CMD}\`"
            echo "- **Result:** ${TEST_STATUS} (exit code ${TEST_EXIT})"
            echo ""
            echo "## Output"
            echo ""
            echo '```'
            echo "$TEST_OUTPUT"
            echo '```'
        fi
    } > "$REPORT_DIR/02-tests.md"

    # --- Generate 03-conversation.md ---
    {
        echo "# Conversation"
        echo ""
        if [[ -z "$CONVERSATION_MD" ]]; then
            if ! command -v jq >/dev/null 2>&1; then
                echo "*Transcript not available — jq is required but not installed.*"
            elif [[ -z "${CLAUDE_PROJECT_DIR:-}" ]]; then
                echo "*Transcript not available — CLAUDE_PROJECT_DIR not set.*"
            else
                echo "*Transcript not found.*"
            fi
        else
            echo "$CONVERSATION_MD"
        fi
    } > "$REPORT_DIR/03-conversation.md"

    # --- Generate 04-pull-requests.md ---
    {
        echo "# Pull Requests"
        echo ""
        if ! command -v gh >/dev/null 2>&1; then
            echo "*\`gh\` CLI not available.* Install [GitHub CLI](https://cli.github.com/) to enable PR status."
        elif [[ -z "$PR_STATUS_OUTPUT" && -z "$PR_LIST_OUTPUT" ]]; then
            echo "*No PR data available.* You may need to run \`gh auth login\`."
        else
            if [[ -n "$PR_STATUS_OUTPUT" ]]; then
                echo "## Current Branch"
                echo ""
                echo '```'
                echo "$PR_STATUS_OUTPUT"
                echo '```'
            fi
            if [[ -n "$PR_LIST_OUTPUT" ]]; then
                echo ""
                echo "## Open PRs"
                echo ""
                echo '```'
                echo "$PR_LIST_OUTPUT"
                echo '```'
            fi
        fi
    } > "$REPORT_DIR/04-pull-requests.md"

    # --- Generate 00-summary.md (last, references computed values) ---
    {
        echo "# Session Review — ${TIMESTAMP}"
        echo ""
        echo "## At a Glance"
        echo ""
        echo "- **Branch:** ${BRANCH}"
        echo "- **Baseline:** \`${BASELINE_SHA}\` → **Current:** \`${CURRENT_SHA}\`"
        echo "- **Files changed:** ${NUM_FILES} (+${STAT_INS:-0} / -${STAT_DEL:-0})"
        if [[ -n "$TEST_CMD" ]]; then
            echo "- **Tests:** ${TEST_STATUS} (${TEST_RUNNER:-unknown})"
        else
            echo "- **Tests:** not configured"
        fi
        echo "- **Open PRs:** ${PR_COUNT}"
        echo ""
        echo "## Reports"
        echo ""
        echo "- [Changes](01-changes.md)"
        echo "- [Tests](02-tests.md)"
        echo "- [Conversation](03-conversation.md)"
        echo "- [Pull Requests](04-pull-requests.md)"
    } > "$REPORT_DIR/00-summary.md"

    # --- Open in nvim ---
    # 1. $NVIM — set when running inside nvim's :terminal (exact parent instance)
    # 2. .claude/.nvim-socket — per-repo socket created by nvim-review alias
    NVIM_SOCK="${NVIM:-}"
    if [[ -z "$NVIM_SOCK" ]] && [[ -S ".claude/.nvim-socket" ]]; then
        NVIM_SOCK=".claude/.nvim-socket"
    fi
    if [[ -n "$NVIM_SOCK" ]]; then
        FULL_REPORT_DIR="$(pwd)/$REPORT_DIR"
        nvim --server "$NVIM_SOCK" --remote-send \
            "<Esc>:edit ${FULL_REPORT_DIR}/00-summary.md<CR>:Neotree reveal<CR>" \
            2>/dev/null || true
    fi
) & disown

exit 0
