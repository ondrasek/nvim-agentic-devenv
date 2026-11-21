return {
    dir = vim.fn.stdpath("config") .. "/lua/devenv-agent",
    name = "devenv-agent",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    config = function(_, opts)
        require("devenv-agent").setup(opts)
    end,
    opts = {
        provider = "ollama",
    },
    keys = {
        -- Agent pane: a terminal split (right or bottom by screen size) running Claude Code / Pi
        {
            "<leader>ac",
            function()
                require("devenv-agent.pane").toggle()
            end,
            desc = "Agent pane toggle",
        },
        {
            "<leader>aw",
            function()
                require("devenv-agent.pane").swap()
            end,
            desc = "Swap agent pane <-> file tree",
        },
        {
            "<leader>ab",
            function()
                require("devenv-agent.pane").select_backend()
            end,
            desc = "Agent pane backend (claude/pi)",
        },
        {
            "<leader>ai",
            function()
                require("devenv-agent.pane").prompt()
            end,
            mode = "n",
            desc = "Ask agent about this file",
        },
        {
            "<leader>ai",
            function()
                -- Capture the live range first, then leave visual mode so the prompt can open
                local first, last = require("devenv-agent.context").selection_range()
                vim.cmd("normal! \27")
                require("devenv-agent.pane").prompt({ first = first, last = last })
            end,
            mode = "x",
            desc = "Ask agent about selection",
        },
        {
            "<leader>ax",
            function()
                require("devenv-agent.pane").close()
            end,
            desc = "Agent pane close (ends session)",
        },
        {
            "<leader>aa",
            function()
                require("devenv-agent").toggle()
            end,
            desc = "AI chat toggle",
        },
        {
            "<leader>ae",
            function()
                require("devenv-agent").open("explain")
            end,
            mode = "n",
            desc = "AI explain",
        },
        {
            "<leader>ae",
            function()
                require("devenv-agent").open_visual("explain")
            end,
            mode = "v",
            desc = "AI explain selection",
        },
        {
            "<leader>ad",
            function()
                require("devenv-agent").open("do")
            end,
            mode = "n",
            desc = "AI do",
        },
        {
            "<leader>ad",
            function()
                require("devenv-agent").open_visual("do")
            end,
            mode = "v",
            desc = "AI do selection",
        },
    },
}
