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
            desc = "AI explain",
        },
        {
            "<leader>ad",
            function()
                require("devenv-agent").open("do")
            end,
            desc = "AI do",
        },
    },
}
