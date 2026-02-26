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
