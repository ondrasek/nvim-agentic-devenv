#!/usr/bin/env bash
# Session start check — verify quality tools are available (non-blocking)
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

missing=()

command -v selene >/dev/null 2>&1 || missing+=("selene")
command -v stylua >/dev/null 2>&1 || missing+=("stylua")
command -v lizard >/dev/null 2>&1 || missing+=("lizard")

if [[ ! -f selene.toml ]]; then
    echo "WARNING: selene.toml not found"
fi

if [[ ! -f .stylua.toml ]]; then
    echo "WARNING: .stylua.toml not found"
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "WARNING: Missing quality tools: ${missing[*]}"
    echo "Install with: brew install ${missing[*]}"
fi

# Always exit 0 — session start is non-blocking
exit 0
