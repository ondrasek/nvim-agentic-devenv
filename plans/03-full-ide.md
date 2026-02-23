# Phase 3: Full IDE Features

Extends nvim with multi-language support, advanced git, debugging, navigation,
and UI polish. Builds on Phase 2 (LSP + completion + formatting).

**Status: COMPLETE**

## Implementation Notes

Key decisions diverging from the original plan:
- **snacks.nvim** replaces indent-blankline.nvim (LazyVim v14 switched) and provides lazygit, indent guides, notifications, bigfile handling, and LSP word highlighting in one plugin
- **noice.nvim skipped** — known stability issues with Neovim 0.11 (crashes, broken confirmations). snacks.notifier covers notifications.
- **mini.ai added** — complements treesitter-textobjects with `a`/`i` textobjects for arguments, function calls, quotes, brackets, tags
- **nvim-dap-ui chosen** over nvim-dap-view — battle-tested, LazyVim default
- **todo-comments.nvim** already existed from Phase 2

## 1. Multi-language LSP

Servers added via mason-lspconfig (`lsp.lua`):

| Language | Server | Formatter | Linter |
|----------|--------|-----------|--------|
| Python | `pyright` + `ruff` | `ruff_format` | ruff LSP |
| Lua | `lua_ls` | `stylua` | — |
| Rust | `rust_analyzer` | `rustfmt` | rust-analyzer |
| TypeScript/JS | `ts_ls` | `prettier` | `eslint` |
| Go | `gopls` | `gofmt` | `golangcilint` |
| Elixir | `elixirls` | `mix` | elixir-ls |
| C# | `omnisharp` | `csharpier` | omnisharp |

## 2. Git Integration

### Gitsigns keymaps (`gitsigns.lua`)

| Key | Action |
|-----|--------|
| `]h` / `[h` | Next/previous hunk |
| `<leader>ghs` | Stage hunk |
| `<leader>ghr` | Reset hunk |
| `<leader>ghp` | Preview hunk |
| `<leader>ghb` | Blame current line |
| `<leader>ghS` | Stage buffer |
| `<leader>ghR` | Reset buffer |

### Lazygit via snacks.nvim (`snacks.lua`)

| Key | Action |
|-----|--------|
| `<leader>gg` | Open lazygit in floating terminal |

## 3. Debugging (`dap.lua`)

**Plugins:** nvim-dap, nvim-dap-ui, nvim-nio, nvim-dap-virtual-text, mason-nvim-dap, nvim-dap-python

| Key | Action |
|-----|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Continue / start debugging |
| `<leader>di` | Step into |
| `<leader>do` | Step over |
| `<leader>dO` | Step out |
| `<leader>du` | Toggle DAP UI |
| `<leader>dr` | Toggle REPL |

DAP UI opens/closes automatically with debug sessions.

## 4. Navigation

### Flash (`flash.lua`)

| Key | Action |
|-----|--------|
| `s` | Flash jump (type chars, pick label) |
| `S` | Flash treesitter (select treesitter node) |

### Treesitter textobjects (`treesitter.lua`)

| Key | Action |
|-----|--------|
| `]f` / `[f` | Next/previous function |
| `]c` / `[c` | Next/previous class |
| `af` / `if` | Select around/inside function |
| `ac` / `ic` | Select around/inside class |

### mini.ai (`mini-ai.lua`)

Enhances `a`/`i` textobjects with arguments, function calls, quotes, brackets, tags.

### Search and replace (`grug-far.lua`)

| Key | Action |
|-----|--------|
| `<leader>sr` | Open search and replace panel |

## 5. UI Polish via snacks.nvim (`snacks.lua`)

| Module | Purpose |
|--------|---------|
| `indent` | Indent guides with scope highlighting |
| `notifier` | Pretty notifications (replaces noice.nvim) |
| `bigfile` | Disables heavy features for large files |
| `words` | LSP reference highlighting under cursor |

## Prerequisites

- Phase 2 complete (working LSP + completion + formatting + linting)
- Language toolchains installed for desired languages (rustup, node, dotnet, etc.)
- `lazygit` installed (`brew install lazygit` — added to Brewfile)
- `debugpy` installed for Python debugging (`pip install debugpy`)

## New files

| File | Plugin |
|------|--------|
| `nvim/lua/plugins/snacks.lua` | snacks.nvim (lazygit, indent, notifier, bigfile, words) |
| `nvim/lua/plugins/dap.lua` | nvim-dap + dap-ui + dap-python |
| `nvim/lua/plugins/flash.lua` | flash.nvim |
| `nvim/lua/plugins/mini-ai.lua` | mini.ai textobjects |
| `nvim/lua/plugins/grug-far.lua` | grug-far.nvim |

## Modified files

| File | Change |
|------|--------|
| `nvim/lua/plugins/lsp.lua` | Add rust_analyzer, ts_ls, gopls, elixirls, omnisharp |
| `nvim/lua/plugins/conform.lua` | Add rustfmt, prettier, gofmt, mix, csharpier |
| `nvim/lua/plugins/lint.lua` | Add eslint (ts/js), golangcilint (go) |
| `nvim/lua/plugins/gitsigns.lua` | Add hunk navigation and operation keymaps |
| `nvim/lua/plugins/treesitter.lua` | Add textobjects dependency and config, add go parser |
| `setup/Brewfile` | Add lazygit |
