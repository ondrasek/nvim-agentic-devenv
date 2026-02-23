# Interactive Learning Guide: tmux + nvim for Agentic Development

A hands-on tutorial for the nvim-agentic-devenv setup. Open this in a Claude Code session
(e.g., `@docs/learning-guide.md`) for interactive guidance.

---

## Section 1: tmux Essentials

### Starting tmux

The quickest way to get going:

```bash
# Start the standard 3-window dev session
bash ~/Git/ondrasek/nvim-agentic-devenv/setup/tmux-session.sh
```

This creates windows: `1:claude`, `2:nvim`, `3:shell`.

> **Try this now:** Run the command above. You should see a tmux status bar at the bottom.

### The Prefix Key

All tmux commands start with the **prefix**: `Ctrl-a`.

Press `Ctrl-a`, release, then press the command key. For example:
- `Ctrl-a d` — detach from session (exit without closing)
- `Ctrl-a ?` — show all keybindings

> **Try this now:** Press `Ctrl-a ?` to see the help screen. Press `q` to close it.

### Window Management

| Action | Keys |
|--------|------|
| Switch to window N | `Cmd+N` or `Alt+N` (1-9) |
| Create new window | `Ctrl-a c` |
| Rename window | `Ctrl-a ,` |
| Close window | Type `exit` in the shell |
| Next window | `Ctrl-a n` |
| Previous window | `Ctrl-a p` |

> **Try this now:** Press `Cmd+2` to go to the nvim window, then `Cmd+1` to come back.

### Pane Splitting

Split the current window into multiple panes:

| Action | Keys |
|--------|------|
| Split horizontally (side by side) | `Ctrl-a \|` |
| Split vertically (top/bottom) | `Ctrl-a -` |
| Move between panes | `Ctrl-a h/j/k/l` |
| Close pane | Type `exit` or `Ctrl-d` |

> **Try this now:** In window 3 (shell), press `Ctrl-a |` to split, then `Ctrl-a h` and `Ctrl-a l` to move between panes.

### Copy Mode (Scrollback)

| Action | Keys |
|--------|------|
| Enter copy mode | `Ctrl-a [` |
| Scroll up/down | Arrow keys or `j`/`k` |
| Search | `/` (forward) or `?` (backward) |
| Exit copy mode | `q` |

### Session Management

```bash
tmux ls                    # List sessions
tmux attach -t dev         # Attach to "dev" session
tmux kill-session -t dev   # Kill "dev" session
```

> **Ask Claude Code:** "How do I switch between tmux sessions?"

### Common Gotchas

- **Nested tmux:** If you see a double status bar, you're running tmux inside tmux. Detach the inner one with `Ctrl-a d`.
- **Prefix confusion:** If keys aren't working, make sure you pressed `Ctrl-a` first (not `Ctrl-b`, the default).
- **Escape delay:** Our config sets `escape-time 10` so nvim's Escape key works instantly.

---

## Section 2: nvim Quick Reference

### The Leader Key

The **leader key** is `Space`. Many keybindings start with leader.

Press `Space` and wait — **which-key** will pop up showing available commands.

> **Try this now:** Open nvim (`nvim .`), press `Space`, and read the which-key popup.

### File Navigation

| Action | Keys | Description |
|--------|------|-------------|
| Find files | `<leader>ff` | Fuzzy search file names (Telescope) |
| Live grep | `<leader>fg` | Search file contents (Telescope) |
| Buffers | `<leader>fb` | Switch between open files |
| Recent files | `<leader>fr` | Recently opened files |
| Help | `<leader>fh` | Search nvim help tags |

> **Try this now:** Press `Space f f` to find a file. Type part of a filename and press Enter.

### File Explorer (mini.files)

| Action | Keys |
|--------|------|
| Open at current file | `<leader>e` |
| Open at project root | `<leader>E` |
| Navigate into | `l` or `Enter` |
| Navigate up | `h` |
| Create file | Type name in empty line, press `=` to sync |
| Delete/rename | Edit the file listing, press `=` to sync |
| Close | `q` |

mini.files works like a buffer — you edit the directory listing, then press `=` to apply changes.

