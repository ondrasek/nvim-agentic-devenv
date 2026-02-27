local M = {}

--- Check if buffer content looks like binary data
---@param bufnr integer
---@param lines string[]
---@return boolean
local function is_binary(bufnr, lines)
    if vim.bo[bufnr].binary then
        return true
    end
    local check_lines = math.min(#lines, 10)
    for i = 1, check_lines do
        if lines[i]:find("%z") then
            return true
        end
    end
    return false
end

--- Add line number prefixes and truncate long lines
---@param lines string[]
---@param start_lnum integer 1-based starting line number
---@param max_line_length integer
---@return string[]
local function format_lines(lines, start_lnum, max_line_length)
    local width = #tostring(start_lnum + #lines - 1)
    local formatted = {}
    for i, line in ipairs(lines) do
        local lnum = start_lnum + i - 1
        local prefix = string.format("%" .. width .. "d| ", lnum)
        if #line > max_line_length then
            line = line:sub(1, max_line_length) .. " …"
        end
        formatted[i] = prefix .. line
    end
    return formatted
end

--- Resolve buffer and window IDs, defaulting to current
---@param opts table
---@return integer bufnr, integer winid
local function resolve_buf_win(opts)
    local bufnr = opts.bufnr or 0
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    local winid = opts.winid or 0
    if winid == 0 then
        winid = vim.api.nvim_get_current_win()
    end
    return bufnr, winid
end

--- Resolve cursor position from window, defaulting to (1,1)
---@param winid integer
---@param bufnr integer
---@return integer cursor_line, integer cursor_col
local function resolve_cursor(winid, bufnr)
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
        local cursor = vim.api.nvim_win_get_cursor(winid)
        return cursor[1], cursor[2] + 1
    end
    return 1, 1
end

--- Gather visual selection content into ctx
---@param ctx table
---@param bufnr integer
---@param total_lines integer
---@param max_lines integer
---@param max_line_length integer
---@return boolean success true if selection was valid
local function gather_selection(ctx, bufnr, total_lines, max_lines, max_line_length)
    if bufnr ~= vim.api.nvim_get_current_buf() then
        return false
    end
    local mark_start = vim.fn.line("'<")
    local mark_end = vim.fn.line("'>")
    local sel_start = math.min(mark_start, mark_end)
    local sel_end = math.max(mark_start, mark_end)
    if sel_start <= 0 or sel_end <= 0 or sel_start > total_lines then
        return false
    end
    sel_end = math.min(sel_end, total_lines)
    local truncated = false
    if sel_end - sel_start + 1 > max_lines then
        sel_end = sel_start + max_lines - 1
        truncated = true
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, sel_start - 1, sel_end, false)
    ctx.selection_start = sel_start
    ctx.selection_end = sel_end
    local content = table.concat(format_lines(lines, sel_start, max_line_length), "\n")
    if truncated then
        content = content .. "\n(truncated to " .. max_lines .. " lines)"
    end
    ctx.content = content
    ctx.content_type = "selection"
    return true
end

--- Gather cursor-centered window content into ctx
---@param ctx table
---@param bufnr integer
---@param total_lines integer
---@param max_lines integer
---@param max_line_length integer
local function gather_cursor_window(ctx, bufnr, total_lines, max_lines, max_line_length)
    local half = math.floor(max_lines / 2)
    local win_start = math.max(1, ctx.cursor_line - half)
    local win_end = math.min(total_lines, win_start + max_lines - 1)
    win_start = math.max(1, win_end - max_lines + 1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, win_start - 1, win_end, false)
    ctx.content = table.concat(format_lines(lines, win_start, max_line_length), "\n")
    ctx.content_type = "cursor_window"
end

--- Gather buffer context for AI prompts
---@param opts? { visual?: boolean, bufnr?: integer, winid?: integer, max_lines?: integer, max_line_length?: integer }
---@return table context
function M.gather(opts)
    opts = opts or {}
    local max_lines = opts.max_lines or 200
    local max_line_length = opts.max_line_length or 500

    local bufnr, winid = resolve_buf_win(opts)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return {
            filename = "(invalid buffer)",
            filetype = "(none)",
            content = "",
            content_type = "empty",
            changedtick = -1,
        }
    end

    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    local filetype = vim.bo[bufnr].filetype
    local cursor_line, cursor_col = resolve_cursor(winid, bufnr)

    local ctx = {
        filename = buf_name ~= "" and buf_name or "(no file)",
        filetype = filetype ~= "" and filetype or "(none)",
        cursor_line = cursor_line,
        cursor_col = cursor_col,
        content = "",
        content_type = "empty",
    }

    local total_lines = vim.api.nvim_buf_line_count(bufnr)

    -- Empty buffer
    if total_lines == 0 or (total_lines == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == "") then
        ctx.content = "(empty buffer)"
        ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
        return ctx
    end

    -- Binary detection
    local prefix = vim.api.nvim_buf_get_lines(bufnr, 0, math.min(10, total_lines), false)
    if is_binary(bufnr, prefix) then
        ctx.content = "(binary or non-text buffer skipped)"
        ctx.content_type = "binary"
        ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
        return ctx
    end

    -- Try visual selection first, fall back to cursor window
    if not (opts.visual and gather_selection(ctx, bufnr, total_lines, max_lines, max_line_length)) then
        gather_cursor_window(ctx, bufnr, total_lines, max_lines, max_line_length)
    end

    ctx.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
    return ctx
end

return M
