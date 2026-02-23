return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        -- Python linting handled by ruff LSP server
        -- Add linters here as languages are added in Phase 3
        -- Explicit empty table prevents nvim-lint from using built-in defaults
        require("lint").linters_by_ft = {}

        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
            callback = function()
                require("lint").try_lint()
            end,
        })
    end,
}
