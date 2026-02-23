#!/usr/bin/env bash
set -euo pipefail

# Per-project setup — local equivalent of devcontainer postCreate.sh
# Run from the root of a project directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(pwd)"

echo "==> Project setup: $PROJECT_DIR"
echo ""

# ─── 1. Python dependencies ──────────────────────────────────────────────────

if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    echo "==> Installing Python dependencies..."
    if [ -f "pyproject.toml" ]; then
        uv sync
    elif [ -f "requirements.txt" ]; then
        uv pip install -r requirements.txt
    fi
else
    echo "==> No Python project detected, skipping dependency install."
fi

# ─── 2. Pre-commit hooks ─────────────────────────────────────────────────────

if [ -f ".pre-commit-config.yaml" ]; then
    echo ""
    echo "==> Installing pre-commit hooks..."
    pre-commit install
else
    echo ""
    echo "==> No .pre-commit-config.yaml found, skipping."
fi

# ─── 3. direnv ────────────────────────────────────────────────────────────────

if [ ! -f ".envrc" ]; then
    echo ""
    echo "==> Copying .envrc template..."
    cp "$REPO_DIR/.envrc.template" ".envrc"
    echo "    Edit .envrc to set your Python version, then run: direnv allow"
else
    echo ""
    echo "==> .envrc already exists, skipping."
fi

direnv allow 2>/dev/null || true

# ─── 4. Claude Code directory ────────────────────────────────────────────────

if [ ! -d ".claude" ]; then
    echo ""
    echo "==> Creating .claude/ directory..."
    mkdir -p .claude
fi

# ─── 5. AGENTS.md symlink (opencode compatibility) ───────────────────────────

if [ -f "CLAUDE.md" ] && [ ! -f "AGENTS.md" ] && [ ! -L "AGENTS.md" ]; then
    echo ""
    echo "==> Symlinking CLAUDE.md → AGENTS.md (opencode compatibility)..."
    ln -s CLAUDE.md AGENTS.md
fi

echo ""
echo "==> Project setup complete!"
