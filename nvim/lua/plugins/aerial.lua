return {
    "stevearc/aerial.nvim",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons",
    },
    keys = {
        { "<leader>cs", "<cmd>AerialToggle!<cr>", desc = "Symbols outline" },
        { "<leader>cS", "<cmd>AerialNavToggle<cr>", desc = "Symbols nav" },
    },
    opts = {
        backends = { "lsp", "treesitter", "markdown", "man" },
        layout = {
            min_width = 30,
        },
        attach_mode = "global",
        filter_kind = false,
    },
}
