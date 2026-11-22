# Keybinding Reference

Complete keybinding reference for the nvim-agentic-devenv environment.

Leader key: `Space` (`<leader>`). Press Space and wait for which-key popup.

## Leader Groups

| Key | Group | Contains |
|-----|-------|----------|
| `<leader>a` | AI | chat toggle, explain mode, do mode, agent pane (Claude Code / Pi) |
| `<leader>b` | Buffer | next, previous, close |
| `<leader>c` | Code | diagnostics, format, outline |
| `<leader>d` | Debug | breakpoints, stepping, UI, REPL |
| `<leader>e` | Explorer | toggle, reveal |
| `<leader>f` | Find | files, grep, buffers, recent, help |
| `<leader>g` | Git | lazygit, hunk operations |
| `<leader>q` | Session | restore, select, last |
| `<leader>r` | Refactor | extract, inline |
| `<leader>s` | Search | TODOs, search-and-replace |
| `<leader>t` | Test | run, debug, summary, output |
| `<leader>x` | Diagnostics | workspace, buffer, quickfix |

## AI Assistant

| Key | Action |
|-----|--------|
| `<leader>aa` | Toggle AI chat |
| `<leader>ae` | AI explain (ask how to do something) |
| `<leader>ad` | AI do (execute an action) |
| `<leader>ac` | Agent chat toggle (two ordinary nvim buffers: transcript + input; hiding keeps the conversation) |
| `<leader>ai` | Ask the agent chat about the active file (visual mode: about the selection) |
| `<leader>af` | Focus the agent chat input |
| `<leader>am` | Agent chat mode: ask (read-only) <-> edit (agent may change files) |
| `<leader>an` | Agent chat: new conversation |
| `<leader>aw` | Swap agent chat and file tree (whichever shows makes room for the other) |
| `<leader>ab` | Choose agent backend (claude / pi) |
| `<leader>ax` | Close the agent chat and end the conversation |
| `<leader>aT` | Agent terminal: full Claude Code / Pi TUI in a terminal split |

Agent chat: type in the input buffer with normal nvim keys; `<CR>` (normal mode) or `<C-s>` (insert mode) sends, `<C-c>` cancels a running turn, `q` in the transcript hides it. Every message carries the active file (or selection) automatically. All normal nvim motions and window commands work in both buffers.

Inside the agent terminal (`<leader>aT`): `Esc` goes to the agent. `Ctrl-q` jumps straight back to the code window. `Ctrl-\ h/j/k/l` (press `Ctrl-\`, release, then the letter) move to the window left/down/up/right.
Coming back to the pane (`<leader>af`, `Ctrl-w` commands, `Ctrl-\ h/j/k/l`) resumes typing. `Ctrl-\ Ctrl-n` enters normal mode inside the pane to scroll or copy.
The pane opens on the right on wide screens (160+ columns), otherwise at the bottom.
On a right-hand pane with little room left for code (under 100 columns), the file tree and the pane take turns automatically:
opening one hides the other (the agent session keeps running). `<leader>aw` swaps them explicitly; `<leader>e` brings the tree back.

Also available as commands: `:DevenvAgent explain`, `:DevenvAgent do`, `:DevenvAgent toggle`,
`:DevenvAgent chat [new|mode|cancel|swap|close|backend <name>]`, `:DevenvAgent pane [claude|pi|close|swap]` (terminal), `:DevenvAgent send [text]`, `:DevenvAgent doctor`.
Switch provider: `:DevenvAgent provider ollama` or `:DevenvAgent provider anthropic`.

## Navigation

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

## LSP

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

## Editing

| Key | Action |
|-----|--------|
| `gcc` | Toggle line comment |
| `gc` | Toggle comment (visual) |
| `gsa` + motion + char | Add surrounding (e.g. `gsaiw"`) |
| `gsd` + char | Delete surrounding (e.g. `gsd"`) |
| `gsr` + old + new | Replace surrounding (e.g. `gsr"'`) |
| `vif` / `vaf` | Select inside/around function |
| `vic` / `vac` | Select inside/around class |
| `]f` / `[f` | Next/previous function |
| `]c` / `[c` | Next/previous class |

## Refactoring

| Key | Action |
|-----|--------|
| `<leader>re` | Extract function (visual) |
| `<leader>rv` | Extract variable (visual) |
| `<leader>ri` | Inline variable |
| `<leader>rf` | Extract block |
| `<leader>rF` | Extract block to file |
| `<leader>sr` | Search and replace (grug-far) |

## Git

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

## Debugging

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

### Python-specific debug

| Key | Action |
|-----|--------|
| `<leader>dPt` | Debug test method |
| `<leader>dPc` | Debug test class |

## Testing

| Key | Action |
|-----|--------|
| `<leader>tt` | Run nearest test |
| `<leader>tf` | Run file tests |
| `<leader>td` | Debug nearest test |
| `<leader>ts` | Toggle test summary |
| `<leader>to` | Show test output |
| `<leader>tO` | Toggle output panel |
| `<leader>tS` | Stop running test |
| `]t` / `[t` | Next/previous failed test |

## Diagnostics

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle workspace diagnostics |
| `<leader>xd` | Toggle buffer diagnostics |
| `<leader>xq` | Toggle quickfix |
| `<leader>st` | Search TODOs |

## Buffers and Sessions

| Key | Action |
|-----|--------|
| `<leader>bn` | Next buffer |
| `<leader>bp` | Previous buffer |
| `<leader>bd` | Close buffer |
| `<leader>qs` | Restore session (cwd) |
| `<leader>qS` | Select session |
| `<leader>ql` | Restore last session |
| `<leader>qd` | Stop auto-saving |

## Terminal and tmux

| Key | Action |
|-----|--------|
| `Ctrl-/` | Toggle floating terminal |
| `<leader>gg` | Lazygit (floating) |
| `<leader>t` | Open a terminal buffer (shares its prefix with the `<leader>t*` test keys, so it fires after a short timeout) |
| `Esc` (terminal mode) | Leave terminal mode (not in the agent pane, where it goes to the agent) |
| `Ctrl-a` | tmux prefix |
| `Cmd+1-9` | Switch tmux windows (via Ghostty/iTerm2 mapping to Alt+1-9) |

## Format-on-save languages

Python (ruff), Rust (rustfmt), TypeScript/JS (prettier), Go (gofmt), Lua (stylua), Elixir (mix), C# (csharpier).
