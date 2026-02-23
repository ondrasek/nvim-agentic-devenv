REPO_DIR := $(shell pwd)

.PHONY: install copy diff setup-project

## install: Run full bootstrap (brew, tools, copy configs)
install:
	bash setup/bootstrap.sh

## copy: Copy configs only (no brew install)
copy:
	@echo "==> Copying configs..."
	@mkdir -p ~/.config/nvim ~/.config/tmux ~/.config/ghostty
	@rsync -a --delete $(REPO_DIR)/nvim/ ~/.config/nvim/
	@cp $(REPO_DIR)/tmux/tmux.conf ~/.config/tmux/tmux.conf
	@rsync -a --delete $(REPO_DIR)/ghostty/ ~/.config/ghostty/
	@echo "    Done."

## diff: Show differences between repo and installed configs
diff:
	@echo "==> nvim"; diff -rq $(REPO_DIR)/nvim/ ~/.config/nvim/ 2>/dev/null || true
	@echo "==> tmux"; diff -q $(REPO_DIR)/tmux/tmux.conf ~/.config/tmux/tmux.conf 2>/dev/null || true
	@echo "==> ghostty"; diff -rq $(REPO_DIR)/ghostty/ ~/.config/ghostty/ 2>/dev/null || true

## setup-project: Initialize current directory as a development project
setup-project:
	bash $(REPO_DIR)/setup/project-setup.sh
