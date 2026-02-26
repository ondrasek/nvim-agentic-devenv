# nvim-agentic-devenv

Terminal-native development environment built on Neovim, tmux, and Ghostty. Replaces VSCode + devcontainers with hand-rolled, transparent config.

## What's included

**Editor (Neovim)**
- Multi-language LSP — Python, Rust, TypeScript/JS, Go, Elixir, C#, Lua
- Autocompletion (blink.cmp) with LSP, buffer, path, and snippet sources
- Format-on-save (conform.nvim) — ruff, rustfmt, prettier, gofmt, stylua, mix, csharpier
- Linting (nvim-lint) — eslint, golangci-lint; Python/Rust/Elixir/C# via LSP
- Diagnostics panel (trouble.nvim), TODO highlighting, auto-pairs
- Debugging (nvim-dap) — DAP UI, virtual text, Python debugpy, Mason adapter install
- Test runner (neotest) — inline pass/fail, adapters for Python, Rust, Go
- Git integration — gitsigns (hunk navigation/staging), lazygit (floating terminal)
- Navigation — telescope (fuzzy finder), flash.nvim (jump), aerial (code outline)
- Editing — mini.surround, mini.ai textobjects, treesitter textobjects, inc-rename (live preview)
- Refactoring — extract function/variable, inline variable
- Search and replace — grug-far.nvim (project-wide)
- UI — neo-tree (file explorer), bufferline (tabs), lualine (statusline with breadcrumbs), which-key, indent guides, dashboard
- Sessions — auto-save/restore per directory (persistence.nvim)
- Markdown rendering in-editor (render-markdown.nvim)
- AI assistant — three approaches: claudecode.nvim (Claude Code bridge), codecompanion.nvim (native AI chat), devenv-ai (custom lightweight chat)
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

This runs the full bootstrap: installs Homebrew packages, CLI tools, and copies configs to `~/.config/`.

## Makefile targets

```bash
make install        # Full bootstrap (brew, tools, copy configs)
make copy           # Copy configs only (no brew install)
make diff           # Show differences between repo and installed configs
make setup-project  # Init current dir as dev project
```

Configs are **copied** (not symlinked). Use [chezmoi](https://www.chezmoi.io/) to track installed dotfiles — the bootstrap script detects it automatically.

## Key bindings

The leader key is `Space`. Press it and wait for which-key to show available commands.

### Navigation

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (telescope) |
| `<leader>fg` | Live grep (telescope) |
| `<leader>fb` | Search buffers |
| `<leader>fr` | Recent files |
| `<leader>fh` | Help tags |
| `<leader>e` | Toggle file explorer |
| `<leader>E` | Reveal current file in explorer |
| `s` | Flash jump |
| `S` | Flash treesitter select |
| `<leader>cs` | Toggle code outline (aerial) |
| `<leader>cS` | Symbols nav (aerial) |

### LSP (Neovim 0.11 built-in + custom)

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `grr` | Find references |
| `K` | Hover documentation |
| `gra` | Code actions |
| `grn` | Rename symbol (live preview) |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `gO` | Document symbols |
| `[d` / `]d` | Previous/next diagnostic |
| `<leader>cd` | Line diagnostics float |
| `<leader>cf` | Format file |

### Editing

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gsa` | Add surrounding |
| `gsd` | Delete surrounding |
| `gsr` | Replace surrounding |
| `af` / `if` | Select around/inside function |
| `ac` / `ic` | Select around/inside class |
| `]f` / `[f` | Next/previous function |
| `]c` / `[c` | Next/previous class |

### Refactoring

| Key | Action |
|-----|--------|
| `<leader>re` | Extract function (visual) |
| `<leader>rv` | Extract variable (visual) |
| `<leader>ri` | Inline variable |
| `<leader>sr` | Search and replace (grug-far) |

### Git

| Key | Action |
|-----|--------|
| `<leader>gg` | Open lazygit |
| `]h` / `[h` | Next/previous hunk |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghb` | Blame line |
| `<leader>ghS` | Stage buffer |
| `<leader>ghR` | Reset buffer |

### Debugging

| Key | Action |
|-----|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Continue / start |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>du` | Toggle DAP UI |
| `<leader>dr` | Toggle REPL |

### Testing

| Key | Action |
|-----|--------|
| `<leader>tt` | Run nearest test |
| `<leader>tf` | Run file tests |
| `<leader>td` | Debug nearest test |
| `<leader>ts` | Toggle test summary |
| `<leader>to` | Show test output |
| `]t` / `[t` | Next/previous failed test |

### Diagnostics

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle workspace diagnostics |
| `<leader>xd` | Toggle buffer diagnostics |
| `<leader>xq` | Toggle quickfix |
| `<leader>st` | Search TODOs |

### Buffers and sessions

| Key | Action |
|-----|--------|
| `<leader>bn` | Next buffer |
| `<leader>bp` | Previous buffer |
| `<leader>bd` | Close buffer |
| `<leader>qs` | Restore session (cwd) |
| `<leader>qS` | Select session |
| `<leader>ql` | Restore last session |

### AI Assistant

Three approaches are included for evaluation. All share `<leader>a` as the AI group.

| Key | Action |
|-----|--------|
| `<leader>a1` | Toggle Claude Code terminal (claudecode.nvim) |
| `<leader>a2` | Toggle CodeCompanion chat |
| `<leader>a3` | Toggle DevenvAI chat |
| `<leader>ae` | Explain (how to do something, with keybinding context) |
| `<leader>ad` | Do it (execute an action via AI) |
| `<leader>as` | Send visual selection to Claude Code |

**Approach 1 — claudecode.nvim**: WebSocket bridge to Claude Code CLI. Toggle with `<leader>a1`. Requires Claude Code running.

**Approach 2 — codecompanion.nvim**: Native nvim AI chat with Ollama (local, default) or Anthropic. `/explain` and `/do` slash commands in chat. Toggle with `<leader>a2`.

**Approach 3 — devenv-ai**: Custom lightweight chat plugin. Floating window, streaming responses, nvim command execution with approval. `:DevenvAI explain` / `:DevenvAI do`. Toggle with `<leader>a3`.

### Terminal

| Key | Action |
|-----|--------|
| `Ctrl-/` | Toggle floating terminal |
| `<leader>gg` | Lazygit (floating) |
| `Ctrl-a` | tmux prefix |

Run `:WhichKey` in Neovim to explore all bindings interactively.

## Repository structure

```
nvim/          Neovim config (-> ~/.config/nvim)
tmux/          tmux config
ghostty/       Ghostty terminal config (-> ~/.config/ghostty)
iterm2/        iTerm2 keybinding docs
setup/         Bootstrap scripts, Brewfile
docs/          Tutorial and learning guides
plans/         Roadmap and phase documentation
samples/       Test files for verifying LSP/formatting (Python, Rust, TS, Go, Elixir, C#, Lua)
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
