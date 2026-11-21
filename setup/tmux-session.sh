#!/usr/bin/env bash
set -euo pipefail

# Standard 3-window dev session launcher
# Usage: tmux-session.sh [session-name] [working-directory]

SESSION="${1:-dev}"
WORKDIR="${2:-$(pwd)}"

# If already inside tmux, don't nest
if [ -n "${TMUX:-}" ]; then
    echo "Already inside tmux. Use Ctrl-a to manage windows."
    exit 0
fi

# Attach to existing session if it exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Attaching to existing session: $SESSION"
    exec tmux attach-session -t "$SESSION"
fi

# Create new session with 3 windows
echo "Creating session: $SESSION (dir: $WORKDIR)"

# Same socket convention as nvim-review and the Claude Code hooks: <repo>/.claude/.nvim-socket.
# Outside a repo with a .claude/ directory, fall back to a per-session socket in $TMPDIR.
ROOT="$(git -C "$WORKDIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$ROOT" ] && [ -d "$ROOT/.claude" ]; then
    NVIM_SOCK="$ROOT/.claude/.nvim-socket"
else
    NVIM_SOCK="${TMPDIR:-/tmp}/nvim-${SESSION}.sock"
fi
rm -f "$NVIM_SOCK" # stale socket from a previous run (session did not exist, so none is live)
printf -v NVIM_SOCK_Q '%q' "$NVIM_SOCK"

tmux new-session -d -s "$SESSION" -c "$WORKDIR" -n "claude"
tmux new-window -t "$SESSION" -c "$WORKDIR" -n "nvim"
tmux send-keys -t "$SESSION:nvim" "nvim --listen $NVIM_SOCK_Q ." Enter
tmux new-window -t "$SESSION" -c "$WORKDIR" -n "shell"

# Start in window 1 (claude)
tmux select-window -t "$SESSION:1"

# Attach
exec tmux attach-session -t "$SESSION"
