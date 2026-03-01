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
        git curl unzip ripgrep fzf nodejs npm jq
    # Neovim — download from GitHub releases (PPA is Ubuntu-only, not available on Debian)
    NVIM_VERSION="v0.11.6"
    case "$(uname -m)" in
        x86_64)  NVIM_ARCH="x86_64" ;;
        aarch64) NVIM_ARCH="arm64" ;;
        *) echo "ERROR: Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    NVIM_TARBALL="nvim-linux-${NVIM_ARCH}.tar.gz"
    curl -LsSf "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${NVIM_TARBALL}" \
        -o /tmp/nvim.tar.gz
    # Verify checksum from GitHub release asset digest
    NVIM_SHA256="$(curl -s "https://api.github.com/repos/neovim/neovim/releases/tags/${NVIM_VERSION}" \
        | jq -r ".assets[] | select(.name == \"${NVIM_TARBALL}\") | .digest" \
        | cut -d: -f2)"
    echo "${NVIM_SHA256}  /tmp/nvim.tar.gz" | sha256sum -c -
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
