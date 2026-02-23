return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        -- Python linting handled by ruff LSP server
        -- Rust linting handled by rust-analyzer
        -- Elixir/C# linting handled by their LSP servers
        require("lint").linters_by_ft = {
            typescript = { "eslint" },
            javascript = { "eslint" },
            go = { "golangcilint" },
        }

        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
            callback = function()
                require("lint").try_lint()
            end,
        })
    end,
}
