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
        -- Contextual chat: two ordinary nvim buffers (transcript + input) docked right/bottom
        {
            "<leader>ac",
            function()
                require("devenv-agent.chat").toggle()
            end,
            desc = "Agent chat toggle",
        },
        {
            "<leader>af",
            function()
                require("devenv-agent.chat").focus_input(true)
            end,
            desc = "Focus agent chat input",
        },
        {
            "<leader>ai",
            function()
                require("devenv-agent.chat").prompt()
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
                require("devenv-agent.chat").prompt({ first = first, last = last })
            end,
            mode = "x",
            desc = "Ask agent about selection",
        },
        {
            "<leader>am",
            function()
                require("devenv-agent.chat").toggle_mode()
            end,
            desc = "Agent mode (ask <-> edit)",
        },
        {
            "<leader>an",
            function()
                require("devenv-agent.chat").new_session()
            end,
            desc = "Agent new conversation",
        },
        {
            "<leader>aw",
            function()
                require("devenv-agent.chat").swap()
            end,
            desc = "Swap agent chat <-> file tree",
        },
        {
            "<leader>ab",
            function()
                require("devenv-agent.chat").select_backend()
            end,
            desc = "Agent backend (claude/pi)",
        },
        {
            "<leader>ax",
            function()
                require("devenv-agent.chat").close()
            end,
            desc = "Agent chat close (ends conversation)",
        },
        -- Full terminal TUI (Claude Code / Pi) for when you want the real thing
        {
            "<leader>aT",
            function()
                require("devenv-agent.pane").toggle()
            end,
            desc = "Agent terminal (full TUI) toggle",
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
