# Tutorial: Getting the Most Out of Your Neovim IDE

A hands-on walkthrough of every major feature in this config. Work through it section by section — each one builds on the last.

Open a sample file to follow along:

```bash
cd nvim-agentic-devenv
nvim samples/python/main.py
```

---

## 1. Orientation

When nvim opens, you'll see:

- **Left sidebar** — neo-tree file explorer
- **Top bar** — bufferline tabs showing open files
- **Bottom bar** — lualine statusline with mode, branch, filename, breadcrumbs, diagnostics
- **Editor** — the main editing area (auto-focused on startup)

Press `Space` and wait. **which-key** pops up showing every available command group: Buffer, Code, Debug, Find, Git, Refactor, Search, Session, Test, Diagnostics. Press any key to drill into a group, or `Esc` to cancel.

### File explorer

| Do this | Keys |
|---------|------|
| Toggle explorer | `<leader>e` |
| Reveal current file | `<leader>E` |
| Navigate into folders | `Enter` |
| Open file | `Enter` on a file |

### Finding things

| Do this | Keys |
|---------|------|
| Find a file by name | `<leader>ff` then type part of the name |
| Search file contents | `<leader>fg` then type a pattern |
| Switch open buffers | `<leader>fb` |
| Recent files | `<leader>fr` |

Try it: press `<leader>ff`, type `main`, and see all the sample files.

---

## 2. Language Intelligence (LSP)

Open `samples/python/main.py`. The LSP servers start automatically.

### Hover and navigation

| Do this | Keys |
|---------|------|
| Hover docs | `K` on any symbol |
| Go to definition | `gd` on `User` in `find_user` |
| Find references | `grr` on `greeting` |
| Go to implementation | `gri` |
| Go to type definition | `grt` |
| Document symbols | `gO` — shows all functions/classes in the file |

Try it: put your cursor on `User` in the `find_user` function signature and press `gd`. You'll jump to the class definition. Press `Ctrl-o` to jump back.

### Diagnostics

The file has `import sys` — an unused import. ruff flags it with a warning in the sign column.

| Do this | Keys |
|---------|------|
| See diagnostic message | `<leader>cd` |
| Next/previous diagnostic | `]d` / `[d` |
| Diagnostics panel | `<leader>xx` |
| Buffer diagnostics only | `<leader>xd` |

### Code actions and rename

| Do this | Keys |
|---------|------|
| Code actions | `gra` — offers to remove unused import |
| Rename symbol | `grn` — type new name with live preview across the file |

Try it: put your cursor on `find_user` and press `grn`. Type `search_user` and watch every reference update in real-time. Press `Enter` to confirm or `Esc` to cancel.

### Code outline

| Do this | Keys |
|---------|------|
| Toggle outline sidebar | `<leader>cs` |
| Symbols nav (Miller columns) | `<leader>cS` |

Try it: press `<leader>cs`. An outline appears on the right showing `User`, `find_user`, `main`. Click or navigate to jump. The lualine statusline also shows breadcrumbs (e.g., `main.py > User > greeting`).

### Multi-language

Open different sample files to see LSP in action for each language:

| File | LSP server | Try |
|------|-----------|-----|
| `samples/python/main.py` | pyright + ruff | `K` on `dataclass`, `gd` on `User` |
| `samples/rust/src/main.rs` | rust-analyzer | `K` on `powi`, `gd` on `Shape` |
| `samples/typescript/index.ts` | ts_ls | `K` on `Promise`, `gd` on `User` |
| `samples/go/main.go` | gopls | `K` on `Sqrt`, `gd` on `Shape` |
| `samples/elixir/example.ex` | elixirls | `K` on `defstruct` |
| `samples/csharp/Program.cs` | omnisharp | `K` on `IShape`, `gd` on `Point` |
| `samples/lua/example.lua` | lua_ls | `K` on `table.insert` |

---

## 3. Editing Power

### Commenting

| Do this | Keys |
|---------|------|
| Toggle line comment | `gcc` |
| Toggle block (visual) | `gc` after selecting lines |

Try it: select a few lines with `V` then `j`, then press `gc`.

### Surround operations

