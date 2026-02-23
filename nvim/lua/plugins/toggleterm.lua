return {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
        { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
    opts = {
        open_mapping = false,
        direction = "horizontal",
        size = 15,
        shade_terminals = true,
        shading_factor = 2,
        persist_size = true,
        persist_mode = true,
        close_on_exit = true,
    },
    config = function(_, opts)
        require("toggleterm").setup(opts)
        -- Map <Esc> in terminal mode to return to normal mode
        vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
        -- Map <leader>t in terminal mode to toggle the terminal off
        vim.keymap.set("t", "<C-\\><C-n><leader>t", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
    end,
}
