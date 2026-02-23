return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    keys = {
        {
            "<leader>cf",
            function()
                require("conform").format()
            end,
            desc = "Format",
        },
    },
    opts = {
        formatters_by_ft = {
            python = { "ruff_format" },
            lua = { "stylua" },
        },
        format_on_save = {
            timeout_ms = 3000,
            lsp_format = "fallback",
        },
    },
}
