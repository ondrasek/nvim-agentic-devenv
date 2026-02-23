return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    keys = {
        { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
    },
    ---@type snacks.Config
    opts = {
        lazygit = { enabled = true },
        indent = { enabled = true },
        notifier = { enabled = true },
        bigfile = { enabled = true },
        words = { enabled = true },
    },
}
