-- Minimal init for headless plenary tests
-- Usage: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

local data_dir = vim.fn.stdpath("data")
local lazy_dir = data_dir .. "/lazy"

-- Add plenary.nvim
local plenary_path = lazy_dir .. "/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
    -- CI fallback: check sibling directory
    plenary_path = vim.fn.getcwd() .. "/../plenary.nvim"
end
vim.opt.rtp:prepend(plenary_path)

-- Add nui.nvim (dependency of devenv-agent)
local nui_path = lazy_dir .. "/nui.nvim"
if vim.fn.isdirectory(nui_path) == 0 then
    -- CI fallback: check sibling directory
    nui_path = vim.fn.getcwd() .. "/../nui.nvim"
end
vim.opt.rtp:prepend(nui_path)

-- Add devenv-agent to rtp (we're running from nvim/ directory)
local devenv_agent_path = vim.fn.getcwd() .. "/lua"
vim.opt.rtp:prepend(vim.fn.getcwd())
package.path = devenv_agent_path .. "/?.lua;" .. devenv_agent_path .. "/?/init.lua;" .. package.path

-- Minimal settings
vim.cmd([[set noswapfile]])
vim.o.termguicolors = true
