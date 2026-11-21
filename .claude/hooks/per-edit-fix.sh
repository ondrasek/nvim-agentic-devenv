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

# Run stylua with the repo's config. stylua looks for its config relative to the CURRENT directory,
# which can drift (e.g. into nvim/), silently falling back to stylua's tab-indented defaults.
root="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-}")"
config_args=()
if [[ -n "$root" && -f "$root/.stylua.toml" ]]; then
    config_args=(--config-path "$root/.stylua.toml")
fi
if ! stylua "${config_args[@]+"${config_args[@]}"}" "$file" >&2; then
    echo "stylua: syntax error in $file" >&2
    exit 2
fi

exit 0
