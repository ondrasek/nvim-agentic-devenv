return {
    "mason-org/mason-lspconfig.nvim",
    opts = {
        ensure_installed = {
            "pyright",
            "ruff",
            "lua_ls",
            "rust_analyzer",
            "ts_ls",
            "gopls",
            "elixirls",
            "omnisharp",
        },
    },
    dependencies = {
        { "mason-org/mason.nvim", opts = {} },
        "neovim/nvim-lspconfig",
    },
    config = function(_, opts)
        require("mason-lspconfig").setup(opts)

        -- Custom keybindings and server tweaks on LSP attach
        -- Note: Neovim 0.11 provides defaults: gd, grr, K, gra, grn, gri, grt, gO, [d, ]d, C-S
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                -- Floating line diagnostics
                vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, {
                    buffer = args.buf,
                    desc = "Line diagnostics",
                })

                -- Disable ruff hover in favor of pyright
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if client and client.name == "ruff" then
                    client.server_capabilities.hoverProvider = false
                end
            end,
        })
    end,
}
