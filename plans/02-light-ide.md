# Phase 2: Light IDE Features

Adds basic language intelligence to nvim while keeping it lightweight.

## LSP (Language Server Protocol)

- **mason.nvim** — portable LSP server installer
- **nvim-lspconfig** — LSP client configuration
- **Servers:** pyright (Python), lua_ls (Lua)

### Keybindings (planned)

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover documentation |
| `<leader>ca` | Code actions |
| `<leader>rn` | Rename symbol |
| `[d` / `]d` | Previous/next diagnostic |

## Completion

- **nvim-cmp** — completion engine
- **cmp-nvim-lsp** — LSP completions
- **cmp-buffer** — buffer word completions
- **cmp-path** — file path completions

## Inline Diagnostics

- Built-in nvim diagnostics (comes with LSP)
- `vim.diagnostic.config()` for virtual text display

## Prerequisites

- Phase 1 must be complete (working nvim with treesitter)
- `npm` available for some LSP servers (pyright)
