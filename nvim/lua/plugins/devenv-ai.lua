return {
    dir = vim.fn.stdpath("config") .. "/lua/devenv-ai",
    name = "devenv-ai",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    config = function(_, opts)
        require("devenv-ai").setup(opts)
    end,
    opts = {
        provider = "ollama",
    },
    keys = {
        {
            "<leader>a3",
            function()
                require("devenv-ai").toggle()
            end,
            desc = "DevenvAI chat",
        },
    },
}
