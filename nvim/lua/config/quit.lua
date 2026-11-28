--- One `:q` from the last file window quits nvim: side panels (file tree, agent chat and terminal, outline,
--- diagnostics, quickfix) never keep the editor open on their own.
---
--- The panels are closed *before* the quit is decided (QuitPre) and nvim's own quit then runs, so `:q`, `:q!`,
--- `:wq`, `ZZ` and the unsaved-changes protection behave exactly as usual. `:q` inside a panel closes only that
--- panel, and with several file windows `:q` closes only one.
local M = {}

local PANEL_FILETYPES = { ["neo-tree"] = true, aerial = true, trouble = true, qf = true }

local function is_floating(win)
    return vim.api.nvim_win_get_config(win).relative ~= ""
end

---@param win integer
---@return boolean
function M.is_panel(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return PANEL_FILETYPES[vim.bo[buf].filetype] == true
        or vim.b[buf].devenv_agent_chat == true
        or vim.b[buf].devenv_agent_pane == true
end

--- Is `win` the only window (in any tab page) that is neither a panel nor floating?
---@param win integer
---@return boolean
function M.is_last_file_window(win)
    if is_floating(win) or M.is_panel(win) then
        return false
    end
    for _, other in ipairs(vim.api.nvim_list_wins()) do
        if other ~= win and not is_floating(other) and not M.is_panel(other) then
            return false
        end
    end
    return true
end

--- Close the side panels if the current window is the last file window, so the pending quit exits nvim
function M.before_quit()
    local current = vim.api.nvim_get_current_win()
    if not M.is_last_file_window(current) then
        return
    end
    -- The tree parked for the chat must not be reopened: that would create a window and cancel the quit
    local ok, pane = pcall(require, "devenv-agent.pane")
    if ok then
        pane.dock_release()
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= current and not is_floating(win) and M.is_panel(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

function M.setup()
    vim.api.nvim_create_autocmd("QuitPre", {
        group = vim.api.nvim_create_augroup("DevenvQuit", { clear = true }),
        desc = "One :q from the last file window quits nvim",
        callback = M.before_quit,
    })
end

return M
