# nvim-agentic-devenv

Local nvim-based agentic development environment. Replaces VSCode + devcontainers with terminal-native tools.

## Repository Structure

- `nvim/` — Neovim config (copied to `~/.config/nvim`)
- `tmux/` — tmux config
- `ghostty/` — Ghostty terminal config (copied to `~/.config/ghostty`)
- `iterm2/` — iTerm2 keybinding documentation
- `setup/` — Bootstrap scripts, Brewfile, project setup
- `nvim/lua/devenv-agent/` — Custom AI assistant plugin (local, loaded via Lazy `dir` field)
- `nvim/docs/` — Keybinding reference (deployed with nvim config, used by AI plugins)
- `docs/` — Learning guides and references
- `.claude/hooks/` — Claude Code hooks (quality-gate on Stop, per-edit-fix, review-snapshot, session-start)
- `plugins/review-snapshot/` — Claude Code plugin; its hook script duplicates `.claude/hooks/review-snapshot.sh` (edit both)
- `container/`, `samples/` — example Dockerfile; LSP/format sample files

## Key Conventions

- **Plugin management:** Lazy.nvim. Each plugin is a separate file in `nvim/lua/plugins/` returning a spec table. Lazy auto-imports all files via `{ import = "plugins" }` in `lua/config/lazy.lua`. **All new plugins MUST be added as a Lazy.nvim spec file in `nvim/lua/plugins/`.** Never install plugins any other way. For local plugins, use the `dir` field in the spec (see `devenv-agent.lua` for an example).
- **Leader key:** Space (`<leader>`)
- **tmux prefix:** `Ctrl-a`
- **Terminal keybindings:** `Cmd+1-9` maps to `Alt+1-9` (via Ghostty/iTerm2), which tmux maps to window switching.
- **AI keybinding group:** `<leader>a` — devenv-agent. Default is the contextual **chat** (`chat.lua` + `chat_backends.lua`: two plain nvim buffers, headless Claude Code/Pi per turn; keys `ac` toggle, `ai` ask, `af` focus, `am` ask/edit mode, `an` new, `aw` swap with tree, `ab` backend, `ax` close). `pane.lua` is the full terminal TUI (`aT`). Context is plain text, never agent-specific `@file` syntax. Embedded Claude (chat + terminal) runs with hooks disabled (`backends.claude.hooks=false`); chat has no shell tool.
- **nvim socket:** one convention everywhere — `<repo>/.claude/.nvim-socket` (nvim-review, tmux-session, hooks), always probed with `--remote-expr 1` before use; never `--remote-send ":edit <path>"` (injection) — use `--remote <path>`.
- **Secrets:** `.env` is gitignored (a symlink to `~/.local/_env`); never read or print it. Agents get only allowlisted `env_keys` (e.g. `OLLAMA_API_KEY`).
- **Keymap docs:** `nvim/docs/keybinding-reference.md` is injected into the chat system prompt — update it whenever a keymap changes.

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

## Quality Tools

```bash
make lint           # Run selene linter
make format         # Format with stylua
make test           # Run plenary.nvim tests
make check          # Full quality gate (lint + format check + complexity + tests)
```

Tools: selene (linter), stylua (formatter, also covers `nvim/tests/`), lizard (complexity), plenary.nvim (tests).
Config: `selene.toml`, `.stylua.toml`. Complexity threshold: CCN 20.
Tests live in `nvim/tests/` and use `nvim/tests/minimal_init.lua` for headless runs.

## Gotchas (learned the hard way)

- **Never `cd` in Bash tool calls** — cwd persists and drifts into `nvim/`, which broke stylua config lookup and littered `.claude/` dirs. Use absolute paths or `git -C`.
- **`make test` needs a pty** (pane specs spawn `cat`): in a sandbox it fails with `E903 ... operation not permitted`; run it unsandboxed. Run specs through `make test` — `PlenaryBustedFile` spawns without `minimal_init` and loads the installed config.
- **`make copy` mirrors `nvim/` into `~/.config/nvim`** (removes extras; protects lockfile/logs; one-time `.pre-devenv` backup) and replaces tmux.conf. **Ghostty is seed-only** — never overwrite/mirror `~/.config/ghostty` (user rule). Don't run it casually.
- `jobstart` rejects an empty `env = {}` (E475): only pass non-empty tables.
- Plenary delivers curl stdout one complete line per callback (newline stripped) — parse per line, never wait for `\n`.
