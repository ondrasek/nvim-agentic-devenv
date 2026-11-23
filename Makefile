REPO_DIR := $(shell pwd)

# `make copy` also tracks the installed configs in chezmoi (when installed). CHEZMOI=0 skips it;
# CHEZMOI_ARGS=--dry-run only shows the plan. chezmoi's own git.autopush decides whether that pushes.
CHEZMOI ?= 1
CHEZMOI_ARGS ?= --yes

# Never push these to ~/.config/nvim (and never remove them there): the installed lockfile is
# newer than any repo copy, logs are runtime output, tests only run from the repo.
NVIM_RSYNC_EXCLUDES := --exclude lazy-lock.json --exclude '*.log' --exclude .nvimlog --exclude tests/ --exclude .claude/

.PHONY: install copy diff setup-project test lint format check agent-image chezmoi-sync

## install: Run full bootstrap (brew, tools, copy configs)
install:
	@echo "🚀 Starting full bootstrap..."
	@echo "   This will install Homebrew packages, CLI tools, and copy configs."
	bash setup/bootstrap.sh
	@echo "✅ Bootstrap complete!"

## copy: Copy configs only (no brew install)
copy:
	@echo "📋 Copying configs from repo to ~/.config..."
	@mkdir -p ~/.config/nvim ~/.config/tmux
	@# One-time backup of whatever was installed before this repo took over (the sync below mirrors the repo)
	@if [ -d ~/.config/nvim ] && [ ! -e ~/.config/nvim.pre-devenv ] && [ -n "$$(ls -A ~/.config/nvim)" ]; then \
		cp -R ~/.config/nvim ~/.config/nvim.pre-devenv && echo "   backup → ~/.config/nvim.pre-devenv"; \
	fi
	@echo "   nvim   → ~/.config/nvim/"
	@rsync -a --delete $(NVIM_RSYNC_EXCLUDES) $(REPO_DIR)/nvim/ ~/.config/nvim/
	@echo "   tmux   → ~/.config/tmux/tmux.conf"
	@cp $(REPO_DIR)/tmux/tmux.conf ~/.config/tmux/tmux.conf
	@# ghostty is never overwritten or mirrored: the repo config is only installed when you have none
	@if [ -e ~/.config/ghostty/config ]; then \
		echo "   ghostty → skipped (~/.config/ghostty/config exists; see 'make diff')"; \
	else \
		mkdir -p ~/.config/ghostty && cp $(REPO_DIR)/ghostty/config ~/.config/ghostty/config && echo "   ghostty → ~/.config/ghostty/config (new)"; \
	fi
	@if [ "$(CHEZMOI)" = "0" ]; then \
		echo "📦 chezmoi sync skipped (CHEZMOI=0)"; \
	elif command -v chezmoi >/dev/null 2>&1; then \
		echo "📦 chezmoi detected — tracking the updated configs (chezmoi may commit and push; 'make copy CHEZMOI=0' skips this)"; \
		bash $(REPO_DIR)/setup/chezmoi-sync.sh $(CHEZMOI_ARGS) \
			|| echo "⚠️  chezmoi sync failed — the configs ARE copied; fix chezmoi and run 'make chezmoi-sync'"; \
	else \
		echo "💡 Tip: install chezmoi to track your dotfiles across machines."; \
	fi
	@echo "✅ Configs copied."

## diff: Show differences between repo and installed configs
diff:
	@echo "🔍 Comparing repo configs with installed configs..."
	@echo "── nvim ──"
	@diff -rq -x lazy-lock.json -x '*.log' -x .nvimlog -x tests -x .claude $(REPO_DIR)/nvim/ ~/.config/nvim/ 2>/dev/null || true
	@echo "── tmux ──"
	@diff -q $(REPO_DIR)/tmux/tmux.conf ~/.config/tmux/tmux.conf 2>/dev/null || true
	@echo "── ghostty ──"
	@diff -u ~/.config/ghostty/config $(REPO_DIR)/ghostty/config 2>/dev/null || true
	@echo "✅ Diff complete."

## chezmoi-sync: Track the installed configs in chezmoi (shows the plan, asks before committing/pushing)
chezmoi-sync:
	@bash $(REPO_DIR)/setup/chezmoi-sync.sh

## agent-image: Build the Pi container image the agent chat runs in (needs Apple's `container`)
agent-image:
	@container system status >/dev/null 2>&1 || container system start --enable-kernel-install
	container build -t devenv-pi:latest -f $(REPO_DIR)/containers/pi/Containerfile $(REPO_DIR)/containers/pi

## setup-project: Initialize current directory as a development project
setup-project:
	@echo "🔧 Setting up current directory as a dev project..."
	bash $(REPO_DIR)/setup/project-setup.sh
	@echo "✅ Project setup complete."

## test: Run plenary.nvim tests
test:
	cd nvim && nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

## lint: Run selene linter
lint:
	selene nvim/lua/ nvim/init.lua

## format: Format Lua files with stylua
format:
	stylua nvim/lua/ nvim/init.lua nvim/tests/

## check: Run all quality checks (lint, format check, complexity, tests)
check: lint
	stylua --check nvim/lua/ nvim/init.lua nvim/tests/
	lizard nvim/lua/ --CCN 20 --warnings_only
	$(MAKE) test
