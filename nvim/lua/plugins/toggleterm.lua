return {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
        { "<C-`>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
        { "<C-`>", "<cmd>ToggleTerm<cr>", mode = "t", desc = "Toggle terminal" },
    },
    opts = {
        open_mapping = [[<C-`>]],
        direction = "horizontal",
        size = 15,
        shade_terminals = true,
        shading_factor = 2,
        persist_size = true,
        persist_mode = true,
        close_on_exit = true,
    },
}
