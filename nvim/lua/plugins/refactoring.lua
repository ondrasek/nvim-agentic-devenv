return {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    keys = {
        { "<leader>re", function() require("refactoring").refactor("Extract Function") end, mode = "v", desc = "Extract function" },
        { "<leader>rv", function() require("refactoring").refactor("Extract Variable") end, mode = "v", desc = "Extract variable" },
        { "<leader>ri", function() require("refactoring").refactor("Inline Variable") end, mode = { "n", "v" }, desc = "Inline variable" },
        { "<leader>rf", function() require("refactoring").refactor("Extract Block") end, desc = "Extract block" },
        { "<leader>rF", function() require("refactoring").refactor("Extract Block To File") end, desc = "Extract block to file" },
    },
    opts = {},
}
