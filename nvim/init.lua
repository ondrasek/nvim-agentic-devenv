-- Initialize lazy.nvim package manager (defined in: lua/config/lazy.lua)
require("config.lazy")

-- ─── Core Settings ───────────────────────────────────────────────────────────

-- Line numbers
vim.o.number = true
vim.o.relativenumber = false

-- Indentation
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- Visual guides
vim.o.colorcolumn = "120"
vim.o.signcolumn = "yes"
vim.o.scrolloff = 5
vim.o.termguicolors = true

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true

-- System clipboard
vim.o.clipboard = "unnamedplus"

-- Font (for GUI clients like neovide)
vim.o.guifont = "JetBrainsMono Nerd Font:h18"

-- ─── Auto-save ───────────────────────────────────────────────────────────────

vim.o.autowriteall = true

vim.api.nvim_create_autocmd("FocusLost", {
    desc = "Auto-save all buffers when focus is lost",
    command = "silent! wall",
})

-- ─── Auto-open neo-tree on startup ──────────────────────────────────────────

vim.api.nvim_create_autocmd("VimEnter", {
    desc = "Open neo-tree on startup, revealing the current file",
    callback = function()
        vim.cmd("Neotree reveal")
    end,
})

-- ─── Terminal ───────────────────────────────────────────────────────────────

-- Open a terminal as a regular buffer (shows as a tab in bufferline)
vim.keymap.set("n", "<leader>t", "<cmd>terminal<cr>", { desc = "Open terminal" })

-- Esc exits terminal mode so you can switch tabs with <leader>bn/bp
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

-- Auto-enter insert mode when switching to a terminal buffer
vim.api.nvim_create_autocmd({ "BufEnter", "TermOpen" }, {
    pattern = "term://*",
    command = "startinsert",
})

-- ─── Trim trailing whitespace on save ────────────────────────────────────────

vim.api.nvim_create_autocmd("BufWritePre", {
    desc = "Trim trailing whitespace before saving",
    callback = function()
        local save = vim.fn.winsaveview()
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.winrestview(save)
    end,
})
