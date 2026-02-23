-- Initialize lazy.nvim package manager (defined in: lua/config/lazy.lua)
require("config.lazy")

-- ─── Core Settings ───────────────────────────────────────────────────────────

-- Line numbers
vim.o.number = true
vim.o.relativenumber = true

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

-- ─── Auto-open neo-tree when opening a directory ────────────────────────────

vim.api.nvim_create_autocmd("VimEnter", {
    desc = "Open neo-tree when nvim is started with a directory",
    callback = function()
        local arg = vim.fn.argv(0)
        if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
            vim.cmd("Neotree show")
        end
    end,
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
