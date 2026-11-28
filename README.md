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
- Agent chat — a contextual assistant in two ordinary nvim buffers (right or bottom by screen size), backed by Claude Code or Pi headless; full terminal TUI available too
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
make agent-image    # Build the Pi container image for the agent chat (needs Apple's `container`)
make chezmoi-sync   # Track the installed configs in chezmoi on its own (shows a plan, asks; `make copy` runs it for you)
```

Configs are **copied** (not symlinked). Use [chezmoi](https://www.chezmoi.io/) to track installed dotfiles: `make chezmoi-sync` adds exactly the files this repo installs, plus the live `~/.config/nvim/lazy-lock.json` (your actual plugin versions; run it again after `:Lazy update`), and forgets entries `make copy` mirrored away (otherwise `chezmoi apply` would resurrect them). `make copy` runs it for you (plan printed, no question asked) when chezmoi is installed; chezmoi's `git.autopush` setting then commits **and pushes** to your dotfiles remote. `make copy CHEZMOI=0` skips it, `make copy CHEZMOI_ARGS=--dry-run` shows the plan only, and if the sync fails the copy still stands. `make install` runs the same script (same `CHEZMOI=0` / `CHEZMOI_ARGS` switches).

`make copy` mirrors `nvim/` into `~/.config/nvim` (it removes files there that are not in the repo) and replaces `~/.config/tmux/tmux.conf`. The first run backs up an existing nvim config to `~/.config/nvim.pre-devenv`. It never touches the installed `lazy-lock.json`, logs, or `.claude/`, and does not copy `tests/`.

**Ghostty is never overwritten.** `ghostty/config` is installed only if `~/.config/ghostty/config` does not exist; otherwise it is skipped. `make diff` shows how yours differs from the repo's.

## Quality checks

```bash
make check   # selene + stylua --check (lua, init.lua, tests) + lizard (CCN 20) + plenary tests
```

The agent-pane specs spawn a real pty (`cat`), so run `make test` in a normal terminal, not inside a sandbox that forbids pty creation.

## Key bindings

**Quitting:** one `:q` from your last file window quits nvim; the file tree, agent chat/terminal, outline, diagnostics and quickfix panels never keep it open (`config/quit.lua`). `:q` inside a panel closes just that panel, and with several file windows it closes one. `:qa` quits everything from anywhere. This config sets `autowriteall`, so quitting **saves** modified files; use `:q!` / `:qa!` to discard.

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
| `<leader>ac` | Agent chat: toggle (hide/show keeps the conversation) |
| `<leader>ai` | Agent chat: ask about the active file; in visual mode, about the selection |
| `<leader>af` | Agent chat: focus the input |
| `<leader>am` | Agent chat: mode ask (read-only) <-> edit |
| `<leader>an` | Agent chat: new conversation |
| `<leader>aw` | Agent chat: swap with the file tree (take turns on small displays) |
| `<leader>ab` | Agent chat: choose backend (`claude` / `pi`) |
| `<leader>ax` | Agent chat: close and end the conversation |
| `<leader>aT` | Agent terminal: the full Claude Code / Pi TUI in a terminal split |
| `<leader>aI` | Agent terminal: send the active file (visual: selection) as context |

Custom lightweight chat plugin (devenv-agent). Floating window with streaming responses, keybinding-aware system prompt, and nvim command execution with approval. Uses Ollama locally by default (`qwen3-coder`), or Anthropic via `ANTHROPIC_API_KEY`. Switch with `:DevenvAgent provider anthropic`. Models and URLs are configurable: `setup({ providers = { anthropic = { model = "..." } } })`.

#### Agent chat (contextual assistant)

Two ordinary nvim buffers, docked on the **right** (screens of 160+ columns) or **bottom**: a read-only markdown **transcript** above a small **input** buffer. Because they are plain buffers, every nvim motion, operator, search, yank and window command works; there is no terminal mode to escape from.

- **Auto-open:** when nvim starts on a file, the chat opens by itself beside it with the cursor left in your file. It starts no agent process until you send a message. On a screen too narrow for tree + file + chat (under 100 code columns) the chat wins at startup and the tree is parked; `<leader>aw` or `<leader>e` brings the tree back (and hides the chat while they cannot share). Disable with `chat = { auto_open = false }` in `nvim/lua/plugins/devenv-agent.lua`.
- **Typing:** `<leader>ac` opens the chat with the cursor in the input. Edit with normal nvim keys; `<CR>` (normal mode) or `<C-s>` (insert mode) sends. `<C-c>` cancels a running turn, `q` in the transcript hides the chat, `i`/`a` in the transcript jump to the input. `<leader>ai` asks without opening the input (visual mode: about the selection).
- **Context:** each message automatically carries the active file and cursor line (or the selected lines). Unsaved edits are written first. The transcript shows only what you typed plus a `📎 file:lines` line.
- **Backends (headless, one process per turn):** Claude Code (`claude -p --output-format stream-json`) and Pi (`pi --mode json`). The conversation continues with Claude's `--resume <session>` / Pi's `--session-id`. Opening a file in another git repository starts a new conversation; a session that cannot be resumed is dropped and the next message starts fresh.
- **Modes:** `edit` (default) lets the agent change files inside the project: Claude gets `--tools Read,Grep,Glob,Edit,Write --permission-mode acceptEdits`, Pi gets `--tools read,edit,write`. `<leader>am` switches to `ask`, which is read-only (`Read,Grep,Glob` with `dontAsk` / Pi `read`). The winbar always shows the current mode. Neither mode has a shell tool, and edits outside the project directory are denied. After each turn open buffers reload from disk. Pi's docs say it never asks for approval before a tool call, so for Pi the tool allowlist is the only guard.
- **Containment (Pi):** Pi has no sandbox and asks no approvals, so by default the chat runs it in an **Apple container** (Apple's `container` CLI: a lightweight Linux VM per turn). The agent sees only the **current directory tree** (nvim's cwd, or the active file's directory when the file lies outside it), mounted read-write; your home directory, ssh keys, `~/.local/_env` and other projects do not exist inside the VM. The **network stays open** so tool calls and web search work: `web_search` / `web_fetch` go through Ollama Cloud via a small extension baked into the image (the stock `@ollama/pi-web-search` only talks to a local Ollama daemon, which does not exist inside the VM). One-time setup: `make agent-image` (starts the container service, builds `devenv-pi:latest` from `containers/pi/Containerfile`, which pins Pi 1.6.0). Pi also gets private state (its sessions and a generated `models.json` with only `${ENV}`-referenced providers), so your real `~/.pi` and its extensions are not used. `chat.containment` = `dir` (default) | `file` (only the active file; uses the Seatbelt engine because a container cannot share a single file) | `none`; `chat.containment_engine` = `container` (default) | `seatbelt` (macOS `sandbox-exec`, which Apple marks deprecated). Switch live with `:DevenvAgent chat scope dir|file|none`; the winbar shows scope and engine. It **fails closed**: if the service is down or the image is missing, Pi does not start and the transcript says what to run. Cancelling a turn kills its container. **Limits:** needs Apple's `container` (Apple silicon); about 2 s startup per turn (measured warm); inside the scope directory the agent can read and write everything, **including any `.env` there** (only the Seatbelt engine denies `.env*`), and with the network open anything it can read can be sent out; the builder VM from `make agent-image` keeps running until `container builder stop`; **Claude is not contained**: it is limited by tool allowlist and project directory only.
- **Hooks:** the embedded Claude (chat and terminal) runs with **all hooks disabled** (`--settings '{"disableAllHooks":true}'`), otherwise your project's Stop hooks (quality gate, auto-commit) would fire inside the editor. One setting controls both: `pane = { backends = { claude = { hooks = true } } }` re-enables them.
- **Settings:** extra CLI flags go in `pane.backends.<name>.args` (for example Pi's `--model`), shared with the terminal pane.
- **Commands:** `:DevenvAgent chat [new|mode|cancel|swap|close|backend <name>|scope dir|file|none]`, `:DevenvAgent send [text]`.
- **Tested how:** end to end with the real Claude Code 2.1.330 (streaming, tool use; `ask` could not edit a file, `edit` did) and the real Pi 0.84.3 through Ollama Cloud (streaming, tool use, memory across turns via `--session-id`, `ask` declined to edit). Specs replay trimmed fixtures from those runs. Latency is real: a trivial first Claude turn took about 26 s to the first token in one measurement.

#### Agent terminal (full Claude Code / Pi TUI, `<leader>aT`)

A terminal split that runs the full CLI coding agent next to your code (use the chat above for a contextual assistant that keeps nvim keys). It opens on the **right** when the screen is at least 160 columns wide, otherwise at the **bottom** (`pane.layout` in the plugin opts). The agent runs in the repository root of the active file.

- **Context:** `<leader>ai` writes the file to disk, then sends your instruction plus the file path, cursor line (or the selected lines as a fenced block) to the agent as plain text. Agents read the file themselves, so there is no `@file` syntax to depend on.
- **Context for the terminal agent:** `<leader>aI` sends the active file (visual mode: the selection) as plain text. Typed prompts carry no file context unless you opt in with `backends.claude.active_file_hook = true` (a per-launch `UserPromptSubmit` hook asking nvim over `$NVIM`); that requires `hooks = true`, because `disableAllHooks` also silences hooks defined in the same `--settings` (checked with a real run).
- **Edits:** the agent edits files on disk; buffers reload automatically (`autoread` + a 2 s `checktime` timer while the pane exists).
- **Keys inside the pane:** `Esc` goes to the agent (interrupt/cancel). `Ctrl-q` jumps straight back to the code window; `Ctrl-\` then `h/j/k/l` moves to the window left/down/up/right (works without Alt/Option; disable or remap with `pane.nav_keys`). Returning to the pane (`<leader>af`, a window command, `Ctrl-\ h/j/k/l`) resumes typing; `Ctrl-\ Ctrl-n` enters normal mode in the pane for scrolling and copying.
- **Sharing the screen with the file tree:** `<leader>aw` alternates between the pane and neo-tree. With `pane.tree.swap = "auto"` (default) this also happens automatically when a right-hand pane would leave fewer than `tree.min_code_columns` (100) columns for code: opening the pane hides the tree, hiding the pane brings it back, and opening the tree hides the pane (its session keeps running). Set `tree.swap` to `true` to always alternate or `false` to never touch the tree. A bottom pane never competes with the tree for columns, so `auto` leaves the tree alone.
- **Pinned window:** the pane window is `winfixbuf`, so `:edit`, `--remote` from the review hook, etc. cannot replace the agent terminal (the command errors instead).
- **Commands:** `:DevenvAgent pane [claude|pi|close|swap]`, `:DevenvAgent send [text]`, `:DevenvAgent doctor` (shows which backends are installed and whether their env keys are set, never the values).
- **Secrets:** only keys listed in a backend's `env_keys` are injected (taken from the process environment, else the project's `.env`). `.env` is gitignored.
- **Sessions:** the agent runs in nvim's `:terminal`, so it inherits `$NVIM`; no `--listen` wrapper is required.

Claude Code works with no extra setup (`claude` on `PATH`).

**Pi with Ollama Cloud** (direct, `https://ollama.com/v1`; Pi's default route here, shipped as `--model ollama-cloud/kimi-k3`):

