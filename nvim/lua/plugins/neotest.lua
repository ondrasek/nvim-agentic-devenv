return {
    "nvim-neotest/neotest",
    dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "nvim-neotest/neotest-python",
        "rouge8/neotest-rust",
        "fredrikaverpil/neotest-golang",
    },
    keys = {
        { "<leader>tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
        { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file tests" },
        { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
        { "<leader>to", function() require("neotest").output.open({ enter_on_open = true }) end, desc = "Show test output" },
        { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
        { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
        { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop test" },
        { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Previous failed test" },
        { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
    },
    config = function()
        require("neotest").setup({
            adapters = {
                require("neotest-python")({
                    dap = { justMyCode = false },
                }),
                require("neotest-rust"),
                require("neotest-golang"),
            },
        })
    end,
}
