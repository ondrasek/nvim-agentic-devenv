#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> nvim-agentic-devenv bootstrap"
echo "    Repo: $REPO_DIR"
echo ""

# ─── 1. Homebrew dependencies ────────────────────────────────────────────────

echo "==> Installing Homebrew packages..."
brew bundle --file="$REPO_DIR/setup/Brewfile"

# ─── 2. Install ruff via uv ──────────────────────────────────────────────────

echo ""
echo "==> Installing ruff via uv..."
if command -v ruff &>/dev/null; then
    echo "    ruff already installed: $(ruff --version)"
else
    uv tool install ruff
    echo "    ruff installed: $(ruff --version)"
fi

# ─── 3. Copy configs ─────────────────────────────────────────────────────────
# Copies rather than symlinks — use chezmoi to track the installed files.

echo ""
echo "==> Copying configs..."

copy_config() {
    local source="$1"
    local target="$2"
    local chezmoi_managed=false

    # Check if target is managed by chezmoi
    if command -v chezmoi &>/dev/null && chezmoi managed --path-style absolute 2>/dev/null | grep -qF "$target"; then
        chezmoi_managed=true
    fi

    mkdir -p "$(dirname "$target")"

    if [ -d "$source" ]; then
        rsync -a --delete "$source/" "$target/"
    else
        cp "$source" "$target"
    fi
    echo "    Copied: $source → $target"

    # Re-add to chezmoi so it tracks the updated files
    if [ "$chezmoi_managed" = true ]; then
        chezmoi add "$target"
        echo "    Re-added to chezmoi: $target"
    fi
}

copy_config "$REPO_DIR/nvim" "$HOME/.config/nvim"
copy_config "$REPO_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
copy_config "$REPO_DIR/ghostty" "$HOME/.config/ghostty"

# ─── 4. direnv hook in .zshrc ────────────────────────────────────────────────

echo ""
echo "==> Checking direnv hook..."

ZSHRC="$HOME/.zshrc"
DIRENV_HOOK='eval "$(direnv hook zsh)"'

if grep -qF "$DIRENV_HOOK" "$ZSHRC" 2>/dev/null; then
    echo "    direnv hook already in .zshrc"
else
    echo "" >> "$ZSHRC"
    echo "# direnv (added by nvim-agentic-devenv bootstrap)" >> "$ZSHRC"
    echo "$DIRENV_HOOK" >> "$ZSHRC"
    echo "    Added direnv hook to .zshrc"
fi

# ─── 5. Verify tools ─────────────────────────────────────────────────────────

echo ""
echo "==> Verifying tools..."

check_tool() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" &>/dev/null; then
        echo "    OK: $name"
    else
        echo "    WARN: $name — check failed"
    fi
}

check_tool "gpg signing" "gpg --list-secret-keys 2>/dev/null | grep -q sec"
check_tool "gh auth" "gh auth status"
check_tool "pyenv" "pyenv version"
check_tool "nvim" "nvim --version"
check_tool "tmux" "tmux -V"
check_tool "direnv" "direnv version"
check_tool "ruff" "ruff --version"
check_tool "pre-commit" "pre-commit --version"

echo ""
echo "==> Bootstrap complete!"
echo "    Restart your shell or run: source ~/.zshrc"
