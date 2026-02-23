return {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    keys = {
        { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
        { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
        { "<leader>bd", "<cmd>bdelete<cr>", desc = "Close buffer" },
    },
    opts = {
        options = {
            diagnostics = "nvim_lsp",
            offsets = {
                {
                    filetype = "neo-tree",
                    text = "Explorer",
                    highlight = "Directory",
                    separator = true,
                },
            },
            show_close_icon = false,
            show_buffer_close_icons = true,
            separator_style = "slant",
        },
    },
}
