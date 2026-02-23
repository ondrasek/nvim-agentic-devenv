# Phase 3: Full IDE Features

Extends nvim with multi-language support, formatting, debugging, and advanced git integration.

## Multi-language LSP

Add servers via mason.nvim:
- **Rust:** rust-analyzer
- **Elixir:** elixir-ls / next-ls
- **C#:** omnisharp / csharp-ls
- **TypeScript:** ts_ls
- **Mojo:** mojo-lsp (when available)

## Formatting

- **conform.nvim** — format on save
- Formatters: ruff (Python), rustfmt (Rust), prettier (TS/JS), mix format (Elixir)

## Debugging

- **nvim-dap** — Debug Adapter Protocol client
- **nvim-dap-ui** — debugger UI
- **nvim-dap-python** — Python debug adapter

## Advanced Git

- **neogit** or **fugitive** — full git UI inside nvim
- Stage hunks, interactive rebase, commit, push without leaving editor

## Prerequisites

- Phase 2 must be complete (working LSP + completion)
- Language-specific toolchains installed (rustup, elixir, dotnet, etc.)
