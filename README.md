# nvim-agentic-devenv

Terminal-native development environment built on Neovim, tmux, and Ghostty. Replaces VSCode + devcontainers with hand-rolled, transparent config.

## What's included

**Editor (Neovim)**
- File explorer (neo-tree), buffer tabs (bufferline), status line (lualine)
- LSP via mason — pyright, ruff, lua_ls out of the box
- Autocompletion (blink.cmp) with LSP, buffer, path, and snippet sources
- Format-on-save (conform.nvim) — ruff_format for Python, stylua for Lua
- Diagnostics panel (trouble.nvim), TODO highlighting, auto-pairs
- Fuzzy finder (telescope), git signs, treesitter syntax, which-key hints
- Tokyodark color scheme with Nerd Font icons

**Terminal multiplexer (tmux)**
- `Ctrl-a` prefix, window switching via `Alt+1-9`

**Terminal emulator (Ghostty/iTerm2)**
- `Cmd+1-9` mapped to `Alt+1-9` for tmux window switching

## Requirements

- macOS (Homebrew)
- [Ghostty](https://ghostty.org/) or iTerm2
- A [Nerd Font](https://www.nerdfonts.com/) (the Brewfile installs one)

## Quick start

```bash
git clone https://github.com/ondrasek/nvim-agentic-devenv.git
cd nvim-agentic-devenv
make install
```

This runs the full bootstrap: installs Homebrew packages, CLI tools (ruff, direnv, etc.), and copies configs to `~/.config/`.

## Makefile targets

```bash
make install        # Full bootstrap (brew, tools, copy configs)
make copy           # Copy configs only (no brew install)
make diff           # Show differences between repo and installed configs
make setup-project  # Init current dir as dev project
```

Configs are **copied** (not symlinked). Use [chezmoi](https://www.chezmoi.io/) to track installed dotfiles — the bootstrap script detects it automatically.

## Key bindings

| Key | Action |
|-----|--------|
| `Space` | Leader key |
| `gd` | Go to definition |
| `grr` | Find references |
| `K` | Hover documentation |
| `gra` | Code actions |
| `grn` | Rename symbol |
| `<leader>cf` | Format file |
| `<leader>xx` | Toggle diagnostics panel |
| `<leader>st` | Search TODOs |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `gcc` | Toggle line comment |
| `Ctrl-a` | tmux prefix |

Run `:WhichKey` in Neovim to explore all bindings interactively.

## Repository structure

```
nvim/          Neovim config (→ ~/.config/nvim)
tmux/          tmux config
ghostty/       Ghostty terminal config (→ ~/.config/ghostty)
iterm2/        iTerm2 keybinding docs
setup/         Bootstrap scripts, Brewfile
docs/          Learning guides
plans/         Roadmap and phase documentation
samples/       Test files for verifying LSP/formatting
```

## Adding plugins

Create a file in `nvim/lua/plugins/` returning a [Lazy.nvim](https://lazy.folke.io/) spec:

```lua
return {
    "author/plugin-name",
    opts = {},
}
```

Run `:Lazy` in Neovim to install. Run `:Mason` to manage LSP servers and formatters.

## License

[Apache License 2.0](LICENSE)
