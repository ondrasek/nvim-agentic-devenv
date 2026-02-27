#!/usr/bin/env bash
# Auto-format Lua files after Edit/Write — PostToolUse hook
# Exit 0 = success, Exit 2 = syntax error (blocks)
set -euo pipefail

# CLAUDE_FILE is set by the hook system for Edit/Write operations
file="${CLAUDE_FILE:-}"

# Only act on .lua files
if [[ "$file" != *.lua ]]; then
    exit 0
fi

# Only format if stylua is available
if ! command -v stylua >/dev/null 2>&1; then
    exit 0
fi

# Only format if the file exists (might have been deleted)
if [[ ! -f "$file" ]]; then
    exit 0
fi

# Run stylua on the file
if ! stylua "$file" 2>&1; then
    echo "stylua: syntax error in $file"
    exit 2
fi

exit 0
