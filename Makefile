REPO_DIR := $(shell pwd)

# Never push these to ~/.config/nvim (and never remove them there): the installed lockfile is
# newer than any repo copy, logs are runtime output, tests only run from the repo.
NVIM_RSYNC_EXCLUDES := --exclude lazy-lock.json --exclude '*.log' --exclude .nvimlog --exclude tests/ --exclude .claude/

.PHONY: install copy diff setup-project test lint format check

## install: Run full bootstrap (brew, tools, copy configs)
install:
	@echo "🚀 Starting full bootstrap..."
	@echo "   This will install Homebrew packages, CLI tools, and copy configs."
	bash setup/bootstrap.sh
	@echo "✅ Bootstrap complete!"

## copy: Copy configs only (no brew install)
copy:
	@echo "📋 Copying configs from repo to ~/.config..."
	@mkdir -p ~/.config/nvim ~/.config/tmux ~/.config/ghostty
	@# One-time backup of whatever was installed before this repo took over (the sync below mirrors the repo)
	@for d in nvim ghostty; do \
		if [ -d ~/.config/$$d ] && [ ! -e ~/.config/$$d.pre-devenv ] && [ -n "$$(ls -A ~/.config/$$d)" ]; then \
			cp -R ~/.config/$$d ~/.config/$$d.pre-devenv && echo "   backup → ~/.config/$$d.pre-devenv"; \
		fi; \
	done
	@echo "   nvim   → ~/.config/nvim/"
	@rsync -a --delete $(NVIM_RSYNC_EXCLUDES) $(REPO_DIR)/nvim/ ~/.config/nvim/
	@echo "   tmux   → ~/.config/tmux/tmux.conf"
	@cp $(REPO_DIR)/tmux/tmux.conf ~/.config/tmux/tmux.conf
	@echo "   ghostty → ~/.config/ghostty/"
	@rsync -a --delete $(REPO_DIR)/ghostty/ ~/.config/ghostty/
	@if command -v chezmoi >/dev/null 2>&1; then \
		echo "📦 chezmoi detected — run 'chezmoi re-add' to track updated configs."; \
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
	@diff -rq $(REPO_DIR)/ghostty/ ~/.config/ghostty/ 2>/dev/null || true
	@echo "✅ Diff complete."

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
	stylua nvim/lua/ nvim/init.lua

## check: Run all quality checks (lint, format check, complexity, tests)
check: lint
	stylua --check nvim/lua/ nvim/init.lua
	lizard nvim/lua/ --CCN 20 --warnings_only
	$(MAKE) test
