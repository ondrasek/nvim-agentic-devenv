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

# ─── 2b. Install lizard (complexity gate used by `make check` and hooks) ─────

echo ""
echo "==> Installing lizard via uv..."
if command -v lizard &>/dev/null; then
    echo "    lizard already installed"
else
    uv tool install lizard
fi

# ─── 3. Copy configs ─────────────────────────────────────────────────────────
# Copies rather than symlinks. chezmoi tracking is done once afterwards by setup/chezmoi-sync.sh
# (the same script `make copy` runs); CHEZMOI=0 skips it, CHEZMOI_ARGS=--dry-run only shows the plan.

echo ""
echo "==> Copying configs..."

copy_config() {
    local source="$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"

    if [ -d "$source" ]; then
        # One-time backup of a pre-existing config (the sync below mirrors the repo)
        if [ -d "$target" ] && [ ! -e "$target.pre-devenv" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
            cp -R "$target" "$target.pre-devenv"
            echo "    Backup: $target → $target.pre-devenv"
        fi
        # Keep the installed lockfile and runtime logs; tests only run from the repo
        rsync -a --delete --exclude lazy-lock.json --exclude '*.log' --exclude .nvimlog --exclude tests/ --exclude .claude/ \
            "$source/" "$target/"
    else
        cp "$source" "$target"
    fi
    echo "    Copied: $source → $target"
}

copy_config "$REPO_DIR/nvim" "$HOME/.config/nvim"
copy_config "$REPO_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"

# Ghostty is personal: never overwrite or mirror it. Install the repo config only when none exists.
if [ -e "$HOME/.config/ghostty/config" ]; then
    echo "    Skipped ghostty: $HOME/.config/ghostty/config exists (compare with: diff -u ~/.config/ghostty/config $REPO_DIR/ghostty/config)"
else
    mkdir -p "$HOME/.config/ghostty"
    cp "$REPO_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    echo "    Copied: ghostty/config → $HOME/.config/ghostty/config (new)"
fi

# Track the installed configs in chezmoi: exactly the installed files, stale entries forgotten, plan printed.
# chezmoi's own git.autocommit / git.autopush then decide whether that commits and pushes.
if [ "${CHEZMOI:-1}" = "0" ]; then
    echo "    📦 chezmoi sync skipped (CHEZMOI=0)"
elif command -v chezmoi &>/dev/null; then
    echo "    📦 chezmoi detected — tracking the installed configs (chezmoi may commit and push)"
    bash "$REPO_DIR/setup/chezmoi-sync.sh" ${CHEZMOI_ARGS:---yes} \
        || echo "    ⚠️  chezmoi sync failed — the configs ARE copied; fix chezmoi and run 'make chezmoi-sync'"
else
    echo "    💡 Tip: install chezmoi to track your dotfiles across machines."
fi

# ─── 4. direnv hook + shell functions in .zshrc ─────────────────────────────

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

echo ""
echo "==> Checking shell functions..."

SHELL_FUNCS_SOURCE="source \"$REPO_DIR/setup/shell-functions.sh\""

if grep -qF "shell-functions.sh" "$ZSHRC" 2>/dev/null; then
    echo "    shell functions already in .zshrc"
else
    echo "" >> "$ZSHRC"
    echo "# nvim-agentic-devenv functions (added by bootstrap)" >> "$ZSHRC"
    echo "$SHELL_FUNCS_SOURCE" >> "$ZSHRC"
    echo "    Added shell functions to .zshrc"
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
