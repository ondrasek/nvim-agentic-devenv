return {
    "coder/claudecode.nvim",
    lazy = false,
    opts = {
        terminal = {
            split_side = "right",
            split_width_percentage = 0.4,
        },
    },
    keys = {
        { "<leader>a1", "<cmd>ClaudeCode<cr>", desc = "Claude Code toggle" },
        { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    },
}
