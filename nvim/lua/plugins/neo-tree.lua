return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    keys = {
        { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "File explorer" },
        { "<leader>E", "<cmd>Neotree reveal<cr>", desc = "File explorer (reveal current)" },
    },
    opts = {
        close_if_last_window = true,
        filesystem = {
            follow_current_file = { enabled = true },
            use_libuv_file_watcher = true,
            filtered_items = {
                hide_dotfiles = false,
                never_show = {
                    ".git",
                    "node_modules",
                    "__pycache__",
                    ".venv",
                },
            },
        },
        window = {
            position = "left",
            width = 35,
        },
    },
}
