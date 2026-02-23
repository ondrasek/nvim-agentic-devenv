return {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Search TODOs" },
    },
    opts = {},
}
