# Phase 2: Light IDE Features

Adds language intelligence, completion, formatting, and diagnostics to nvim.
Goal: replicate the core LazyVim IDE experience with hand-rolled, transparent config.

## 1. LSP (Language Server Protocol)

**Plugins:**
- `williamboman/mason.nvim` — portable LSP/formatter/linter installer
- `williamboman/mason-lspconfig.nvim` — bridge between mason and lspconfig
- `neovim/nvim-lspconfig` — LSP client configuration

**Servers (initial):**
- `pyright` — Python
- `lua_ls` — Lua (for editing nvim config)

**Keybindings:**

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover documentation |
| `<leader>ca` | Code actions |
| `<leader>cr` | Rename symbol |
| `[d` / `]d` | Previous/next diagnostic |
| `<leader>cd` | Line diagnostics (floating window) |

**File:** `nvim/lua/plugins/lsp.lua`

## 2. Autocompletion

**Plugins:**
- `hrsh7th/nvim-cmp` — completion engine
- `hrsh7th/cmp-nvim-lsp` — LSP completions
- `hrsh7th/cmp-buffer` — buffer word completions
- `hrsh7th/cmp-path` — file path completions
- `L3MON4D3/LuaSnip` — snippet engine (required by nvim-cmp)
- `saadparwaiz1/cmp_luasnip` — snippet completions

**Behavior:**
- Popup appears as you type with LSP suggestions, buffer words, file paths
- `<CR>` confirms selection
- `<Tab>` / `<S-Tab>` cycles through items
- `<C-Space>` triggers completion manually
- `<C-e>` dismisses popup

**File:** `nvim/lua/plugins/cmp.lua`

## 3. Formatting

**Plugin:** `stevearc/conform.nvim`

**Formatters (initial):**
- `ruff_format` — Python (via ruff, already installed)
- `stylua` — Lua (installed via mason)

**Behavior:**
- Format on save (async)
- `<leader>cf` to format manually
- Falls back to LSP formatting if no formatter configured

**File:** `nvim/lua/plugins/conform.lua`

## 4. Linting

**Plugin:** `mfussenegger/nvim-lint`

**Linters (initial):**
- `ruff` — Python (fast, replaces flake8/pylint)

**Behavior:**
- Lint on save and on insert leave
- Results shown as inline diagnostics (same as LSP errors)

**File:** `nvim/lua/plugins/lint.lua`

## 5. Diagnostics Panel

**Plugin:** `folke/trouble.nvim`

**Keybindings:**

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle diagnostics list (workspace) |
| `<leader>xd` | Toggle diagnostics list (current buffer) |
| `<leader>xq` | Toggle quickfix list |

**Behavior:**
- VSCode-like "Problems" panel at the bottom
- Shows all errors/warnings from LSP and linters
- Click or press enter to jump to the diagnostic location

**File:** `nvim/lua/plugins/trouble.lua`

## 6. Quality of Life

### Auto-pairs

**Plugin:** `echasnovski/mini.pairs`

- Auto-close `()`, `[]`, `{}`, `""`, `''`, `` `` ``
- Skips closing character if already present

**File:** `nvim/lua/plugins/mini-pairs.lua`

### Commenting

**Plugin:** `folke/ts-comments.nvim`

- `gcc` — toggle comment on current line
- `gc` in visual mode — toggle comment on selection
- Treesitter-aware (handles embedded languages like JSX correctly)

**File:** `nvim/lua/plugins/ts-comments.lua`

## Prerequisites

- Phase 1 complete (working nvim with treesitter, neo-tree, bufferline, lualine)
- `npm` available for pyright LSP server
- `ruff` available (installed by container-setup.sh or locally)

## New files

| File | Plugin |
|------|--------|
| `nvim/lua/plugins/lsp.lua` | mason + lspconfig |
| `nvim/lua/plugins/cmp.lua` | nvim-cmp + sources |
| `nvim/lua/plugins/conform.lua` | conform.nvim |
| `nvim/lua/plugins/lint.lua` | nvim-lint |
| `nvim/lua/plugins/trouble.lua` | trouble.nvim |
| `nvim/lua/plugins/mini-pairs.lua` | mini.pairs |
| `nvim/lua/plugins/ts-comments.lua` | ts-comments.nvim |