| Do this | Keys | Example |
|---------|------|---------|
| Add surrounding | `gsa` + motion + char | `gsaiw"` wraps word in `"` |
| Delete surrounding | `gsd` + char | `gsd"` removes surrounding `"` |
| Replace surrounding | `gsr` + old + new | `gsr"'` changes `"` to `'` |

Try it: put your cursor on `World` in the Lua sample. Press `gsaiw"` — it wraps the word in double quotes. Then press `gsr"'` to change them to single quotes. Press `gsd'` to remove them.

### Text objects

Treesitter-aware text objects let you select and operate on code structures.

| Do this | Keys |
|---------|------|
| Select inside function | `vif` |
| Select around function (with signature) | `vaf` |
| Select inside class | `vic` |
| Select around class | `vac` |
| Jump to next function | `]f` |
| Jump to previous function | `[f` |
| Jump to next class | `]c` |
| Jump to previous class | `[c` |

mini.ai adds more text objects that work with `a`/`i`:

| Text object | Meaning |
|------------|---------|
| `a)` / `i)` | Around/inside parentheses |
| `a"` / `i"` | Around/inside quotes |
| `aa` / `ia` | Around/inside argument |
| `af` / `if` | Around/inside function |

Try it: in the Python sample, put your cursor inside the `greeting` method. Press `vif` to select the function body. Press `Esc`, then `vaf` to select the entire method including the `def` line.

### Flash (jump navigation)

| Do this | Keys |
|---------|------|
| Jump to any visible text | `s` then type 1-2 chars |
| Treesitter select | `S` then pick a label |

Try it: press `s`, type `us` — flash highlights every "us" on screen with labels. Press the label character to jump there instantly.

### Format on save

Formatting happens automatically when you save. You can also format manually:

| Do this | Keys |
|---------|------|
| Format file | `<leader>cf` |

Each language uses its own formatter:
Python (ruff), Rust (rustfmt), TypeScript/JS (prettier), Go (gofmt), Lua (stylua), Elixir (mix), C# (csharpier).

---

## 4. Refactoring

### Extract and inline

Select some code in visual mode, then use refactoring commands:

| Do this | Keys |
|---------|------|
| Extract function | `<leader>re` (visual mode) |
| Extract variable | `<leader>rv` (visual mode) |
| Inline variable | `<leader>ri` |
| Extract block | `<leader>rf` |
| Extract block to file | `<leader>rF` |

Try it: in the Python sample, visually select the body of the `for` loop in `find_user` (`V` on the `if` and `return` lines). Press `<leader>re`, type `matches_name`, and a new function is extracted.

### Search and replace

| Do this | Keys |
|---------|------|
| Open search and replace | `<leader>sr` |

grug-far opens a panel where you can:
1. Type a search pattern
2. Type a replacement
3. See all matches across the project
4. Replace individually or all at once

Try it: press `<leader>sr`, search for `greeting`, replace with `hello`. Review matches before confirming.

---

## 5. Git Workflow

### Hunk operations

Make a change to any file in the repo. The sign column shows `+` (added), `~` (changed), or `_` (deleted).

| Do this | Keys |
|---------|------|
| Next hunk | `]h` |
| Previous hunk | `[h` |
| Preview hunk diff | `<leader>ghp` |
| Stage hunk | `<leader>ghs` |
| Reset hunk (undo changes) | `<leader>ghr` |
| Blame current line | `<leader>ghb` |
| Stage entire buffer | `<leader>ghS` |
| Reset entire buffer | `<leader>ghR` |

Try it: add a blank line to a file. Press `]h` to jump to the change. Press `<leader>ghp` to see a preview. Press `<leader>ghr` to undo it.

### Lazygit

| Do this | Keys |
|---------|------|
| Open lazygit | `<leader>gg` |

A floating terminal opens with lazygit — a full TUI for git. Stage files, write commits, push, view logs, resolve conflicts, all without leaving nvim. Press `q` to close.

---

## 6. Debugging

Open `samples/python/main.py`.

### Setting breakpoints

| Do this | Keys |
|---------|------|
| Toggle breakpoint | `<leader>db` on any line |
| Conditional breakpoint | `<leader>dB` then type a condition |

Try it: move to the `print(user.greeting())` line and press `<leader>db`. A red dot appears in the sign column.

### Running the debugger

