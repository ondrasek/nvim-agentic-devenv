#!/usr/bin/env bash
set -euo pipefail

# Container bootstrap script for nvim-agentic-devenv
# Installs neovim + dependencies and copies the IDE config.
# Usage: run inside a container (Dockerfile RUN or devcontainer postCreateCommand)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Detecting package manager..."
if command -v apt-get &>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        git curl unzip ripgrep fzf nodejs npm
    # Neovim — download from GitHub releases (PPA is Ubuntu-only, not available on Debian)
    case "$(uname -m)" in
        x86_64)  NVIM_ARCH="x86_64" ;;
        aarch64) NVIM_ARCH="arm64" ;;
        *) echo "ERROR: Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    curl -L "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
        -o /tmp/nvim.tar.gz
    tar -C /usr/local --strip-components=1 -xzf /tmp/nvim.tar.gz
    rm /tmp/nvim.tar.gz
    apt-get clean && rm -rf /var/lib/apt/lists/*
elif command -v apk &>/dev/null; then
    apk add --no-cache neovim git curl ripgrep fzf nodejs npm
else
    echo "ERROR: Unsupported package manager (need apt or apk)" >&2
    exit 1
fi

echo "==> Copying nvim config..."
mkdir -p ~/.config/nvim
cp -r "$REPO_DIR/nvim/"* ~/.config/nvim/

echo "==> Installing plugins (headless)..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "==> Installing treesitter parsers..."
nvim --headless "+TSUpdateSync" +qa 2>/dev/null || true

echo "==> Installing uv + ruff..."
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
if ! command -v ruff &>/dev/null; then
    curl -LsSf https://astral.sh/ruff/install.sh | sh
fi

echo "==> Done. Run 'nvim .' to start the IDE."
