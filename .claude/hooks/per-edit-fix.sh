#!/usr/bin/env bash
# Auto-format Lua files after Edit/Write — PostToolUse hook
# Exit 0 = success, Exit 2 = syntax error (blocks)
set -euo pipefail

# Hook input arrives as JSON on stdin: {"tool_input": {"file_path": "..."}}
# (there is no CLAUDE_FILE env var). Requires jq; exits quietly without it.
command -v jq >/dev/null 2>&1 || exit 0
file="$(jq -r '.tool_input.file_path // empty')"

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
if ! stylua "$file" >&2; then
    echo "stylua: syntax error in $file" >&2
    exit 2
fi

exit 0
