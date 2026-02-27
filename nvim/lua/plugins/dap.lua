return {
    "mfussenegger/nvim-dap",
    dependencies = {
        {
            "rcarriga/nvim-dap-ui",
            dependencies = { "nvim-neotest/nvim-nio" },
            opts = {},
            keys = {
                {
                    "<leader>du",
                    function()
                        require("dapui").toggle()
                    end,
                    desc = "Toggle DAP UI",
                },
            },
        },
        {
            "theHamsta/nvim-dap-virtual-text",
            opts = {},
        },
        {
            "jay-babu/mason-nvim-dap.nvim",
            dependencies = "mason-org/mason.nvim",
            opts = {
                ensure_installed = { "python" },
                automatic_installation = true,
            },
        },
        {
            "mfussenegger/nvim-dap-python",
            keys = {
                {
                    "<leader>dPt",
                    function()
                        require("dap-python").test_method()
                    end,
                    desc = "Debug test method",
                },
                {
                    "<leader>dPc",
                    function()
                        require("dap-python").test_class()
                    end,
                    desc = "Debug test class",
                },
            },
            config = function()
                require("dap-python").setup("python")
            end,
        },
    },
    keys = {
        {
            "<leader>db",
            function()
                require("dap").toggle_breakpoint()
            end,
            desc = "Toggle breakpoint",
        },
        {
            "<leader>dB",
            function()
                require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
            end,
            desc = "Conditional breakpoint",
        },
        {
            "<leader>dc",
            function()
                require("dap").continue()
            end,
            desc = "Continue / start",
        },
        {
            "<leader>di",
            function()
                require("dap").step_into()
            end,
            desc = "Step into",
        },
        {
            "<leader>do",
            function()
                require("dap").step_over()
            end,
            desc = "Step over",
        },
        {
            "<leader>dO",
            function()
                require("dap").step_out()
            end,
            desc = "Step out",
        },
        {
            "<leader>dr",
            function()
                require("dap").repl.toggle()
            end,
            desc = "Toggle REPL",
        },
    },
    config = function()
        -- Open/close dap-ui automatically with debug sessions
        local dap, dapui = require("dap"), require("dapui")
        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
        end
    end,
}
