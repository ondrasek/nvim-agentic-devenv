# Phase 2: Light IDE Features

**Status: Implemented**

Adds language intelligence, completion, formatting, and diagnostics to nvim.
Goal: replicate the core LazyVim IDE experience with hand-rolled, transparent config.

Key ecosystem finding: Neovim 0.11 overhauled LSP support with native `vim.lsp.config`/`vim.lsp.enable` APIs and built-in keybindings. This simplifies setup significantly.

## 1. LSP (Language Server Protocol)

**Plugins:**
- `mason-org/mason.nvim` — LSP/tool installer (org renamed from `williamboman`)
- `mason-org/mason-lspconfig.nvim` — auto-enables installed servers via `vim.lsp.enable()`
- `neovim/nvim-lspconfig` — ships server configs

**Servers:**
- `pyright` — Python type checking, hover, go-to-definition
- `ruff` — Python linting + formatting via LSP (replaces nvim-lint for Python; ruff-lsp is archived, native `ruff server` is the replacement)
- `lua_ls` — Lua (for editing nvim config)

**Keybindings:** Neovim 0.11 provides these by default — no custom mappings needed:

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `grr` | Find references |
| `K` | Hover documentation |
| `gra` | Code actions |
| `grn` | Rename symbol |
| `gri` | Implementation |
| `grt` | Type definition |
| `gO` | Document symbols |
| `[d` / `]d` | Previous/next diagnostic |
| `Ctrl-S` | Signature help (insert mode) |
| `<leader>cd` | Line diagnostics (custom) |

**Ruff + Pyright coexistence:** Ruff hover disabled; pyright handles it.

**File:** `nvim/lua/plugins/lsp.lua`

## 2. Autocompletion

**Plugin:** `saghen/blink.cmp` (replaces the 6-plugin nvim-cmp stack)
**Optional dep:** `rafamadriz/friendly-snippets`

**Why blink.cmp over nvim-cmp:**
- Community consensus (LazyVim + kickstart.nvim both switched)
- 1 plugin instead of 6 (nvim-cmp + cmp-nvim-lsp + cmp-buffer + cmp-path + LuaSnip + cmp_luasnip)
- Built-in: LSP, buffer, path, snippet sources + signature help + auto-brackets
- Sub-5ms async vs nvim-cmp's 60ms debounce
- Uses native `vim.snippet` — no LuaSnip dependency

**Behavior:**
- Popup appears as you type with LSP suggestions, buffer words, file paths
- `C-y` confirms selection, `C-n`/`C-p` navigates, `C-space` triggers, `C-e` dismisses

**File:** `nvim/lua/plugins/blink-cmp.lua`

## 3. Lua Dev Completions

**Plugin:** `folke/lazydev.nvim`

Configures lua_ls to understand the Neovim API (`vim.*` types). Only loads for Lua files.

**File:** `nvim/lua/plugins/lazydev.lua`

## 4. Formatting

**Plugin:** `stevearc/conform.nvim`

**Formatters:**
- `ruff_format` — Python
- `stylua` — Lua (installed via mason)

**Behavior:**
- Format on save (async, 3s timeout)
- `<leader>cf` to format manually
- Falls back to LSP formatting if no formatter configured

**File:** `nvim/lua/plugins/conform.lua`

## 5. Linting

**Plugin:** `mfussenegger/nvim-lint`

Python linting handled by ruff LSP server. nvim-lint is the framework for non-Python languages in Phase 3 (eslint, golangci-lint, etc.).

**File:** `nvim/lua/plugins/lint.lua`

## 6. Diagnostics Panel

**Plugin:** `folke/trouble.nvim` (v3)

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle diagnostics list (workspace) |
| `<leader>xd` | Toggle diagnostics list (current buffer) |
| `<leader>xq` | Toggle quickfix list |

**File:** `nvim/lua/plugins/trouble.lua`

## 7. Quality of Life

### Auto-pairs

**Plugin:** `windwp/nvim-autopairs`

Chosen over mini.pairs for better Python triple-quote support and fewer edge cases.

**File:** `nvim/lua/plugins/autopairs.lua`

### Commenting

**Plugin:** `folke/ts-comments.nvim`

Enhances Neovim 0.10+ native `gc`/`gcc` commenting with per-treesitter-node commentstring overrides.

**File:** `nvim/lua/plugins/ts-comments.lua`

### TODO Comments

**Plugin:** `folke/todo-comments.nvim`

Highlights TODO/FIXME/HACK/BUG in code. `<leader>st` searches all TODOs via telescope.

**File:** `nvim/lua/plugins/todo-comments.lua`

## New files

| File | Plugin |
|------|--------|
| `nvim/lua/plugins/lsp.lua` | mason + mason-lspconfig + nvim-lspconfig |
| `nvim/lua/plugins/blink-cmp.lua` | blink.cmp + friendly-snippets |
| `nvim/lua/plugins/lazydev.lua` | lazydev.nvim |
| `nvim/lua/plugins/conform.lua` | conform.nvim |
| `nvim/lua/plugins/lint.lua` | nvim-lint |
| `nvim/lua/plugins/trouble.lua` | trouble.nvim |
| `nvim/lua/plugins/autopairs.lua` | nvim-autopairs |
| `nvim/lua/plugins/ts-comments.lua` | ts-comments.nvim |
| `nvim/lua/plugins/todo-comments.lua` | todo-comments.nvim |

## Sample files

| File | Purpose |
|------|---------|
| `samples/python/main.py` | Test pyright, ruff, formatting |
| `samples/lua/example.lua` | Test lua_ls, stylua |
| `samples/rust/src/main.rs` + `Cargo.toml` | Ready for Phase 3 rust-analyzer |
| `samples/typescript/index.ts` + `package.json` | Ready for Phase 3 ts_ls |