> **Try this now:** Press `Space e` to open the file explorer. Navigate around with `h` and `l`.

### Git Gutter (gitsigns)

When editing files in a git repo, the sign column shows:
- `+` — added line
- `~` — changed line
- `_` — deleted line (shown below the deletion)

These update automatically as you edit.

### Buffer Management

| Action | Keys |
|--------|------|
| List buffers | `<leader>fb` |
| Close buffer | `:bd` |
| Next buffer | `:bn` |
| Previous buffer | `:bp` |

### Plugin Manager

Run `:Lazy` to open the plugin manager. From there:
- **I** — Install missing plugins
- **U** — Update plugins
- **X** — Clean unused plugins
- **C** — Check for updates
- **q** — Close

> **Try this now:** Type `:Lazy` and press Enter. Press `q` to close.

### Useful Built-in Commands

| Command | Action |
|---------|--------|
| `:w` | Save file |
| `:q` | Quit (or `:q!` to force) |
| `:wq` | Save and quit |
| `u` | Undo |
| `Ctrl-r` | Redo |
| `/pattern` | Search forward |
| `n` / `N` | Next / previous search match |
| `*` | Search word under cursor |

---

## Section 3: The Combined Workflow

### Standard Session Layout

```
Window 1: claude  — Claude Code (primary workspace)
Window 2: nvim    — editor for browsing and quick edits
Window 3: shell   — git, testing, manual commands
```

Switch between them with `Cmd+1`, `Cmd+2`, `Cmd+3`.

### When to Use What

| Task | Tool |
|------|------|
| Writing new code, refactoring | Claude Code (window 1) |
| Browsing code, quick edits | nvim (window 2) |
| Reading code with syntax highlighting | nvim (window 2) |
| Git operations, running tests | shell (window 3) |
| Complex multi-file changes | Claude Code (window 1) |
| Reviewing diffs | shell (window 3): `git diff` |

### Workflow Pattern

1. **Cmd+1** — Describe the task to Claude Code
2. Claude Code makes changes → auto-saved to disk
3. **Cmd+2** — Review changes in nvim (gitsigns shows modified lines)
4. **Cmd+3** — Run tests, check `git diff`, commit if happy
5. **Cmd+1** — Continue with next task

### Copy/Paste

Everything uses the system clipboard:
- **nvim:** `y` to yank (copies to system clipboard via `clipboard = "unnamedplus"`)
- **tmux:** Mouse select copies automatically; `Cmd+V` pastes
- **Between tools:** System clipboard works across all — copy in nvim, paste in Claude Code, etc.

> **Ask Claude Code:** "What's the fastest way to copy a function from nvim to discuss with you?"

---

## Section 4: Cheat Sheet

### tmux (prefix: Ctrl-a)

| Category | Action | Keys |
|----------|--------|------|
| **Windows** | Switch to window N | `Cmd+N` / `Alt+N` |
| | New window | `Ctrl-a c` |
| | Rename window | `Ctrl-a ,` |
| **Panes** | Split horizontal | `Ctrl-a \|` |
| | Split vertical | `Ctrl-a -` |
| | Navigate panes | `Ctrl-a h/j/k/l` |
| **Session** | Detach | `Ctrl-a d` |
| | Reload config | `Ctrl-a r` |
| **Copy** | Enter copy mode | `Ctrl-a [` |

### nvim (leader: Space)

| Category | Action | Keys |
|----------|--------|------|
| **Files** | Find files | `Space f f` |
| | Live grep | `Space f g` |
| | Buffers | `Space f b` |
| | Recent files | `Space f r` |
| **Explorer** | Open (current file) | `Space e` |
| | Open (cwd) | `Space E` |
| | Navigate | `h` / `l` / `Enter` |
| | Apply changes | `=` |
| **Git** | (automatic gutter signs) | `+` `~` `_` |
| **Help** | Show keybindings | `Space ?` |
| | Plugin manager | `:Lazy` |
| **Editing** | Save | `:w` (or just switch away — auto-save) |
| | Undo / Redo | `u` / `Ctrl-r` |
| | Search | `/pattern` |
