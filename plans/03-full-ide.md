# Phase 3: Full IDE Features

Extends nvim with multi-language support, advanced git, debugging, navigation,
and UI polish. Builds on Phase 2 (LSP + completion + formatting).

## 1. Multi-language LSP

Add servers via mason.nvim (same `lsp.lua` config, just extend the server list):

| Language | Server | Formatter | Linter |
|----------|--------|-----------|--------|
| Rust | `rust-analyzer` | `rustfmt` (via conform) | built-in (rust-analyzer) |
| TypeScript/JS | `ts_ls` | `prettier` (via conform) | `eslint` (via nvim-lint) |
| Elixir | `elixir-ls` | `mix format` (via conform) | built-in (elixir-ls) |
| C# | `omnisharp` | `csharpier` (via conform) | built-in (omnisharp) |
| Go | `gopls` | `gofmt` (via conform) | `golangci-lint` (via nvim-lint) |

**Changes:** extend `lsp.lua` server list, add formatters to `conform.lua`, add linters to `lint.lua`

## 2. Git Integration

### Gitsigns keymaps

**Modify:** `nvim/lua/plugins/gitsigns.lua`

Add keybindings to the existing gitsigns config:

| Key | Action |
|-----|--------|
| `]h` / `[h` | Next/previous hunk |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghb` | Blame current line |
| `<leader>ghS` | Stage buffer |
| `<leader>ghR` | Reset buffer |

### Lazygit

**Plugin:** `snacks.nvim` terminal or simple keymap to open lazygit in a floating terminal

| Key | Action |
|-----|--------|
| `<leader>gg` | Open lazygit in floating terminal |

**File:** `nvim/lua/plugins/lazygit.lua` (or add to gitsigns config)

## 3. Debugging

**Plugins:**
- `mfussenegger/nvim-dap` — Debug Adapter Protocol client
- `rcarriga/nvim-dap-ui` — debugger UI (variables, breakpoints, stack, REPL)
- `mfussenegger/nvim-dap-python` — Python debug adapter (uses debugpy)

**Keybindings:**

| Key | Action |
|-----|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dc` | Continue / start debugging |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>dr` | Toggle REPL |
| `<leader>du` | Toggle DAP UI |

**File:** `nvim/lua/plugins/dap.lua`

## 4. Navigation

### Flash (jump navigation)

**Plugin:** `folke/flash.nvim`

| Key | Action |
|-----|--------|
| `s` | Flash jump (type chars, pick label to jump) |
| `S` | Flash treesitter (select treesitter node) |
| `r` | Remote flash (in operator-pending mode) |

**File:** `nvim/lua/plugins/flash.lua`

### Treesitter text objects

**Plugin:** `nvim-treesitter/nvim-treesitter-textobjects`

| Key | Action |
|-----|--------|
| `]f` / `[f` | Next/previous function |
| `]c` / `[c` | Next/previous class |
| `af` / `if` | Select around/inside function |
| `ac` / `ic` | Select around/inside class |
| `<C-space>` | Incremental selection (expand by treesitter node) |

**Changes:** extend `nvim/lua/plugins/treesitter.lua` with textobjects config

### Search and replace

**Plugin:** `MagicDuck/grug-far.nvim`

| Key | Action |
|-----|--------|
| `<leader>sr` | Open search and replace panel |

**File:** `nvim/lua/plugins/grug-far.lua`

## 5. UI Polish

### Indent guides

**Plugin:** `lukas-reineke/indent-blankline.nvim`

- Shows thin vertical lines at each indent level
- Scope highlighting (current context is brighter)

**File:** `nvim/lua/plugins/indent-blankline.lua`

### Noice (command line UI)

**Plugin:** `folke/noice.nvim`

- Replaces bottom command line with floating popup
- Routes messages and notifications to floating windows
- Search counter displayed inline

**File:** `nvim/lua/plugins/noice.lua`

### TODO comments

**Plugin:** `folke/todo-comments.nvim`

- Highlights `TODO`, `FIXME`, `HACK`, `BUG`, `NOTE` in code
- `]t` / `[t` to jump between them
- `<leader>st` to search all TODOs via telescope

**File:** `nvim/lua/plugins/todo-comments.lua`

## Prerequisites

- Phase 2 complete (working LSP + completion + formatting + linting)
- Language toolchains installed for desired languages (rustup, node, dotnet, etc.)
- `lazygit` installed (`brew install lazygit` or in container-setup.sh)
- `debugpy` installed for Python debugging (`pip install debugpy`)

## New files

| File | Plugin |
|------|--------|
| `nvim/lua/plugins/lazygit.lua` | Lazygit integration |
| `nvim/lua/plugins/dap.lua` | nvim-dap + dap-ui + dap-python |
| `nvim/lua/plugins/flash.lua` | flash.nvim |
| `nvim/lua/plugins/grug-far.lua` | grug-far.nvim |
| `nvim/lua/plugins/indent-blankline.lua` | indent-blankline.nvim |
| `nvim/lua/plugins/noice.lua` | noice.nvim |
| `nvim/lua/plugins/todo-comments.lua` | todo-comments.nvim |

## Modified files

| File | Change |
|------|--------|
| `nvim/lua/plugins/lsp.lua` | Add language servers |
| `nvim/lua/plugins/conform.lua` | Add formatters |
| `nvim/lua/plugins/lint.lua` | Add linters |
| `nvim/lua/plugins/gitsigns.lua` | Add hunk keymaps |
| `nvim/lua/plugins/treesitter.lua` | Add textobjects config |
