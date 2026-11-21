#!/usr/bin/env bash
# PostToolUse hook: opens the modified file in nvim and shows its git diff.
# Socket: <project>/.claude/.nvim-socket — the same path used by `nvim-review`
# (setup/shell-functions.sh), tmux-session.sh and the review-snapshot hook.

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$ROOT" ] && exit 0
SOCK="$ROOT/.claude/.nvim-socket"
[ -S "$SOCK" ] || exit 0

# Liveness probe: a stale socket file left by a crashed nvim must not hang the hook
[ "$(nvim --server "$SOCK" --remote-expr 1 2>/dev/null)" = "1" ] || exit 0

# --remote takes the path as an argument (no Ex-command interpolation), so special
# characters in file names cannot inject commands the way --remote-send "<Esc>:edit ..." did.
nvim --server "$SOCK" --remote "$FILE_PATH" 2>/dev/null
nvim --server "$SOCK" --remote-send '<C-\><C-N><Cmd>Gitsigns diffthis<CR>' 2>/dev/null

exit 0
