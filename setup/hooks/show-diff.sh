#!/usr/bin/env bash
# PostToolUse hook: opens modified file in nvim and shows git diff
# Requires nvim running with --listen /tmp/nvim-{session}.sock

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
[ -z "$FILE_PATH" ] && exit 0

# Find the nvim server socket (use first match)
NVIM_SOCK=$(ls /tmp/nvim-*.sock 2>/dev/null | head -1)
[ -z "$NVIM_SOCK" ] && exit 0

# Tell nvim to open the file and show diff against HEAD
nvim --server "$NVIM_SOCK" --remote-send "<Esc>:edit ${FILE_PATH}<CR>:Gitsigns diffthis<CR>" 2>/dev/null

exit 0
