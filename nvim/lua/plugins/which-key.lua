return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        spec = {
            { "<leader>b", group = "Buffer" },
            { "<leader>c", group = "Code" },
            { "<leader>d", group = "Debug" },
            { "<leader>dP", group = "Python" },
            { "<leader>e", group = "Explorer" },
            { "<leader>f", group = "Find" },
            { "<leader>g", group = "Git" },
            { "<leader>gh", group = "Hunks" },
            { "<leader>q", group = "Session" },
            { "<leader>r", group = "Refactor" },
            { "<leader>s", group = "Search" },
            { "<leader>t", group = "Test" },
            { "<leader>x", group = "Diagnostics" },
        },
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer local keymaps",
        },
    },
}
