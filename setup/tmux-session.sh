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

NVIM_SOCK="/tmp/nvim-${SESSION}.sock"

tmux new-session -d -s "$SESSION" -c "$WORKDIR" -n "claude"
tmux new-window -t "$SESSION" -c "$WORKDIR" -n "nvim"
tmux send-keys -t "$SESSION:nvim" "nvim --listen '$NVIM_SOCK' ." Enter
tmux new-window -t "$SESSION" -c "$WORKDIR" -n "shell"

# Start in window 1 (claude)
tmux select-window -t "$SESSION:1"

# Attach
exec tmux attach-session -t "$SESSION"
