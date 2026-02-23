# nvim-agentic-devenv

Local nvim-based agentic development environment. Replaces VSCode + devcontainers with terminal-native tools.

## Repository Structure

- `nvim/` — Neovim config (copied to `~/.config/nvim`)
- `tmux/` — tmux config
- `ghostty/` — Ghostty terminal config (copied to `~/.config/ghostty`)
- `iterm2/` — iTerm2 keybinding documentation
- `setup/` — Bootstrap scripts, Brewfile, project setup
- `docs/` — Learning guides and references
- `plans/` — Future phase documentation

## Key Conventions

- **Plugin management:** Lazy.nvim. Each plugin is a separate file in `nvim/lua/plugins/` returning a spec table. Lazy auto-imports all files via `{ import = "plugins" }` in `lua/config/lazy.lua`.
- **Leader key:** Space (`<leader>`)
- **tmux prefix:** `Ctrl-a`
- **Terminal keybindings:** `Cmd+1-9` maps to `Alt+1-9` (via Ghostty/iTerm2), which tmux maps to window switching.

## Setup

```bash
make install        # Full bootstrap (brew, tools, copy configs)
make copy           # Copy configs only (no brew install)
make diff           # Show differences between repo and installed configs
make setup-project  # Init current dir as dev project
```

Configs are copied (not symlinked) — use chezmoi to track installed dotfiles.

## Adding Plugins

Create a new file in `nvim/lua/plugins/` following the Lazy.nvim spec format:
```lua
return {
    "author/plugin-name",
    opts = {},
}
```

Run `:Lazy` in nvim to install/update/manage plugins.