| Do this | Keys |
|---------|------|
| Start / continue | `<leader>dc` |
| Step into | `<leader>di` |
| Step over | `<leader>do` |
| Step out | `<leader>dO` |
| Toggle DAP UI | `<leader>du` |
| Toggle REPL | `<leader>dr` |

Try it: with a breakpoint set, press `<leader>dc`. Select the Python debug configuration. The DAP UI opens automatically showing:
- **Variables** — local and global variables with their values
- **Call stack** — current execution point
- **Breakpoints** — list of all breakpoints
- **REPL** — evaluate expressions at the breakpoint

Virtual text shows variable values inline next to the code. Press `<leader>do` to step over, `<leader>di` to step into functions.

---

## 7. Testing

Open `samples/python/main.py` (or any file with tests).

| Do this | Keys |
|---------|------|
| Run nearest test | `<leader>tt` |
| Run all tests in file | `<leader>tf` |
| Debug nearest test | `<leader>td` |
| Toggle test summary | `<leader>ts` |
| Show test output | `<leader>to` |
| Toggle output panel | `<leader>tO` |
| Stop running test | `<leader>tS` |
| Jump to next failed test | `]t` |
| Jump to previous failed test | `[t` |

neotest shows pass/fail status in the gutter next to each test. The summary panel shows a tree of all tests with their status.

Supported languages: Python (pytest), Rust (cargo test), Go (go test).

---

## 8. Terminal

| Do this | Keys |
|---------|------|
| Toggle floating terminal | `Ctrl-/` |
| Open lazygit | `<leader>gg` |

The floating terminal is a quick way to run commands without leaving nvim. Press `Ctrl-/` again to hide it. Your shell session persists.

---

## 9. Sessions

Sessions auto-save when you exit nvim and can be restored when you return to the same directory.

| Do this | Keys |
|---------|------|
| Restore session for cwd | `<leader>qs` |
| Select from saved sessions | `<leader>qS` |
| Restore last session | `<leader>ql` |
| Stop auto-saving | `<leader>qd` |

The dashboard (shown on startup with no file argument) also offers session restore.

---

## 10. UI Features

### Indent guides

Vertical lines show indentation levels. The current scope is highlighted brighter.

### Notifications

Notifications (LSP progress, format-on-save, etc.) appear in the top-right corner and fade out.

### Bigfile mode

Large files (>1.5MB) automatically disable heavy features (treesitter, LSP, etc.) for performance.

### LSP word highlighting

When your cursor rests on a symbol, all other references in the visible area are highlighted.

### Markdown rendering

Open any `.md` file. Headings, code blocks, checkboxes, tables, and links render with visual formatting directly in the buffer.

### TODO highlighting

Keywords in comments are highlighted with distinct colors:
- `TODO` — blue
- `FIXME` — red
- `HACK` — orange
- `BUG` — red
- `NOTE` — green

Press `<leader>st` to search all TODOs across the project.

---

## Quick Reference Card

### Leader groups (press `Space` + key)

| Key | Group | Contains |
|-----|-------|----------|
| `b` | Buffer | next, previous, close |
| `c` | Code | diagnostics, format, outline |
| `d` | Debug | breakpoints, stepping, UI, REPL |
| `e` | Explorer | toggle, reveal |
| `f` | Find | files, grep, buffers, recent, help |
| `g` | Git | lazygit, hunk operations |
| `q` | Session | restore, select, last |
| `r` | Refactor | extract, inline |
| `s` | Search | TODOs, search-and-replace |
| `t` | Test | run, debug, summary, output |
| `x` | Diagnostics | workspace, buffer, quickfix |

### Non-leader essentials

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `grr` | Find references |
| `grn` | Rename (live preview) |
| `gra` | Code actions |
| `K` | Hover docs |
| `gcc` | Toggle comment |
| `gsa`/`gsd`/`gsr` | Add/delete/replace surrounding |
| `s` / `S` | Flash jump / treesitter select |
| `]f` / `[f` | Next/previous function |
| `]h` / `[h` | Next/previous git hunk |
| `]d` / `[d` | Next/previous diagnostic |
| `]t` / `[t` | Next/previous failed test |
| `Ctrl-/` | Toggle floating terminal |
