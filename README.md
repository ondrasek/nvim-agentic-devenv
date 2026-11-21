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
- AI assistant (devenv-agent) — inline chat with explain/do modes, Ollama (local) or Anthropic providers
- Agent pane — Claude Code or Pi in a side terminal (right or bottom by screen size) that works on the active buffer
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

`make copy` mirrors `nvim/` and `ghostty/` into `~/.config/` (it removes files there that are not in the repo). The first run backs up an existing config to `~/.config/nvim.pre-devenv` / `~/.config/ghostty.pre-devenv`. It never touches the installed `lazy-lock.json`, logs, or `.claude/`, and does not copy `tests/`.

## Quality checks

```bash
make check   # selene + stylua --check (lua, init.lua, tests) + lizard (CCN 20) + plenary tests
```

The agent-pane specs spawn a real pty (`cat`), so run `make test` in a normal terminal, not inside a sandbox that forbids pty creation.

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

| Key | Action |
|-----|--------|
| `<leader>aa` | Toggle AI chat |
| `<leader>ae` | AI explain (how to do something, with keybinding context) |
| `<leader>ad` | AI do (execute an action) |
| `<leader>ac` | Agent pane: toggle (hide/show keeps the session alive) |
| `<leader>ai` | Agent pane: ask about the active file; in visual mode, about the selection |
| `<leader>aw` | Agent pane: swap with the file tree (take turns on small displays) |
| `<leader>ab` | Agent pane: choose backend (`claude` / `pi`) |
| `<leader>ax` | Agent pane: close and end the session |

Custom lightweight chat plugin (devenv-agent). Floating window with streaming responses, keybinding-aware system prompt, and nvim command execution with approval. Uses Ollama locally by default (`qwen3-coder`), or Anthropic via `ANTHROPIC_API_KEY`. Switch with `:DevenvAgent provider anthropic`. Models and URLs are configurable: `setup({ providers = { anthropic = { model = "..." } } })`.

#### Agent pane (Claude Code / Pi)

A terminal split that runs a CLI coding agent next to your code. It opens on the **right** when the screen is at least 160 columns wide, otherwise at the **bottom** (`pane.layout` in the plugin opts). The agent runs in the repository root of the active file.

- **Context:** `<leader>ai` writes the file to disk, then sends your instruction plus the file path, cursor line (or the selected lines as a fenced block) to the agent as plain text. Agents read the file themselves, so there is no `@file` syntax to depend on.
- **Edits:** the agent edits files on disk; buffers reload automatically (`autoread` + a 2 s `checktime` timer while the pane exists).
- **Keys inside the pane:** `Esc` goes to the agent (interrupt/cancel). `Ctrl-q` leaves terminal mode so you can use window commands; `Ctrl-w` navigation works from normal mode.
- **Sharing the screen with the file tree:** `<leader>aw` alternates between the pane and neo-tree. With `pane.tree.swap = "auto"` (default) this also happens automatically when a right-hand pane would leave fewer than `tree.min_code_columns` (100) columns for code: opening the pane hides the tree, hiding the pane brings it back, and opening the tree hides the pane (its session keeps running). Set `tree.swap` to `true` to always alternate or `false` to never touch the tree. A bottom pane never competes with the tree for columns, so `auto` leaves the tree alone.
- **Pinned window:** the pane window is `winfixbuf`, so `:edit`, `--remote` from the review hook, etc. cannot replace the agent terminal (the command errors instead).
- **Commands:** `:DevenvAgent pane [claude|pi|close|swap]`, `:DevenvAgent send [text]`, `:DevenvAgent doctor` (shows which backends are installed and whether their env keys are set, never the values).
- **Secrets:** only keys listed in a backend's `env_keys` are injected (taken from the process environment, else the project's `.env`). `.env` is gitignored.
- **Sessions:** the agent runs in nvim's `:terminal`, so it inherits `$NVIM`; no `--listen` wrapper is required.

Claude Code works with no extra setup (`claude` on `PATH`).

**Pi with Ollama Cloud** — what is documented and what is not:

1. Install Pi (Node 22.19+): `npm install -g @earendil-works/pi-coding-agent` ([Pi README](https://github.com/earendil-works/pi), [Ollama's Pi page](https://docs.ollama.com/integrations/pi)). Ollama also offers `ollama launch pi --model <model>:cloud`, which configures Pi for you.
2. Create an API key at <https://ollama.com/settings/keys> and put `OLLAMA_API_KEY=...` in the project `.env` (or your shell environment).
3. Add a provider to `~/.pi/agent/models.json` (Pi supports `${ENV}` interpolation in `apiKey`; Ollama documents `https://ollama.com/v1` as its OpenAI-compatible cloud base URL):

   ```json
   {
     "providers": {
       "ollama-cloud": {
         "baseUrl": "https://ollama.com/v1",
         "api": "openai-completions",
         "apiKey": "${OLLAMA_API_KEY}",
         "models": [{ "id": "<model id from https://ollama.com/api/tags>" }]
       }
     }
   }
   ```

4. Select the model: `opts = { pane = { backends = { pi = { args = { "--model", "ollama-cloud/<model id>" } } } } }` in `nvim/lua/plugins/devenv-agent.lua`.

**Not verified end to end:** Pi's docs show only a *local* Ollama endpoint, and neither Pi nor Ollama documents this exact cloud combination. Each piece is documented separately; the combination, and Pi accepting the pasted multi-line prompts, were not run here. Run `:DevenvAgent doctor` first, then try `<leader>ab` → `pi`.

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
plugins/       Claude Code plugin (review-snapshot) and .claude-plugin marketplace
container/     Example Dockerfile for container workflows
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
