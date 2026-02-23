return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        signs = {
            add          = { text = "+" },
            change       = { text = "~" },
            delete       = { text = "_" },
            topdelete    = { text = "-" },
            changedelete = { text = "~" },
        },
        on_attach = function(bufnr)
            local gs = require("gitsigns")
            local function map(mode, l, r, desc)
                vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
            end

            -- Hunk navigation
            map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
            map("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")

            -- Hunk operations
            map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
            map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
            map("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
            map("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
            map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
            map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
            map("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
            map("n", "<leader>ghR", gs.reset_buffer, "Reset buffer")
        end,
    },
}