1. Install Pi (Node 22.19+): `npm install -g @earendil-works/pi-coding-agent` ([Pi README](https://github.com/earendil-works/pi)).
2. Create an API key at <https://ollama.com/settings/keys> and put `OLLAMA_API_KEY=...` in the project `.env`, in `~/.local/_env`, or in your shell environment (searched in that order; only `OLLAMA_API_KEY` is ever read, never printed).
3. Add a provider to `~/.pi/agent/models.json`. Pi expands `${OLLAMA_API_KEY}` in `apiKey`, so the key itself stays out of the file. Cloud model ids have no `:cloud` suffix (list: <https://ollama.com/api/tags>):

   ```json
   {
     "providers": {
       "ollama-cloud": {
         "baseUrl": "https://ollama.com/v1",
         "api": "openai-completions",
         "apiKey": "${OLLAMA_API_KEY}",
         "models": [{ "id": "kimi-k3" }, { "id": "glm-5.2" }, { "id": "minimax-m3" }]
       }
     }
   }
   ```

4. Pick another model with `pane.backends.pi.args = { "--model", "ollama-cloud/<model id>" }` in `nvim/lua/plugins/devenv-agent.lua`.

**Verified:** the chat (`<leader>ac`, backend `pi`) ran a real turn against this route: streaming, tool use, memory across turns, and `ask` mode declining an edit. **Not verified:** pasting multi-line prompts into the Pi TUI in the terminal pane (`<leader>aT`). Run `:DevenvAgent doctor` to check the backends and key.

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
